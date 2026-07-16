// Creates a club and auto-joins the creator. v1: a user can only be in one club at a time.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

function randomInviteCode() {
  // No 0/O/1/I — avoids ambiguity when a code is read aloud or typed by hand.
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return code;
}

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  const { rows: already } = await sql`SELECT club_id FROM club_members WHERE user_id = ${userId}`;
  if (already.length > 0) return res.status(409).json({ error: 'already_in_club' });

  const { name } = req.body || {};
  if (!name || !name.trim()) return res.status(400).json({ error: 'bad_request' });

  let club;
  // Retry on the astronomically rare invite_code collision instead of trusting a single attempt.
  for (let attempt = 0; attempt < 5 && !club; attempt++) {
    const code = randomInviteCode();
    try {
      const { rows } = await sql`
        INSERT INTO clubs (name, invite_code, created_by)
        VALUES (${name.trim()}, ${code}, ${userId})
        RETURNING id, name, invite_code
      `;
      club = rows[0];
    } catch (e) {
      if (!String(e.message).includes('invite_code')) throw e;
    }
  }
  if (!club) return res.status(500).json({ error: 'could_not_create' });

  await sql`INSERT INTO club_members (club_id, user_id) VALUES (${club.id}, ${userId})`;
  res.status(201).json({ id: club.id, name: club.name, inviteCode: club.invite_code });
});
