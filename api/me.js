// Bootstrap call after sign-in / on app launch — current user's identity, XP total, and which
// club (if any) they belong to.
const { sql } = require('../lib/db');
const { requireAuth } = require('../lib/auth');
const { withErrorHandling } = require('../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  const { rows } = await sql`
    SELECT u.id, u.name, u.xp_total, u.referral_code, cm.club_id
    FROM users u
    LEFT JOIN club_members cm ON cm.user_id = u.id
    WHERE u.id = ${userId}
  `;
  const row = rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });

  res.status(200).json({ id: row.id, name: row.name, xpTotal: row.xp_total, referralCode: row.referral_code, clubId: row.club_id || null });
});
