// Google Sign-In — the app hands us the ID token the GoogleSignIn SDK returned; we verify it
// against Google's own public keys and upsert a user keyed on Google's stable `sub`.
const { sql } = require('../../lib/db');
const { verifyGoogleIdToken, signSession } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  const { idToken } = req.body || {};
  if (!idToken) return res.status(400).json({ error: 'bad_request' });

  let claims;
  try {
    claims = await verifyGoogleIdToken(idToken);
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }

  const { rows: existing } = await sql`SELECT id, name, xp_total FROM users WHERE google_sub = ${claims.sub}`;
  let user = existing[0];
  if (!user) {
    const displayName = claims.name || 'Coureur';
    const { rows } = await sql`
      INSERT INTO users (google_sub, email, name)
      VALUES (${claims.sub}, ${claims.email}, ${displayName})
      RETURNING id, name, xp_total
    `;
    user = rows[0];
  }

  const token = await signSession(user.id);
  res.status(200).json({ token, user: { id: user.id, name: user.name, xpTotal: user.xp_total } });
});
