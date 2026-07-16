// Posts one completed activity (a run, a strength/mobility session, or a badge unlock) to the
// user's club feed, and credits its XP to their real, server-side total — this is what makes the
// leaderboard and feed genuinely backed by real actions instead of mock data.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

const ALLOWED_TYPES = new Set(['run', 'strength', 'badge']);

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

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
});
