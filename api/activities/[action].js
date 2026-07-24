// Consolidated into one dynamic route ([action] = create | feed | kudos) instead of 3 separate
// files — see api/auth/[action].js for why. /api/activities/create, /feed, /kudos still work
// exactly as before.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling, isUuid } = require('../../lib/http');
const { sendPushToUser } = require('../../lib/apns');
const { containsObjectionableContent } = require('../../lib/moderation');

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
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Posts one completed activity (a run, a strength/mobility session, or a badge unlock) to the
// user's club feed, and credits its XP to their real, server-side total — this is what makes the
// leaderboard and feed genuinely backed by real actions instead of mock data.
async function handleCreate(req, res, userId) {
  const { clientId, type, text, xpEarned, distanceKm } = req.body || {};
  const cleanText = typeof text === 'string' ? text.trim().slice(0, 200) : '';
  if (!isUuid(clientId) || !ALLOWED_TYPES.has(type) || !cleanText || typeof xpEarned !== 'number') {
    return res.status(400).json({ error: 'bad_request' });
  }
  // The client computes xpEarned locally (same gamification formula the rest of the app already
  // uses) — this cap just stops a tampered client from inflating the shared leaderboard, it's not
  // meant to be the real anti-cheat mechanism.
  const xp = Math.max(0, Math.min(500, Math.round(xpEarned)));
  // Only 'run' activities carry a real distance — a structured column (rather than parsing it
  // back out of `text`) is what lets club challenges compute real collective progress.
  const distance = type === 'run' && typeof distanceKm === 'number' && distanceKm > 0 ? distanceKm : null;

  // Checked before the INSERT below — this is the referral-reward trigger (see
  // `grantReferralRewardIfNeeded`): a signup that goes on to log a real first activity, not just
  // an install.
  const { rows: priorActivityRows } = await sql`SELECT COUNT(*)::int AS count FROM activities WHERE user_id = ${userId}`;
  const isFirstActivity = priorActivityRows[0].count === 0;

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
  await Promise.all(
    recipients.map((r) =>
      sendPushToUser(sql, r.user_id, { title: 'Le Club', body: `${posterName} ${text}` })
    )
  );
}

async function handleFeed(req, res, userId) {
  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id;
  if (!clubId) return res.status(200).json({ items: [] });

  const { rows } = await sql`
    SELECT a.id, a.text, a.created_at, u.name, u.id AS user_id,
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

  // Scoped to the caller's own club, like the comments handlers always were — without this,
  // anyone holding an activity UUID could kudos (and push-notify) across club boundaries.
  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id;
  const { rows: activityRows } = await sql`SELECT user_id, text, club_id FROM activities WHERE id = ${activityId}`;
  const activity = activityRows[0];
  if (!activity || !clubId || activity.club_id !== clubId) return res.status(404).json({ error: 'not_found' });

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
    await sendPushToUser(sql, activity.user_id, {
      title: 'Le Club',
      body: `${kudoer[0]?.name || 'Quelqu’un'} a applaudi : ${activity.text}`,
    });
  }
  res.status(200).json({ kudoed: true });
}

// Lists real comments on one activity, oldest first (a conversation reads top-down) — scoped to
// the caller's own club (an activity from another club, or one that's since had its club_id
// cleared, 404s rather than leaking it) and filtered the same way the feed already is: no
// comments from anyone the caller has blocked.
async function handleCommentsList(req, res, userId) {
  const { activityId } = req.query || {};
  if (!isUuid(activityId)) return res.status(400).json({ error: 'bad_request' });

  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id;
  if (!clubId) return res.status(200).json({ items: [] });

  const { rows: activityRows } = await sql`SELECT club_id FROM activities WHERE id = ${activityId}`;
  if (activityRows[0]?.club_id !== clubId) return res.status(404).json({ error: 'not_found' });

  const { rows } = await sql`
    SELECT c.id, c.text, c.created_at, u.id AS user_id, u.name
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

  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id;
  if (!clubId) return res.status(409).json({ error: 'not_in_club' });

  const { rows: activityRows } = await sql`SELECT club_id, user_id, text FROM activities WHERE id = ${activityId}`;
  const activity = activityRows[0];
  if (!activity || activity.club_id !== clubId) return res.status(404).json({ error: 'not_found' });

  const { rows: inserted } = await sql`
    INSERT INTO activity_comments (activity_id, user_id, text)
    VALUES (${activityId}, ${userId}, ${trimmed})
    RETURNING id, created_at
  `;
  const { rows: me } = await sql`SELECT name FROM users WHERE id = ${userId}`;
  const commenterName = me[0]?.name || 'Toi';

  // Push before the response — Vercel may freeze the function once the response is sent.
  if (activity.user_id !== userId) {
    await sendPushToUser(sql, activity.user_id, {
      title: 'Le Club',
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
