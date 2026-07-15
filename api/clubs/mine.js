// The user's club (if any) plus a real, computed leaderboard — ranked by each member's actual
// xp_total, not a fixed/mocked position. Returns { club: null } if the user hasn't joined or
// created a club yet.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  const { rows: memberRows } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  if (memberRows.length === 0) return res.status(200).json({ club: null, leaderboard: [] });

  const clubId = memberRows[0].club_id;
  const { rows: clubRows } = await sql`SELECT id, name, invite_code FROM clubs WHERE id = ${clubId}`;
  const club = clubRows[0];

  const { rows: leaderboard } = await sql`
    SELECT u.id, u.name, u.xp_total, RANK() OVER (ORDER BY u.xp_total DESC) AS rank
    FROM club_members cm
    JOIN users u ON u.id = cm.user_id
    WHERE cm.club_id = ${clubId}
    ORDER BY u.xp_total DESC
  `;

  const { rows: countRows } = await sql`SELECT COUNT(*)::int AS count FROM club_members WHERE club_id = ${clubId}`;

  res.status(200).json({
    club: { id: club.id, name: club.name, inviteCode: club.invite_code, memberCount: countRows[0].count },
    leaderboard: leaderboard.map((r) => ({
      id: r.id, name: r.name, xp: r.xp_total, rank: Number(r.rank), isMe: r.id === userId,
    })),
  });
});
