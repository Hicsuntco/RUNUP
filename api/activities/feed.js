const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

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
});
