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
const SESSION_LIFETIME_DAYS = 30;
const SESSION_LIFETIME = `${SESSION_LIFETIME_DAYS}d`;

// --- Renouvellement glissant ---
//
// LE PROBLÈME : un jeton de 30 jours finit par expirer, et le jour où il expire l'app reçoit un
// 401 et redemande de se connecter. Pour quelqu'un qui ouvre RUNUP tous les jours, c'est une
// interruption qui n'apprend rien à personne — sa session n'a jamais cessé d'être légitime.
//
// LA RÉPONSE : à partir du moment où il reste moins de la moitié de sa vie à un jeton, toute
// requête authentifiée en renvoie un neuf dans un en-tête. Le client le range et s'en sert
// ensuite. Quelqu'un qui se sert de l'app ne voit donc jamais d'écran de connexion.
//
// L'ANCIEN JETON N'EST PAS RÉVOQUÉ. Il expire tout seul, dans les 30 jours. Le révoquer casserait
// les requêtes déjà parties avec lui, et surtout : si le client manque l'en-tête (réponse perdue,
// app tuée au mauvais moment), il continue avec l'ancien, qui doit rester valable. Un chevauchement
// de deux jetons vivants est le prix de cette tolérance.
//
// LE PLAFOND, LUI, N'EST PAS NÉGOCIABLE. Sans lui, un jeton volé dont le voleur se sert se
// renouvelle à l'infini : la fenêtre de 30 jours que ce fichier a justement réduite depuis 180
// deviendrait illimitée, et pour celui qui l'exploite plutôt que pour celle à qui il appartient.
// `sid` porte donc l'instant de la VRAIE connexion, recopié de renouvellement en renouvellement,
// et au-delà de 90 jours on cesse de renouveler : le jeton expire normalement et il faut se
// reconnecter.
//
// 90 jours est un arbitrage, et il se paie : une session volée et activement exploitée vit trois
// fois plus longtemps qu'avant. En échange, une session légitime ne redemande de se connecter
// qu'une fois par trimestre au lieu d'une fois par mois. Le fichier avait écarté 180 jours en les
// jugeant « une très longue fenêtre » ; 90 reste en deçà, délibérément.
const RENEWAL_HEADER = 'X-RunUp-Session-Renewed';
const ABSOLUTE_SESSION_DAYS = 90;

/// `sessionStart` est l'instant de la connexion d'origine, en secondes. Absent à la connexion
/// elle-même — c'est maintenant —, recopié à chaque renouvellement pour que le plafond compte
/// depuis le vrai début et non depuis le dernier jeton émis.
async function signSession(userId, sessionStart = null) {
  const maintenant = Math.floor(Date.now() / 1000);
  return await new SignJWT({ sub: userId, sid: sessionStart ?? maintenant })
    .setProtectedHeader({ alg: 'HS256' })
    // A unique id per issued token — this is the handle `revoked_tokens` (and therefore
    // /api/auth/signout) uses to name ONE token, so signing out on one device doesn't have to
    // invalidate her other devices too.
    .setJti(crypto.randomUUID())
    .setIssuedAt()
    .setExpirationTime(SESSION_LIFETIME)
    .sign(sessionSecret());
}

/// Le début de session que porte un jeton.
///
/// Les jetons émis avant `sid` n'en ont pas : on retombe sur leur propre date d'émission, ce qui
/// est la lecture la plus prudente — leur plafond court depuis ce qu'on sait d'eux, et jamais
/// depuis « maintenant », qui le repousserait indéfiniment à chaque renouvellement.
function sessionStartOf(claims) {
  if (claims && Number.isFinite(claims.sid)) return claims.sid;
  if (claims && Number.isFinite(claims.iat)) return claims.iat;
  return Math.floor(Date.now() / 1000);
}

/// Faut-il renvoyer un jeton neuf ? Pure, donc testée (`tests/auth.test.js`).
function shouldRenewSession(claims, nowSeconds = Math.floor(Date.now() / 1000)) {
  if (!claims || !Number.isFinite(claims.exp)) return false;
  // Déjà expiré : ce n'est plus un renouvellement, c'est une résurrection.
  if (claims.exp <= nowSeconds) return false;
  if (nowSeconds - sessionStartOf(claims) >= ABSOLUTE_SESSION_DAYS * 86400) return false;
  return (claims.exp - nowSeconds) < (SESSION_LIFETIME_DAYS * 86400) / 2;
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
async function requireAuth(req, res = null) {
  const claims = await verifiedSessionClaims(req);
  if (!claims) return null;
  // `res` est facultatif pour que les appelants qui n'en ont pas — et les tests — continuent de
  // marcher ; mais chaque route en a un, et le lui passer est ce qui fait vivre le renouvellement.
  if (res && typeof res.setHeader === 'function' && !res.headersSent && shouldRenewSession(claims)) {
    try {
      res.setHeader(RENEWAL_HEADER, await signSession(claims.sub, sessionStartOf(claims)));
    } catch (err) {
      // Un renouvellement raté ne doit JAMAIS faire échouer la requête qui le portait : la
      // session en cours reste parfaitement valable, et la prochaine requête réessaiera.
      console.error('renouvellement de session impossible', err);
    }
  }
  return claims.sub;
}

// --- Sign in with Apple: verify the identity token AuthenticationServices gave the app ---

const appleJWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

async function verifyAppleIdentityToken(identityToken) {
  const { payload } = await jwtVerify(identityToken, appleJWKS, {
    issuer: 'https://appleid.apple.com',
    audience: requireEnv('APPLE_BUNDLE_ID'), // com.hicsuntco.runup
  });
  // NORMALISÉE À LA SOURCE. `users.email` est déclaré UNIQUE, et l'unicité de Postgres est
  // SENSIBLE À LA CASSE : une inscription par mot de passe range « charlotte@x.com » (le chemin
  // mot de passe minusculise déjà), Apple renvoie « Charlotte@X.com », et l'INSERT ne déclenche
  // aucun conflit. Deux comptes pour la même personne, dont un vide — et la branche prévue pour
  // exactement ce cas ne s'exécute jamais, puisque la contrainte ne saute pas.
  //
  // Pire : `users.email_sha256` est calculée sur `lower(btrim(email))`, donc les deux comptes
  // portent la MÊME empreinte et la même personne apparaît en double dans « tes contacts ».
  const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : null;
  return { sub: payload.sub, email };
}

module.exports = {
  signSession, requireAuth, verifiedSessionClaims, verifyAppleIdentityToken, bcrypt,
  // Exportés pour les tests et pour que le nom de l'en-tête ait UNE écriture côté serveur.
  shouldRenewSession, sessionStartOf, RENEWAL_HEADER, SESSION_LIFETIME_DAYS, ABSOLUTE_SESSION_DAYS,
};
