// Consolidated into one dynamic route ([action] = apple | signup | login) instead of 3 separate
// files — Vercel's Hobby plan caps a deployment at 12 serverless functions, and 3 files here plus
// the rest of the backend went over that. Behavior is unchanged: /api/auth/apple, /api/auth/signup,
// /api/auth/login still work exactly as before.
const { sql } = require('../../lib/db');
const { verifyAppleIdentityToken, signSession, bcrypt } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  switch (req.query.action) {
    case 'apple':
      return handleApple(req, res);
    case 'signup':
      return handleSignup(req, res);
    case 'login':
      return handleLogin(req, res);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Sign in with Apple — verify the identity token against Apple's own public keys (never trust a
// client-claimed user id) and upsert a user keyed on Apple's stable `sub`.
async function handleApple(req, res) {
  const { identityToken, name } = req.body || {};
  if (!identityToken) return res.status(400).json({ error: 'bad_request' });

  let claims;
  try {
    claims = await verifyAppleIdentityToken(identityToken);
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }

  const { rows: existing } = await sql`SELECT id, name, xp_total FROM users WHERE apple_sub = ${claims.sub}`;
  let user = existing[0];
  if (!user) {
    // Apple only sends a display name on the very first sign-in ever for this Apple ID on this
    // app (every later sign-in omits it) — trust what the client passed this one time, fall back
    // to a generic name if Apple withheld even that.
    const displayName = (name && name.trim()) || 'Coureur';
    const { rows } = await sql`
      INSERT INTO users (apple_sub, email, name)
      VALUES (${claims.sub}, ${claims.email}, ${displayName})
      RETURNING id, name, xp_total
    `;
    user = rows[0];
  }

  const token = await signSession(user.id);
  res.status(200).json({ token, user: { id: user.id, name: user.name, xpTotal: user.xp_total } });
}

// Email + password sign-up. Passwords are never stored in plain text — only a bcrypt hash.
async function handleSignup(req, res) {
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
}

async function handleLogin(req, res) {
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
}
