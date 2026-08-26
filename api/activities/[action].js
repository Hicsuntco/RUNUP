// Consolidated into one dynamic route ([action] = create | feed | kudos) instead of 3 separate
// files — see api/auth/[action].js for why. /api/activities/create, /feed, /kudos still work
// exactly as before.
const { put, del } = require('@vercel/blob');
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling, isUuid } = require('../../lib/http');
const { sendPushToUser, sendPushToUsers } = require('../../lib/apns');
const { containsObjectionableContent } = require('../../lib/moderation');
const { underDailyCap } = require('../../lib/rateLimit');
const { canViewActivity, activityMetrics, isBlockedEitherWay } = require('../../lib/social');

const ALLOWED_TYPES = new Set(['run', 'strength', 'badge']);
const REFERRAL_REWARD_XP = 100;

module.exports = withErrorHandling(async function handler(req, res) {
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'create':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleCreate(req, res, userId);
    case 'feed':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleFeed(req, res, userId);
    case 'kudos':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleKudos(req, res, userId);
    case 'comments':
      if (req.method === 'GET') return handleCommentsList(req, res, userId);
      if (req.method === 'POST') return handleCommentCreate(req, res, userId);
      return res.status(405).json({ error: 'method_not_allowed' });
    case 'delete':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleDelete(req, res, userId);
    // Itinéraires partagés. Ces actions vivent ici plutôt que dans `api/routes/*.js` pour une
    // raison très concrète : Vercel compte un fichier sous `api/` comme une fonction serverless,
    // le plan Hobby en autorise douze, et le projet en a exactement douze. Un treizième fichier
    // ferait échouer TOUS les déploiements (voir le commit qui a fusionné `api/account`).
    case 'routePublish':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRoutePublish(req, res, userId);
    case 'routesNearby':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRoutesNearby(req, res, userId);
    case 'routeDetail':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRouteDetail(req, res, userId);
    case 'routeSave':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRouteSave(req, res, userId);
    case 'routesMine':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRoutesMine(req, res, userId);
    case 'routePhoto':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRoutePhoto(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Removes ONE of the caller's own activities from the club feed — scoped to user_id in the
// DELETE itself, so nobody can remove anyone else's post. Kudos and comments cascade with the
// row (FKs), and any challenge progress it contributed drops out automatically (progress is a
// live SUM over these rows). The XP it earned stays: the run really happened — removal is a
// feed-privacy action, not an undo of the training.
async function handleDelete(req, res, userId) {
  const { activityId } = req.body || {};
  if (!isUuid(activityId)) return res.status(400).json({ error: 'bad_request' });
  const { rows } = await sql`DELETE FROM activities WHERE id = ${activityId} AND user_id = ${userId} RETURNING id`;
  if (rows.length === 0) return res.status(404).json({ error: 'not_found' });
  res.status(200).json({ ok: true });
}

// Posts one completed activity (a run, a strength/mobility session, or a badge unlock) to the
// user's club feed, and credits its XP to their real, server-side total — this is what makes the
// leaderboard and feed genuinely backed by real actions instead of mock data.
async function handleCreate(req, res, userId) {
  const { clientId, type, text, xpEarned, distanceKm, durationSeconds, avgPace, elevationGainM, isPersonalRecord, contentKey } = req.body || {};
  const cleanText = typeof text === 'string' ? text.trim().slice(0, 200) : '';
  if (!isUuid(clientId) || !ALLOWED_TYPES.has(type) || !cleanText || typeof xpEarned !== 'number') {
    return res.status(400).json({ error: 'bad_request' });
  }
  // Same filter as club names/challenge titles/comments — activity text lands in every club
  // member's feed AND on their lock screens via push, so it can't be the one unfiltered field.
  if (containsObjectionableContent(cleanText)) return res.status(422).json({ error: 'objectionable_content' });
  // The client computes xpEarned locally (same gamification formula the rest of the app already
  // uses) — this cap just stops a tampered client from inflating the shared leaderboard, it's not
  // meant to be the real anti-cheat mechanism.
  const xp = Math.max(0, Math.min(500, Math.round(xpEarned)));
  // Un identifiant, pas du texte : il ne s'affiche jamais tel quel, l'appareil qui lit s'en sert
  // pour retrouver une chaîne traduite chez lui (voir `activities.content_key` dans schema.sql).
  // D'où le filtre sur la forme plutôt que le filtre de modération — et l'absence de filtre
  // laisserait passer n'importe quoi dans une colonne dont la valeur sert de clé.
  const key = typeof contentKey === 'string' && /^[a-z0-9_]{1,40}$/.test(contentKey) ? contentKey : null;
  // Only 'run' activities carry a real distance — a structured column (rather than parsing it
  // back out of `text`) is what lets club challenges compute real collective progress. Finite +
  // capped at 500 km: `Infinity > 0` is true in JS, and a tampered client's `1e12` would
  // otherwise instantly "complete" every club challenge (progress is a raw SUM).
  const distance = type === 'run' && Number.isFinite(distanceKm) && distanceKm > 0
    ? Math.min(distanceKm, 500)
    : null;

  // The rest of the run's real metrics, so the feed can show the run itself and not just a
  // sentence about it. Same shape of validation as `distance`: only for 'run', finite, positive,
  // and capped — a tampered client must not be able to write a 10-hour "run" or a 40 000 m climb
  // into a shared feed. NULL wherever it doesn't apply (strength/badge activities, a manually
  // logged run with no GPS): the client omits a missing metric rather than printing a fake 0.
  const duration = type === 'run' && Number.isFinite(durationSeconds) && durationSeconds > 0
    ? Math.min(Math.round(durationSeconds), 86400)
    : null;
  // "M:SS" only — this is rendered straight into other people's feeds, so it is validated as a
  // shape rather than trusted as free text.
  const pace = type === 'run' && typeof avgPace === 'string' && /^\d{1,2}:[0-5]\d$/.test(avgPace)
    ? avgPace
    : null;
  const elevation = type === 'run' && Number.isFinite(elevationGainM) && elevationGainM > 0
    ? Math.min(Math.round(elevationGainM), 10000)
    : null;
  // Only ever what the client asserts after checking its own full run history — the server has no
  // way to verify a personal record (it never receives past runs), so it stores the claim as-is
  // and never infers one.
  const personalRecord = type === 'run' && isPersonalRecord === true;

  // Per-user daily activity cap — each fresh clientId is otherwise a fresh XP award, so a
  // scripted loop with random UUIDs could farm unbounded xp_total onto the shared leaderboard.
  // 40/day is far beyond any real day of running + goals. Fails open on counter errors.
  try {
    const { rows: capRows } = await sql`
      INSERT INTO coach_usage (key, day, count) VALUES (${'act:' + userId}, CURRENT_DATE, 1)
      ON CONFLICT (key, day) DO UPDATE SET count = coach_usage.count + 1
      RETURNING count
    `;
    if (capRows[0] && capRows[0].count > 40) return res.status(429).json({ error: 'too_many_activities' });
  } catch { /* the cap must never take activity posting down with it */ }

  // Checked before the INSERT below — this is the referral-reward trigger (see
  // `grantReferralRewardIfNeeded`): a signup that goes on to log a real first activity, not just
  // an install.
  // An existence check, not a full COUNT — this runs on every single activity creation, and only
  // ever needs to know "is there at least one prior row", not how many.
  const { rows: priorActivityRows } = await sql`SELECT 1 FROM activities WHERE user_id = ${userId} LIMIT 1`;
  const isFirstActivity = priorActivityRows.length === 0;

  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id || null;

  // Idempotent on clientId, atomically: the old check-then-insert raced a fast retry into a
  // unique-constraint 500 instead of `duplicate: true`, and XP must only be credited when this
  // request is the one that actually inserted the row.
  const { rows: inserted } = await sql`
    INSERT INTO activities (client_id, user_id, club_id, type, text, xp_earned, distance_km, duration_seconds, avg_pace, elevation_gain_m, is_personal_record, content_key)
    VALUES (${clientId}, ${userId}, ${clubId}, ${type}, ${cleanText}, ${xp}, ${distance}, ${duration}, ${pace}, ${elevation}, ${personalRecord}, ${key})
    ON CONFLICT (client_id) DO NOTHING
    RETURNING id
  `;
  if (inserted.length === 0) return res.status(200).json({ ok: true, duplicate: true });
  await sql`UPDATE users SET xp_total = xp_total + ${xp} WHERE id = ${userId}`;

  // Before the response, deliberately — Vercel may freeze the function the moment the response
  // is sent, silently dropping anything still in flight. A referral reward that sometimes
  // doesn't arrive is worse than a create call that takes half a second longer.
  if (isFirstActivity) await grantReferralRewardIfNeeded(userId);
  if (clubId) await notifyClubOfNewActivity(clubId, userId, cleanText);

  res.status(201).json({ ok: true });
}

// Rewards both sides of a referral — but only the first time the referred person logs a real
// activity, not at signup itself (an install that never actually runs isn't worth rewarding).
// The flip of `referral_reward_granted` is conditional inside the UPDATE itself, so two
// concurrent "first activities" can't both pass a pre-check and double-pay the referrer.
async function grantReferralRewardIfNeeded(userId) {
  const { rows: flipped } = await sql`
    UPDATE users SET referral_reward_granted = true, xp_total = xp_total + ${REFERRAL_REWARD_XP}
    WHERE id = ${userId} AND referred_by IS NOT NULL AND referral_reward_granted = false
    RETURNING referred_by
  `;
  const referrerId = flipped[0]?.referred_by;
  if (!referrerId) return;

  await sql`UPDATE users SET xp_total = xp_total + ${REFERRAL_REWARD_XP} WHERE id = ${referrerId}`;

  const { rows: referredRows } = await sql`SELECT name FROM users WHERE id = ${userId}`;
  await sendPushToUser(sql, referrerId, {
    title: 'Parrainage',
    body: `${referredRows[0]?.name || 'Un ami'} a rejoint RunUp grâce à toi — +${REFERRAL_REWARD_XP} XP !`,
  });
}

// Every other member of the poster's club, except anyone who's blocked the poster (mirrors the
// feed's own visibility rule — someone you've blocked shouldn't be able to reach you by posting).
async function notifyClubOfNewActivity(clubId, posterId, text) {
  const { rows: poster } = await sql`SELECT name FROM users WHERE id = ${posterId}`;
  const posterName = poster[0]?.name || 'Un membre';
  const { rows: recipients } = await sql`
    SELECT user_id FROM club_members
    WHERE club_id = ${clubId} AND user_id != ${posterId}
      AND user_id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${posterId})
  `;
  await sendPushToUsers(sql, recipients.map((r) => r.user_id), { title: 'Le Club', body: `${posterName} ${text}` });
}

async function handleFeed(req, res, userId) {
  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id;
  if (!clubId) return res.status(200).json({ items: [] });

  const { rows } = await sql`
    SELECT a.id, a.text, a.created_at, u.name, u.id AS user_id, u.avatar_data, u.avatar_url,
           a.distance_km, a.duration_seconds, a.avg_pace, a.elevation_gain_m, a.is_personal_record,
           a.content_key,
           (SELECT COUNT(*)::int FROM activity_kudos k WHERE k.activity_id = a.id) AS kudos,
           EXISTS(SELECT 1 FROM activity_kudos k WHERE k.activity_id = a.id AND k.user_id = ${userId}) AS kudoed_by_me,
           (SELECT COUNT(*)::int FROM activity_comments c WHERE c.activity_id = a.id) AS comments_count
    FROM activities a
    JOIN users u ON u.id = a.user_id
    WHERE a.club_id = ${clubId}
      AND a.user_id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
    ORDER BY a.created_at DESC
    LIMIT 50
  `;

  res.status(200).json({
    items: rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      name: r.name,
      avatarBase64: r.avatar_data || null,
      avatarUrl: r.avatar_url || null,
      text: r.text,
      createdAt: r.created_at,
      ...activityMetrics(r),
      kudos: r.kudos,
      kudoedByMe: r.kudoed_by_me,
      commentsCount: r.comments_count,
    })),
  });
}

// Toggles the caller's kudos on one activity — real per-user state (activity_kudos), not a local
// @State Set that resets whenever the app relaunches.
async function handleKudos(req, res, userId) {
  const { activityId } = req.body || {};
  if (!isUuid(activityId)) return res.status(400).json({ error: 'bad_request' });

  // Toggling is cheap per-call but unthrottled, it's a free way to flood a target with pushes —
  // 300/day is far beyond any real usage (toggling kudos on every post in an active club feed).
  if (!(await underDailyCap('kudos:' + userId, 300))) return res.status(429).json({ error: 'too_many_requests' });

  // Reachable through EITHER relationship now — clubmates (as before) or a follow (friends feed)
  // — `canViewActivity` covers both plus the block check, so anyone holding an activity UUID they
  // have no real relationship to still 404s the same way a cross-club id always did.
  const { rows: activityRows } = await sql`SELECT user_id, text, club_id FROM activities WHERE id = ${activityId}`;
  const activity = activityRows[0];
  if (!activity || !(await canViewActivity(userId, activity.user_id, activity.club_id))) {
    return res.status(404).json({ error: 'not_found' });
  }

  const { rows: existing } = await sql`
    SELECT 1 FROM activity_kudos WHERE activity_id = ${activityId} AND user_id = ${userId}
  `;

  if (existing.length > 0) {
    await sql`DELETE FROM activity_kudos WHERE activity_id = ${activityId} AND user_id = ${userId}`;
    res.status(200).json({ kudoed: false });
    return;
  }

  await sql`
    INSERT INTO activity_kudos (activity_id, user_id) VALUES (${activityId}, ${userId})
    ON CONFLICT DO NOTHING
  `;

  // Only on a new kudos, never on removal, and never for kudoing your own post. Before the
  // response — Vercel may freeze the function once the response is sent.
  if (activity.user_id !== userId) {
    const { rows: kudoer } = await sql`SELECT name FROM users WHERE id = ${userId}`;
    let pushTitle = 'Amis';
    if (activity.club_id) {
      const { rows: memberRows } = await sql`SELECT 1 FROM club_members WHERE user_id = ${userId} AND club_id = ${activity.club_id}`;
      if (memberRows.length > 0) pushTitle = 'Le Club';
    }
    await sendPushToUser(sql, activity.user_id, {
      title: pushTitle,
      body: `${kudoer[0]?.name || 'Quelqu’un'} a applaudi : ${activity.text}`,
    });
  }
  res.status(200).json({ kudoed: true });
}

// Lists real comments on one activity, oldest first (a conversation reads top-down) — reachable
// through either relationship (clubmates or a follow, see `canViewActivity`; an activity neither
// applies to, or one whose club_id has since been cleared, 404s rather than leaking it) and
// filtered the same way the feed already is: no comments from anyone the caller has blocked.
async function handleCommentsList(req, res, userId) {
  const { activityId } = req.query || {};
  if (!isUuid(activityId)) return res.status(400).json({ error: 'bad_request' });

  const { rows: activityRows } = await sql`SELECT user_id, club_id FROM activities WHERE id = ${activityId}`;
  const activity = activityRows[0];
  if (!activity || !(await canViewActivity(userId, activity.user_id, activity.club_id))) {
    return res.status(404).json({ error: 'not_found' });
  }

  const { rows } = await sql`
    SELECT c.id, c.text, c.created_at, u.id AS user_id, u.name, u.avatar_data, u.avatar_url
    FROM activity_comments c
    JOIN users u ON u.id = c.user_id
    WHERE c.activity_id = ${activityId}
      AND c.user_id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
    ORDER BY c.created_at ASC
    LIMIT 200
  `;

  res.status(200).json({
    items: rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      name: r.name,
      avatarBase64: r.avatar_data || null,
      avatarUrl: r.avatar_url || null,
      text: r.text,
      createdAt: r.created_at,
    })),
  });
}

// Posts a real comment on a club-mate's activity — same moderation (blocklist filter) as club
// names/challenge titles, plus a push to the activity's owner (never for commenting on your own).
async function handleCommentCreate(req, res, userId) {
  const { activityId, text } = req.body || {};
  const trimmed = (text || '').trim().slice(0, 500);
  if (!isUuid(activityId) || !trimmed) return res.status(400).json({ error: 'bad_request' });
  if (containsObjectionableContent(trimmed)) return res.status(422).json({ error: 'objectionable_content' });
  // 100/day is far beyond any real conversation volume, and stops comments from being used to
  // flood a target (or the whole club feed) with pushes.
  if (!(await underDailyCap('comment:' + userId, 100))) return res.status(429).json({ error: 'too_many_requests' });

  const { rows: activityRows } = await sql`SELECT club_id, user_id, text FROM activities WHERE id = ${activityId}`;
  const activity = activityRows[0];
  if (!activity || !(await canViewActivity(userId, activity.user_id, activity.club_id))) {
    return res.status(404).json({ error: 'not_found' });
  }

  const { rows: inserted } = await sql`
    INSERT INTO activity_comments (activity_id, user_id, text)
    VALUES (${activityId}, ${userId}, ${trimmed})
    RETURNING id, created_at
  `;
  const { rows: me } = await sql`SELECT name FROM users WHERE id = ${userId}`;
  const commenterName = me[0]?.name || 'Toi';

  // Push before the response — Vercel may freeze the function once the response is sent. Title
  // reflects which relationship actually granted access, not just whether the activity has a
  // club_id at all (the commenter could be a follower with no club, or a club-mate).
  if (activity.user_id !== userId) {
    let pushTitle = 'Amis';
    if (activity.club_id) {
      const { rows: memberRows } = await sql`SELECT 1 FROM club_members WHERE user_id = ${userId} AND club_id = ${activity.club_id}`;
      if (memberRows.length > 0) pushTitle = 'Le Club';
    }
    await sendPushToUser(sql, activity.user_id, {
      title: pushTitle,
      body: `${commenterName} a commenté : ${activity.text}`,
    });
  }

  res.status(201).json({
    id: inserted[0].id,
    userId,
    name: commenterName,
    text: trimmed,
    createdAt: inserted[0].created_at,
  });
}


// ---------------------------------------------------------------------------
// Itinéraires partagés
// ---------------------------------------------------------------------------
// Voir `db/schema.sql` § "Shared routes" pour la règle de confidentialité : le tracé arrive ICI
// déjà rogné de ses 300 premiers et derniers mètres, par l'app. Le serveur ne reçoit donc jamais
// le point de départ réel d'une course, et ne peut pas le divulguer.

const MAX_ROUTE_POINTS = 600;
const MAX_PREVIEW_POINTS = 32;
// Généreux pour un usage réel (on publie un itinéraire de temps en temps, pas dix par jour) et
// serré pour un client trafiqué : chaque publication est une écriture JSONB non triviale.
const MAX_ROUTES_PER_DAY = 10;
const ROUTES_PAGE_SIZE = 50;

function isLatLngPair(p) {
  return Array.isArray(p) && p.length === 2
    && Number.isFinite(p[0]) && Number.isFinite(p[1])
    && p[0] >= -90 && p[0] <= 90 && p[1] >= -180 && p[1] <= 180;
}

function coerceNumber(value, { min, max }) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < min || n > max) return null;
  return n;
}

// Publie un itinéraire. Idempotent sur `client_id` comme `create` : une reprise de requête sur une
// connexion instable ne doit pas semer deux fois le même tracé sur la carte.
async function handleRoutePublish(req, res, userId) {
  const body = req.body || {};
  if (!isUuid(body.clientId)) return res.status(400).json({ error: 'bad_request' });

  const name = typeof body.name === 'string' ? body.name.trim().slice(0, 80) : '';
  if (!name) return res.status(400).json({ error: 'bad_request' });
  const notes = typeof body.notes === 'string' && body.notes.trim()
    ? body.notes.trim().slice(0, 500)
    : null;
  // Même filtre que les noms de club et les commentaires (App Store 1.2) : ce nom et cette note
  // sont visibles par des inconnus, pas seulement par le club de l'autrice.
  if (containsObjectionableContent(name) || (notes && containsObjectionableContent(notes))) {
    return res.status(422).json({ error: 'objectionable_content' });
  }

  const distanceKm = coerceNumber(body.distanceKm, { min: 0.5, max: 200 });
  if (distanceKm === null) return res.status(400).json({ error: 'bad_request' });

  const points = body.points;
  if (!Array.isArray(points) || points.length < 2 || points.length > MAX_ROUTE_POINTS
      || !points.every(isLatLngPair)) {
    return res.status(400).json({ error: 'bad_route' });
  }
  // Le repli tronque plutôt que de refuser : un aperçu malformé est un défaut d'affichage, pas une
  // raison de perdre la publication.
  const preview = Array.isArray(body.preview) && body.preview.length >= 2
    && body.preview.length <= MAX_PREVIEW_POINTS && body.preview.every(isLatLngPair)
    ? body.preview
    : points.slice(0, MAX_PREVIEW_POINTS);

  if (!(await underDailyCap(`route:${userId}`, MAX_ROUTES_PER_DAY))) {
    return res.status(429).json({ error: 'too_many_routes' });
  }

  const elevation = coerceNumber(body.elevationGainM, { min: 0, max: 20000 });
  const duration = coerceNumber(body.durationSeconds, { min: 0, max: 86400 });
  const locality = typeof body.locality === 'string' ? body.locality.trim().slice(0, 80) || null : null;
  const countryCode = typeof body.countryCode === 'string'
    ? body.countryCode.trim().toUpperCase().slice(0, 2) || null
    : null;

  const { rows } = await sql`
    INSERT INTO routes (client_id, user_id, name, notes, distance_km, elevation_gain_m,
                        duration_seconds, points, preview_points, start_lat, start_lng,
                        locality, country_code)
    VALUES (${body.clientId}, ${userId}, ${name}, ${notes}, ${distanceKm},
            ${elevation === null ? null : Math.round(elevation)},
            ${duration === null ? null : Math.round(duration)},
            ${JSON.stringify(points)}::jsonb, ${JSON.stringify(preview)}::jsonb,
            ${points[0][0]}, ${points[0][1]}, ${locality}, ${countryCode})
    ON CONFLICT (client_id) DO NOTHING
    RETURNING id
  `;
  if (!rows[0]) {
    // Déjà publié par une tentative précédente — on renvoie l'identifiant existant plutôt qu'une
    // erreur, pour que le client puisse quand même naviguer vers l'itinéraire.
    const { rows: existing } = await sql`SELECT id FROM routes WHERE client_id = ${body.clientId}`;
    return res.status(200).json({ ok: true, id: existing[0] ? existing[0].id : null, duplicate: true });
  }
  res.status(201).json({ ok: true, id: rows[0].id });
}

// Les itinéraires dont le DÉPART tombe dans le rectangle demandé. Pas de tracé complet ici, juste
// l'aperçu : cinquante tracés complets feraient plusieurs mégaoctets pour dessiner des gribouillis
// de quelques millimètres.
async function handleRoutesNearby(req, res, userId) {
  const minLat = coerceNumber(req.query.minLat, { min: -90, max: 90 });
  const maxLat = coerceNumber(req.query.maxLat, { min: -90, max: 90 });
  const minLng = coerceNumber(req.query.minLng, { min: -180, max: 180 });
  const maxLng = coerceNumber(req.query.maxLng, { min: -180, max: 180 });
  if ([minLat, maxLat, minLng, maxLng].some((v) => v === null) || minLat > maxLat || minLng > maxLng) {
    return res.status(400).json({ error: 'bad_request' });
  }
  // Filtres de distance optionnels — c'est la demande réelle : « je veux 10 km ici ».
  const distMin = coerceNumber(req.query.distMin, { min: 0, max: 200 });
  const distMax = coerceNumber(req.query.distMax, { min: 0, max: 200 });

  const { rows } = await sql`
    SELECT r.id, r.name, r.distance_km, r.elevation_gain_m, r.duration_seconds,
           r.preview_points, r.start_lat, r.start_lng, r.locality, r.country_code,
           r.photo_url, r.saves_count, r.created_at,
           u.name AS author_name, u.username AS author_username, u.avatar_url AS author_avatar,
           EXISTS (SELECT 1 FROM route_saves s WHERE s.route_id = r.id AND s.user_id = ${userId}) AS saved
    FROM routes r
    JOIN users u ON u.id = r.user_id
    WHERE r.start_lat BETWEEN ${minLat} AND ${maxLat}
      AND r.start_lng BETWEEN ${minLng} AND ${maxLng}
      AND (${distMin}::numeric IS NULL OR r.distance_km >= ${distMin})
      AND (${distMax}::numeric IS NULL OR r.distance_km <= ${distMax})
      -- Un blocage dans un sens ou dans l'autre retire l'itinéraire de la carte, comme il retire
      -- les publications du fil.
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = ${userId} AND b.blocked_id = r.user_id)
           OR (b.blocker_id = r.user_id AND b.blocked_id = ${userId})
      )
    ORDER BY r.saves_count DESC, r.created_at DESC
    LIMIT ${ROUTES_PAGE_SIZE}
  `;
  res.status(200).json({ routes: rows.map(mapRouteSummary) });
}

// Le tracé complet d'UN itinéraire — payé seulement quand quelqu'un l'ouvre vraiment.
async function handleRouteDetail(req, res, userId) {
  const id = req.query.id;
  if (!isUuid(id)) return res.status(400).json({ error: 'bad_request' });
  const { rows } = await sql`
    SELECT r.id, r.name, r.notes, r.distance_km, r.elevation_gain_m, r.duration_seconds,
           r.points, r.preview_points, r.start_lat, r.start_lng, r.locality, r.country_code,
           r.photo_url, r.saves_count, r.created_at, r.user_id,
           u.name AS author_name, u.username AS author_username, u.avatar_url AS author_avatar,
           EXISTS (SELECT 1 FROM route_saves s WHERE s.route_id = r.id AND s.user_id = ${userId}) AS saved
    FROM routes r
    JOIN users u ON u.id = r.user_id
    WHERE r.id = ${id}
  `;
  const row = rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  if (await isBlockedEitherWay(userId, row.user_id)) return res.status(404).json({ error: 'not_found' });
  res.status(200).json({
    route: { ...mapRouteSummary(row), notes: row.notes, points: row.points || [] },
  });
}

// Bascule l'enregistrement. `saves_count` est dénormalisé sur `routes` parce que c'est la clé de
// tri de la liste de découverte : un COUNT() par ligne à chaque affichage de carte serait payé
// cinquante fois par panoramique.
async function handleRouteSave(req, res, userId) {
  const { routeId, saved } = req.body || {};
  if (!isUuid(routeId) || typeof saved !== 'boolean') return res.status(400).json({ error: 'bad_request' });
  const { rows: exists } = await sql`SELECT user_id FROM routes WHERE id = ${routeId}`;
  if (!exists[0]) return res.status(404).json({ error: 'not_found' });
  if (await isBlockedEitherWay(userId, exists[0].user_id)) return res.status(404).json({ error: 'not_found' });

  if (saved) {
    const { rowCount } = await sql`
      INSERT INTO route_saves (route_id, user_id) VALUES (${routeId}, ${userId})
      ON CONFLICT DO NOTHING
    `;
    // Le compteur ne bouge que si la ligne a vraiment été créée — sinon un double appui le
    // gonflerait indéfiniment.
    if (rowCount > 0) await sql`UPDATE routes SET saves_count = saves_count + 1 WHERE id = ${routeId}`;
  } else {
    const { rowCount } = await sql`
      DELETE FROM route_saves WHERE route_id = ${routeId} AND user_id = ${userId}
    `;
    if (rowCount > 0) {
      await sql`UPDATE routes SET saves_count = GREATEST(saves_count - 1, 0) WHERE id = ${routeId}`;
    }
  }
  const { rows } = await sql`SELECT saves_count FROM routes WHERE id = ${routeId}`;
  res.status(200).json({ ok: true, savesCount: rows[0] ? Number(rows[0].saves_count) : 0 });
}

// Les itinéraires que j'ai publiés et ceux que j'ai enregistrés — la liste « à essayer ».
async function handleRoutesMine(req, res, userId) {
  const { rows: published } = await sql`
    SELECT r.id, r.name, r.distance_km, r.elevation_gain_m, r.duration_seconds,
           r.preview_points, r.start_lat, r.start_lng, r.locality, r.country_code,
           r.photo_url, r.saves_count, r.created_at,
           u.name AS author_name, u.username AS author_username, u.avatar_url AS author_avatar,
           TRUE AS saved
    FROM routes r JOIN users u ON u.id = r.user_id
    WHERE r.user_id = ${userId}
    ORDER BY r.created_at DESC LIMIT ${ROUTES_PAGE_SIZE}
  `;
  const { rows: saved } = await sql`
    SELECT r.id, r.name, r.distance_km, r.elevation_gain_m, r.duration_seconds,
           r.preview_points, r.start_lat, r.start_lng, r.locality, r.country_code,
           r.photo_url, r.saves_count, r.created_at,
           u.name AS author_name, u.username AS author_username, u.avatar_url AS author_avatar,
           TRUE AS saved
    FROM route_saves s
    JOIN routes r ON r.id = s.route_id
    JOIN users u ON u.id = r.user_id
    WHERE s.user_id = ${userId}
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = ${userId} AND b.blocked_id = r.user_id)
           OR (b.blocker_id = r.user_id AND b.blocked_id = ${userId})
      )
    ORDER BY s.created_at DESC LIMIT ${ROUTES_PAGE_SIZE}
  `;
  res.status(200).json({
    published: published.map(mapRouteSummary),
    saved: saved.map(mapRouteSummary),
  });
}

// `numeric` revient en chaîne depuis Postgres ; le client attend des nombres. Même conversion
// explicite que `activityMetrics` dans lib/social.js, et pour la même raison.
function mapRouteSummary(row) {
  return {
    id: row.id,
    name: row.name,
    distanceKm: row.distance_km === null ? null : Number(row.distance_km),
    elevationGainM: row.elevation_gain_m === null ? null : Number(row.elevation_gain_m),
    durationSeconds: row.duration_seconds === null ? null : Number(row.duration_seconds),
    preview: row.preview_points || [],
    startLat: Number(row.start_lat),
    startLng: Number(row.start_lng),
    locality: row.locality,
    countryCode: row.country_code,
    photoUrl: row.photo_url,
    savesCount: Number(row.saves_count),
    saved: row.saved === true,
    createdAt: row.created_at,
    authorName: row.author_name,
    authorUsername: row.author_username,
    authorAvatarUrl: row.author_avatar,
  };
}

// La photo d'un itinéraire — ce qui donne envie d'y aller, là où le tracé dit seulement où c'est.
//
// Même chaîne que les avatars (`api/account/[action].js`) : redimensionnée sur l'appareil, déposée
// dans Vercel Blob, et seule l'URL atterrit en base. Stocker le base64 dans la ligne ferait
// voyager plusieurs centaines de kilo-octets à chaque affichage de la liste de découverte, pour
// une vignette de 52 points.
//
// Plus généreux que l'avatar (500 ko contre 200) : une photo de paysage en 1080 px porte
// nettement plus d'information qu'une pastille de profil, et c'est tout l'intérêt.
const MAX_ROUTE_PHOTO_LENGTH = 500000;
const MAX_ROUTE_PHOTOS_PER_DAY = 20;

function isValidJpegBuffer(buffer) {
  return buffer.length > 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
}

async function handleRoutePhoto(req, res, userId) {
  const { routeId, photoDataURI } = req.body || {};
  if (!isUuid(routeId)) return res.status(400).json({ error: 'bad_request' });

  const { rows } = await sql`SELECT user_id, photo_url FROM routes WHERE id = ${routeId}`;
  if (!rows[0]) return res.status(404).json({ error: 'not_found' });
  // L'autrice seule : sans ce contrôle, n'importe qui pourrait remplacer la photo de n'importe
  // quel itinéraire de la carte.
  if (rows[0].user_id !== userId) return res.status(403).json({ error: 'forbidden' });
  const previousUrl = rows[0].photo_url;

  // Retirer la photo est un cas légitime et sans condition — ni cap, ni validation.
  if (photoDataURI === null || photoDataURI === undefined) {
    await sql`UPDATE routes SET photo_url = NULL WHERE id = ${routeId}`;
    if (previousUrl) del(previousUrl).catch(() => {});
    return res.status(200).json({ ok: true, photoUrl: null });
  }

  if (typeof photoDataURI !== 'string'
      || photoDataURI.length > MAX_ROUTE_PHOTO_LENGTH
      || !photoDataURI.startsWith('data:image/jpeg;base64,')) {
    return res.status(400).json({ error: 'bad_request' });
  }
  if (!(await underDailyCap(`routePhoto:${userId}`, MAX_ROUTE_PHOTOS_PER_DAY))) {
    return res.status(429).json({ error: 'too_many_uploads' });
  }

  let decoded;
  try {
    decoded = Buffer.from(photoDataURI.slice('data:image/jpeg;base64,'.length), 'base64');
  } catch {
    return res.status(400).json({ error: 'bad_request' });
  }
  // Les octets magiques, pas le préfixe annoncé par le client : c'est ce qui empêche vraiment de
  // déposer autre chose qu'une image et de le servir à tous ceux qui consultent la carte.
  if (!isValidJpegBuffer(decoded)) return res.status(400).json({ error: 'not_an_image' });

  const blob = await put(`routes/${routeId}.jpg`, decoded, {
    access: 'public',
    contentType: 'image/jpeg',
    // Chemin stable : un remplacement écrase l'objet au lieu d'en accumuler un par changement.
    addRandomSuffix: false,
    // Et donc un cache à casser, puisque l'URL ne change pas.
    cacheControlMaxAge: 3600,
  });
  await sql`UPDATE routes SET photo_url = ${blob.url} WHERE id = ${routeId}`;
  if (previousUrl && previousUrl !== blob.url) del(previousUrl).catch(() => {});
  res.status(200).json({ ok: true, photoUrl: blob.url });
}
