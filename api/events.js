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
const { estAdmin } = require('../lib/admin');
const { jetonValide } = require('../lib/statsJeton');

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
  // Un message météo parti. Sa propriété `source` distingue l'ouverture de l'app d'un réveil en
  // arrière-plan accordé par iOS — et c'est le SEUL moyen de savoir si ces réveils se produisent :
  // iOS décide seul, ne le signale pas, et ne s'en explique jamais. Sans ce nom ici, l'événement
  // partirait dans le vide et la question resterait sans réponse, exactement comme l'entonnoir
  // d'abonnement plus bas.
  'weather_advice_sent',
  // ── CES ONZE NOMS MANQUAIENT, ET LE CLIENT LES ENVOYAIT DEPUIS DES MOIS ──────────────────────
  //
  // Le commentaire en tête de cette liste dit qu'ajouter un nom est « un acte délibéré ». C'est
  // vrai, et c'est précisément par là que la liste s'est cassée : le côté client a été écrit,
  // relu et livré sans que personne n'ait à revenir ici. Les événements partaient, l'app ne
  // voyait aucune erreur (une réponse 200, `rejected` dans un corps que personne ne lit), et la
  // boucle plus bas les comptait un par un dans le vide.
  //
  // Le plus coûteux est l'entonnoir d'abonnement. Il a été ajouté côté client pour une raison
  // écrite noir sur blanc dans `Analytics.swift` : « rien ne disait si personne ne paye parce que
  // personne n'atteint le mur de paiement, parce qu'on le voit et qu'on repart, ou parce que
  // l'achat casse. Ce sont trois maladies différentes, avec trois remèdes opposés. » Les huit
  // événements censés les distinguer n'ont jamais atteint cette table. La question est restée
  // exactement aussi ouverte qu'avant, et personne ne pouvait le deviner en lisant le client.
  //
  // `ci_scripts/check_events.py` compare désormais cette liste à l'énumération Swift dans les
  // deux sens. C'est une duplication entre deux langages, sans compilateur pour la tenir : la
  // seule chose qui pouvait la garder juste était une machine.
  'paywall_shown',
  'paywall_plan_selected',
  'purchase_started',
  'purchase_completed',
  'purchase_cancelled',
  'purchase_failed',
  'restore_tapped',
  'paywall_products_unavailable',
  'session_moved',
  'account_switched_fresh',
  // Les gestes délibérés du Club — le seul moyen de savoir si un club est vivant ou seulement
  // rejoint. Voir `Analytics.EventName.clubActionTaken` : sa prop unique `kind` est prise dans
  // une liste fermée de huit valeurs, sans identifiant d'activité, d'itinéraire ni de personne.
  'club_action_taken',
  // Une vidéo de course fabriquée. La seule question que cette fonctionnalité pose : est-ce que
  // quelqu'un s'en sert ? Elle coûte une douzaine de secondes de calcul sur le téléphone et un
  // bouton de plus sur l'écran de fin de course — deux choses qu'on retire sans regret si la
  // réponse est non. Sa prop unique (`discipline`) vaut « run », « bike » ou « trail ».
  'run_video_made',
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
  // Deux sens sur la même table, donc sur la même route. GET rend des AGRÉGATS de ce que POST a
  // écrit — voir `lectureAgregats` tout en bas, et surtout le commentaire qui dit pourquoi ce
  // n'est pas `api/stats.js` : ce projet est à douze fonctions serverless, et douze est le
  // plafond du plan. Une treizième ne manque pas de place « à peu près » : elle fait échouer le
  // DÉPLOIEMENT ENTIER, donc l'app en production, pour un tableau de bord.
  if (req.method === 'GET') return lectureAgregats(req, res);
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  // Optional on purpose (see the file header) — `null` here is a normal, expected pre-signup
  // caller, not a rejection. `.catch` mirrors api/coach.js: a JWKS/DB hiccup while verifying must
  // degrade this call to anonymous, never 500 it.
  const userId = await requireAuth(req, res).catch(() => null);

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

// ─── LA LECTURE : des agrégats pour le livre de comptes de la maison ──────────────────────────
//
// Hukaia et RUNUP sont publiées par le même compte Apple, et le livre de comptes
// (app.hukaia.com/comptes) voyait donc les TÉLÉCHARGEMENTS de RUNUP — ils arrivent dans les mêmes
// rapports de ventes — et rien d'autre. Pas une ouverture, pas une course, pas un compte : tout
// le reste vit sur ce Postgres-ci, que rien là-bas ne sait lire.
//
// Charlotte, 24 octobre : « je veux un vrai Dashboard pour suivre les deux applications
// parfaitement, savoir comment elles fonctionnent, ce qui fonctionne et ce qui ne fonctionne
// pas ». D'où ce point de lecture.
//
// POURQUOI ICI, ET PAS DANS UN api/stats.js À LUI
//
// Vercel compte UNE fonction serverless par fichier sous api/, et ce projet en a exactement
// douze — le plafond du plan. Un treizième fichier ne se déploie pas « un peu moins bien » : le
// déploiement entier échoue, donc l'app en production tombe, pour une page de chiffres. La
// lecture vit donc avec l'écriture, ce qui se défend aussi sans ce plafond : c'est la même
// table, et personne n'a à deviner où elle se lit.
//
// CE QUI N'EN SORT JAMAIS
//
// Aucune ligne, aucun identifiant, aucune adresse, aucun nom. Que des comptages. La table
// `events` porte un `anonymous_id` par appareil et un `user_id` par compte : les faire sortir
// d'ici reviendrait à exporter le parcours de gens qui n'ont rien demandé, vers une autre base,
// pour afficher un chiffre qu'un COUNT() donne aussi bien.
//
// LA PORTE
//
// Deux façons d'entrer, et aucune par défaut :
//
//   1. un jeton de service, posé dans RUNUP_STATS_TOKEN (Vercel → Settings → Environment
//      Variables). C'est ce que la collecte quotidienne de Hukaia utilise : une machine parle à
//      une machine, sans compte ni session ;
//   2. une session d'administrateur (les mêmes adresses que lib/admin.js), pour regarder depuis
//      un navigateur sans rien configurer.
//
// Variable non définie ET pas d'admin connecté : 401. Pas de repli, pas de valeur par défaut —
// même règle que la liste des admins, pour la même raison : « un droit qui s'accorde tout seul
// quand une configuration manque est la plus mauvaise des portes ».
//
// La porte elle-même vit dans lib/statsJeton.js, et pas ici : cette route a besoin d'un Postgres,
// les tests de ce dépôt n'en ont pas, et une porte qu'on ne peut pas éprouver finit par s'ouvrir
// toute seule un jour de refactor. Voir tests/statsJeton.test.js.
async function autoriseLecture(req, res) {
  if (jetonValide(req.headers.authorization, process.env.RUNUP_STATS_TOKEN)) return true;

  // Pas de jeton de service valable : reste la session d'un administrateur.
  const userId = await requireAuth(req, res);
  if (!userId) return false;
  const { rows } = await sql`SELECT email FROM users WHERE id = ${userId}`;
  return !!(rows[0] && estAdmin(rows[0].email));
}

async function lectureAgregats(req, res) {
  if (!(await autoriseLecture(req, res))) {
    if (!res.headersSent) res.status(401).json({ error: 'unauthorized' });
    return;
  }

  // La fenêtre, bornée des deux côtés : un `?jours=100000` ferait un balayage complet de la table
  // qui grossit le plus vite d'ici, pour un chiffre que personne ne regarde.
  const jours = Math.min(Math.max(parseInt(req.query.jours, 10) || 30, 1), 365);
  const depuis = new Date(Date.now() - jours * 86400000).toISOString();

  // Un seul aller-retour par famille de questions plutôt qu'un COUNT() par ligne du tableau de
  // bord : chaque requête de ce driver est un appel HTTP, et quinze appels séquentiels pour
  // quinze nombres rendraient cette lecture plus lente que tout le reste de l'API réuni.
  const [comptes, usage, courses, clubs, entonnoir, parJour] = await Promise.all([
    sql`
      SELECT count(*)::int AS total,
             count(*) FILTER (WHERE created_at >= ${depuis})::int AS neufs,
             count(*) FILTER (WHERE last_seen_at >= ${depuis})::int AS actifs,
             -- Jamais revenu : vu pour la dernière fois dans les minutes de son inscription, ou
             -- jamais vu du tout. C'est le chiffre qui décide de tous les autres.
             count(*) FILTER (WHERE last_seen_at IS NULL
                                 OR last_seen_at <= created_at + interval '5 minutes')::int AS jamais_revenus
        FROM users`,
    sql`
      SELECT count(*) FILTER (WHERE name = 'app_opened')::int AS ouvertures,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'app_opened')::int AS appareils,
             count(*) FILTER (WHERE name = 'coach_message_sent')::int AS messages_coach,
             count(DISTINCT user_id) FILTER (WHERE name = 'coach_message_sent')::int AS gens_coach
        FROM events WHERE created_at >= ${depuis}`,
    sql`
      SELECT count(*) FILTER (WHERE type = 'run')::int AS courses,
             count(DISTINCT user_id) FILTER (WHERE type = 'run')::int AS coureurs,
             coalesce(sum(distance_km) FILTER (WHERE type = 'run'), 0)::float AS km
        FROM activities WHERE created_at >= ${depuis}`,
    sql`
      SELECT (SELECT count(*)::int FROM clubs) AS clubs,
             (SELECT count(*)::int FROM club_members) AS membres`,
    // L'entonnoir d'avant-compte, le seul endroit où RUNUP perd des gens sans jamais le savoir :
    // l'onboarding se termine entièrement sans se connecter, et la plupart ne se connectent
    // jamais. On compte des APPAREILS (anonymous_id), parce qu'il n'y a pas encore de compte.
    sql`
      SELECT count(DISTINCT anonymous_id) FILTER (WHERE name = 'onboarding_started')::int AS commences,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'onboarding_finished')::int AS finis,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'first_run_started')::int AS premiere_lancee,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'first_run_completed')::int AS premiere_finie
        FROM events WHERE created_at >= ${depuis}`,
    sql`
      SELECT created_at::date AS jour,
             count(*) FILTER (WHERE name = 'app_opened')::int AS ouvertures,
             count(DISTINCT anonymous_id)::int AS appareils
        FROM events WHERE created_at >= ${depuis}
       GROUP BY 1 ORDER BY 1`,
  ]);

  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).json({
    app: 'runup',
    jours,
    releve_le: new Date().toISOString(),
    comptes: comptes.rows[0],
    usage: usage.rows[0],
    courses: courses.rows[0],
    clubs: clubs.rows[0],
    entonnoir: entonnoir.rows[0],
    par_jour: parJour.rows,
  });
}
