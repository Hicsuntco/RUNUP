const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  const { rows: already } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  if (already.length > 0) return res.status(409).json({ error: 'already_in_club' });

  const { inviteCode } = req.body || {};
  if (!inviteCode) return res.status(400).json({ error: 'bad_request' });

  const { rows } = await sql`SELECT id, name FROM clubs WHERE invite_code = ${String(inviteCode).trim().toUpperCase()}`;
  const club = rows[0];
  if (!club) return res.status(404).json({ error: 'not_found' });

  await sql`INSERT INTO club_members (club_id, user_id) VALUES (${club.id}, ${userId})`;
  res.status(200).json({ id: club.id, name: club.name });
});
