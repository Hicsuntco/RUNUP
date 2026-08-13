// Behavioural analytics intake — the app's only instrumentation, first-party by design (see the
// `events` table in db/schema.sql for why there's no third-party SDK behind this).
//
// Two things make this endpoint different from every other one here:
//   1. Auth is OPTIONAL. The decisive part of the funnel happens before an account exists at all
//      — onboarding runs end to end without ever signing in, and Club (the only feature that
//      needs an account) is reached long after. Requiring a token here would have thrown away
//      exactly the events worth collecting and left the "where does onboarding leak" question as
//      unanswerable as it was before.
//   2. It takes a batch, not one event. The client buffers and flushes (see
//      RunUp/Services/Analytics.swift) so a run never pays a network round trip per tap.
const { sql } = require('../lib/db');
const { requireAuth } = require('../lib/auth');
const { withErrorHandling, isUuid } = require('../lib/http');
const { underDailyCap } = require('../lib/rateLimit');

// Must match `Analytics.EventName` on the client — anything else is dropped rather than stored,
// same reasoning as `KNOWN_BADGES` in api/clubs/[action].js: an endpoint that accepts arbitrary
// client strings ends up as a free write-anything-you-like table, and (worse for its actual
// purpose) as a pile of near-duplicate names nobody can aggregate over. Adding a name here is a
// deliberate act, which is what keeps this list at the size of a funnel instead of a firehose.
const KNOWN_EVENTS = new Set([
  'app_opened',
  'onboarding_started',
  'onboarding_step_viewed',
  'onboarding_step_completed',
  'onboarding_finished',
  'run_started',
  'first_run_started',
  'run_completed',
  'first_run_completed',
  'coach_message_sent',
  'club_created',
  'club_joined',
  // Le seul événement à haute fréquence de la liste — un par changement d'écran, là où tous les
  // autres marquent un moment rare. Il est admis parce qu'il répond à une question qu'aucun autre
  // ne peut trancher : le Profil a remplacé Club en 5e onglet, la couche sociale est donc
  // descendue d'un niveau, et rien ne disait si ça lui coûte de l'usage.
  //
  // Sa cadence est déjà bornée sans traitement particulier : `MAX_EVENTS_PER_BATCH` et
  // `DAILY_BATCH_CAP` s'appliquent à lui comme aux autres. Sa prop unique (`screen`) est un
  // `AppScreen.rawValue` — une quinzaine de valeurs possibles, donc agrégeable, sans identifiant
  // de contenu ni durée.
  'screen_viewed',
]);

// A real day of heavy use is a few dozen events across a handful of flushes; the client also caps
// its own buffer. These bound what a tampered client (or a script hitting an endpoint that
// deliberately needs no token) can write.
const MAX_EVENTS_PER_BATCH = 50;
const MAX_PROPS_CHARS = 2000;
const DAILY_BATCH_CAP = 200;
// A batch that survived an app kill can legitimately arrive days late, so client timestamps have
// to be trusted to a point — but only to a point: without a floor and a ceiling, one device with a
// wrong clock silently poisons every cohort/retention query it lands in. Outside the window the
// row falls back to server `now()`, which is wrong by at most the flush delay instead of by years.
const MAX_BACKDATE_MS = 7 * 24 * 3600 * 1000;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  // Optional on purpose (see the file header) — `null` here is a normal, expected pre-signup
  // caller, not a rejection. `.catch` mirrors api/coach.js: a JWKS/DB hiccup while verifying must
  // degrade this call to anonymous, never 500 it.
  const userId = await requireAuth(req).catch(() => null);

  // Same key shape as the coach's limiter: the account when there is one, the caller's IP
  // otherwise, since anonymous use is the point of this endpoint. Fails open (see
  // lib/rateLimit.js) — a broken counter must not start dropping the only telemetry there is.
  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || 'unknown';
  const capKey = userId ? `events:u:${userId}` : `events:ip:${ip}`;
  if (!(await underDailyCap(capKey, DAILY_BATCH_CAP))) return res.status(429).json({ error: 'too_many_requests' });

  const { anonymousId, events } = req.body || {};
  if (!Array.isArray(events)) return res.status(400).json({ error: 'bad_request' });
  if (events.length > MAX_EVENTS_PER_BATCH) return res.status(400).json({ error: 'payload_too_large' });

  // The client generates a UUID; anything else is a tampered or malformed caller, and storing it
  // would only pollute the column that pre-account events are stitched on.
  const cleanAnonymousId = isUuid(anonymousId) ? anonymousId : null;

  const now = Date.now();
  const rows = [];
  let rejected = 0;
  for (const event of events) {
    if (!event || !KNOWN_EVENTS.has(event.name)) {
      rejected++;
      continue;
    }
    // Props are optional and best-effort: a malformed or oversized bag costs the props, never the
    // event itself. The event's existence is what the funnel is counted from; its properties only
    // ever refine a breakdown.
    let props = null;
    if (event.props && typeof event.props === 'object' && !Array.isArray(event.props)) {
      const serialized = JSON.stringify(event.props);
      if (serialized.length <= MAX_PROPS_CHARS) props = serialized;
    }
    rows.push({ name: event.name, props, createdAt: clampClientTimestamp(event.createdAt, now) });
  }

  // Individually dropped, never a 400 for the whole batch: an older or newer build of the app
  // sending one name this deploy doesn't know must not fail the request, because the client would
  // then retry that same batch forever and every good event in it would be stuck behind the bad
  // one. The counts come back so a client (or whoever is debugging one) can still see it happened.
  await Promise.all(
    rows.map((row) => sql`
      INSERT INTO events (user_id, anonymous_id, name, props, created_at)
      VALUES (${userId}, ${cleanAnonymousId}, ${row.name}, ${row.props}::jsonb, ${row.createdAt})
    `)
  );

  // The whole point of `users.last_seen_at` (see db/schema.sql): retention needs a "still around"
  // signal, and this batch already proves the app was open. Not awaited into the response path's
  // critical logic beyond this — but still awaited, since Vercel may freeze the function the
  // moment the response is sent.
  if (userId) {
    await sql`UPDATE users SET last_seen_at = now() WHERE id = ${userId}`.catch(() => {});
  }

  // Opportunistic prune, not a cron job — same pattern (and same reason) as api/coach.js's
  // coach_usage cleanup. This is the fastest-growing table in the schema and nothing else would
  // ever bound it; 400 days keeps a full year of cohorts comparable year-over-year, and matches
  // the retention period stated in PRIVACY_POLICY.md.
  if (Math.random() < 0.005) {
    sql`DELETE FROM events WHERE created_at < now() - interval '400 days'`.catch(() => {});
  }

  res.status(200).json({ ok: true, accepted: rows.length, rejected });
});

// Returns an ISO timestamp for the row: the client's own if it's plausible, server time otherwise.
function clampClientTimestamp(raw, now) {
  if (typeof raw !== 'string') return new Date(now).toISOString();
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) return new Date(now).toISOString();
  if (parsed < now - MAX_BACKDATE_MS || parsed > now + MAX_CLOCK_SKEW_MS) return new Date(now).toISOString();
  return new Date(parsed).toISOString();
}
