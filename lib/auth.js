// Session tokens (our own JWTs, issued after either sign-in method succeeds) plus verification of
// the identity token Apple hands the app directly — nothing here trusts a client-supplied user
// id, only a token cryptographically verified against Apple's own public keys, or a password
// checked against its stored bcrypt hash.
const { SignJWT, jwtVerify, createRemoteJWKSet } = require('jose');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

function sessionSecret() {
  return new TextEncoder().encode(requireEnv('RUNUP_SESSION_SECRET'));
}

// --- Our own session tokens ---

// 30 days, down from the 180 these used to live for. A bearer token that grants full access to an
// account is the one credential the app stores on disk (Keychain), and 6 months was a very long
// window for something that, until `revoked_tokens` below, could not be taken back at all. 30 days
// still means she practically never has to sign in again (the app re-authenticates silently on
// every launch that has a valid token), while bounding how long a leaked one stays useful.
const SESSION_LIFETIME = '30d';

async function signSession(userId) {
  return await new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: 'HS256' })
    // A unique id per issued token — this is the handle `revoked_tokens` (and therefore
    // /api/auth/signout) uses to name ONE token, so signing out on one device doesn't have to
    // invalidate her other devices too.
    .setJti(crypto.randomUUID())
    .setIssuedAt()
    .setExpirationTime(SESSION_LIFETIME)
    .sign(sessionSecret());
}

// Postgres `undefined_table`. Deploy order isn't atomic here: Vercel redeploys on push, while
// db/schema.sql is re-run by hand in Neon's SQL editor — so this code can be live for a while
// before `revoked_tokens` exists. Detected explicitly rather than swallowing every DB error, which
// would silently turn a real outage into "revocation quietly stopped working".
function isMissingRevokedTokensTable(err) {
  return !!err && (err.code === '42P01' || String(err.message || '').includes('revoked_tokens'));
}

/// Verifies the Bearer token and returns its full verified payload (sub, jti, exp), or null.
/// `requireAuth` is what routes normally use; this exists for the one caller that needs the
/// token's own id rather than just its owner — api/auth/[action].js's `signout`, which files that
/// jti in `revoked_tokens`.
async function verifiedSessionClaims(req) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return null;

  let payload;
  try {
    ({ payload } = await jwtVerify(token, sessionSecret(), { algorithms: ['HS256'] }));
  } catch {
    return null; // bad signature, expired, or malformed
  }

  const { sql } = require('./db');
  try {
    // Two checks in a single round trip:
    //  - the user still exists: after account deletion the old token otherwise still
    //    "authenticates" and every route then dies on an FK violation against the vanished user id
    //    (raw 500s instead of a clean 401 that signs the client out);
    //  - the token hasn't been revoked by a sign-out.
    // Tokens issued before `jti` existed don't carry one: `jti = NULL` matches no row, so they
    // stay valid exactly as before instead of every currently-signed-in user being logged out by
    // the deploy that ships this. Such a token simply isn't revocable — nothing names it — and it
    // ages out on its own under the old 180d expiry; the next sign-in issues a revocable one.
    const { rows } = await sql`
      SELECT 1 FROM users
      WHERE id = ${payload.sub}
        AND NOT EXISTS (SELECT 1 FROM revoked_tokens WHERE jti = ${payload.jti || null})
    `;
    return rows.length > 0 ? payload : null;
  } catch (err) {
    if (!isMissingRevokedTokensTable(err)) return null;
    // Migration not run yet — fall back to the pre-revocation check rather than 401-ing every
    // request in the app until it is.
    try {
      const { rows } = await sql`SELECT 1 FROM users WHERE id = ${payload.sub}`;
      return rows.length > 0 ? payload : null;
    } catch {
      return null;
    }
  }
}

/// Returns the authenticated user id, or null — every protected route starts with this instead
/// of trusting anything the client claims about who it is.
async function requireAuth(req) {
  const claims = await verifiedSessionClaims(req);
  return claims ? claims.sub : null;
}

// --- Sign in with Apple: verify the identity token AuthenticationServices gave the app ---

const appleJWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

async function verifyAppleIdentityToken(identityToken) {
  const { payload } = await jwtVerify(identityToken, appleJWKS, {
    issuer: 'https://appleid.apple.com',
    audience: requireEnv('APPLE_BUNDLE_ID'), // com.hicsuntco.runup
  });
  return { sub: payload.sub, email: typeof payload.email === 'string' ? payload.email : null };
}

module.exports = { signSession, requireAuth, verifiedSessionClaims, verifyAppleIdentityToken, bcrypt };
