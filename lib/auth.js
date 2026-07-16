// Session tokens (our own JWTs, issued after either sign-in method succeeds) plus verification of
// the identity token Apple hands the app directly — nothing here trusts a client-supplied user
// id, only a token cryptographically verified against Apple's own public keys, or a password
// checked against its stored bcrypt hash.
const { SignJWT, jwtVerify, createRemoteJWKSet } = require('jose');
const bcrypt = require('bcryptjs');

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

function sessionSecret() {
  return new TextEncoder().encode(requireEnv('RUNUP_SESSION_SECRET'));
}

// --- Our own session tokens ---

async function signSession(userId) {
  return await new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('180d')
    .sign(sessionSecret());
}

/// Returns the authenticated user id, or null — every protected route starts with this instead
/// of trusting anything the client claims about who it is.
async function requireAuth(req) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, sessionSecret());
    return payload.sub;
  } catch {
    return null;
  }
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

module.exports = { signSession, requireAuth, verifyAppleIdentityToken, bcrypt };
