// Consolidated into one dynamic route ([action] = create | feed | kudos) instead of 3 separate
// files — see api/auth/[action].js for why. /api/activities/create, /feed, /kudos still work
// exactly as before.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

const ALLOWED_TYPES = new Set(['run', 'strength', 'badge']);

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
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Posts one completed activity (a run, a strength/mobility session, or a badge unlock) to the
// user's club feed, and credits its XP to their real, server-side total — this is what makes the
// leaderboard and feed genuinely backed by real actions instead of mock data.
async function handleCreate(req, res, userId) {
  const { clientId, type, text, xpEarned } = req.body || {};
  if (!clientId || !ALLOWED_TYPES.has(type) || !text || typeof xpEarned !== 'number') {
    return res.status(400).json({ error: 'bad_request' });
  }
  // The client computes xpEarned locally (same gamification formula the rest of the app already
  // uses) — this cap just stops a tampered client from inflating the shared leaderboard, it's not
  // meant to be the real anti-cheat mechanism.
  const xp = Math.max(0, Math.min(500, Math.round(xpEarned)));

  // Idempotent on clientId: a retried request (flaky network) must not double-count XP or post
  // the same activity to the feed twice.
  const { rows: existing } = await sql`SELECT id FROM activities WHERE client_id = ${clientId}`;
  if (existing.length > 0) return res.status(200).json({ ok: true, duplicate: true });

  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id || null;

  await sql`
    INSERT INTO activities (client_id, user_id, club_id, type, text, xp_earned)
    VALUES (${clientId}, ${userId}, ${clubId}, ${type}, ${text}, ${xp})
  `;
  await sql`UPDATE users SET xp_total = xp_total + ${xp} WHERE id = ${userId}`;

  res.status(201).json({ ok: true });
}

async function handleFeed(req, res, userId) {
  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  const clubId = memberRows[0]?.club_id;
  if (!clubId) return res.status(200).json({ items: [] });

  const { rows } = await sql`
    SELECT a.id, a.text, a.created_at, u.name, u.id AS user_id,
           (SELECT COUNT(*)::int FROM activity_kudos k WHERE k.activity_id = a.id) AS kudos,
           EXISTS(SELECT 1 FROM activity_kudos k WHERE k.activity_id = a.id AND k.user_id = ${userId}) AS kudoed_by_me
    FROM activities a
    JOIN users u ON u.id = a.user_id
    WHERE a.club_id = ${clubId}
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
    })),
  });
}

// Toggles the caller's kudos on one activity — real per-user state (activity_kudos), not a local
// @State Set that resets whenever the app relaunches.
async function handleKudos(req, res, userId) {
  const { activityId } = req.body || {};
  if (!activityId) return res.status(400).json({ error: 'bad_request' });

  const { rows: existing } = await sql`
    SELECT 1 FROM activity_kudos WHERE activity_id = ${activityId} AND user_id = ${userId}
  `;

  if (existing.length > 0) {
    await sql`DELETE FROM activity_kudos WHERE activity_id = ${activityId} AND user_id = ${userId}`;
    res.status(200).json({ kudoed: false });
  } else {
    await sql`
      INSERT INTO activity_kudos (activity_id, user_id) VALUES (${activityId}, ${userId})
      ON CONFLICT DO NOTHING
    `;
    res.status(200).json({ kudoed: true });
  }
}
