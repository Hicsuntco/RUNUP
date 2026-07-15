// Email + password sign-up. Passwords are never stored in plain text — only a bcrypt hash.
const { sql } = require('../../lib/db');
const { bcrypt, signSession } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  const { email, password, name } = req.body || {};
  if (!email || !password || !name || !name.trim()) return res.status(400).json({ error: 'bad_request' });
  if (password.length < 8) return res.status(400).json({ error: 'weak_password' });

  const normalizedEmail = String(email).trim().toLowerCase();
  const { rows: existing } = await sql`SELECT id FROM users WHERE email = ${normalizedEmail}`;
  if (existing.length > 0) return res.status(409).json({ error: 'email_taken' });

  const passwordHash = await bcrypt.hash(password, 12);
  const { rows } = await sql`
    INSERT INTO users (email, password_hash, name)
    VALUES (${normalizedEmail}, ${passwordHash}, ${name.trim()})
    RETURNING id, name, xp_total
  `;
  const user = rows[0];

  const token = await signSession(user.id);
  res.status(201).json({ token, user: { id: user.id, name: user.name, xpTotal: user.xp_total } });
});
