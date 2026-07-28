// Consolidated into one dynamic route ([action] = create | feed | kudos) instead of 3 separate
// files — see api/auth/[action].js for why. /api/activities/create, /feed, /kudos still work
// exactly as before.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling, isUuid } = require('../../lib/http');
const { sendPushToUser, sendPushToUsers } = require('../../lib/apns');
const { containsObjectionableContent } = require('../../lib/moderation');
const { underDailyCap } = require('../../lib/rateLimit');
const { canViewActivity } = require('../../lib/social');

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
  const { clientId, type, text, xpEarned, distanceKm } = req.body || {};
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
  // Only 'run' activities carry a real distance — a structured column (rather than parsing it
  // back out of `text`) is what lets club challenges compute real collective progress. Finite +
  // capped at 500 km: `Infinity > 0` is true in JS, and a tampered client's `1e12` would
  // otherwise instantly "complete" every club challenge (progress is a raw SUM).
  const distance = type === 'run' && Number.isFinite(distanceKm) && distanceKm > 0
    ? Math.min(distanceKm, 500)
    : null;

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
    INSERT INTO activities (client_id, user_id, club_id, type, text, xp_earned, distance_km)
    VALUES (${clientId}, ${userId}, ${clubId}, ${type}, ${cleanText}, ${xp}, ${distance})
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
