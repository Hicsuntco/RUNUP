const { sql } = require('../../lib/db');
const { bcrypt, signSession } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'bad_request' });

  const normalizedEmail = String(email).trim().toLowerCase();
  const { rows } = await sql`SELECT id, name, xp_total, password_hash FROM users WHERE email = ${normalizedEmail}`;
  const user = rows[0];
  // Same "invalid_credentials" whether the email doesn't exist or the password's wrong — doesn't
  // confirm to a caller which emails have an account.
  if (!user || !user.password_hash) return res.status(401).json({ error: 'invalid_credentials' });

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) return res.status(401).json({ error: 'invalid_credentials' });

  const token = await signSession(user.id);
  res.status(200).json({ token, user: { id: user.id, name: user.name, xpTotal: user.xp_total } });
});
