// Sign in with Apple — the app hands us the identity token AuthenticationServices returned; we
// verify it against Apple's own public keys (never trust a client-claimed user id) and upsert a
// user keyed on Apple's stable `sub`.
const { sql } = require('../../lib/db');
const { verifyAppleIdentityToken, signSession } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

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
});
