// Consolidated into one dynamic route ([action] = apple | signup | login) instead of 3 separate
// files — Vercel's Hobby plan caps a deployment at 12 serverless functions, and 3 files here plus
// the rest of the backend went over that. Behavior is unchanged: /api/auth/apple, /api/auth/signup,
// /api/auth/login still work exactly as before.
const { sql } = require('../../lib/db');
const { verifyAppleIdentityToken, signSession, bcrypt } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');
const { containsObjectionableContent } = require('../../lib/moderation');
// Real referral loop (see db/schema.sql) — every new account gets its own shareable code;
// signing up with someone else's code links `referred_by`, rewarded later on the referred
// person's first real activity (api/activities/[action].js). Shared with api/me.js, which
// backfills a code for accounts created before this feature existed.
const { generateUniqueReferralCode } = require('../../lib/referral');

// A junk/typo'd/nonexistent code is never a signup error — it just means no referral link, same
// as leaving the field empty.
async function resolveReferrerId(referralCode) {
  if (!referralCode) return null;
  const { rows } = await sql`SELECT id FROM users WHERE referral_code = ${String(referralCode).trim().toUpperCase()}`;
  return rows[0]?.id || null;
}

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
  const { identityToken, name, referralCode } = req.body || {};
  if (!identityToken) return res.status(400).json({ error: 'bad_request' });

  let claims;
  try {
    claims = await verifyAppleIdentityToken(identityToken);
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }

  const { rows: existing } = await sql`SELECT id, name, xp_total, referral_code FROM users WHERE apple_sub = ${claims.sub}`;
  let user = existing[0];
  if (!user) {
    // Apple only sends a display name on the very first sign-in ever for this Apple ID on this
    // app (every later sign-in omits it) — trust what the client passed this one time, fall back
    // to a generic name if Apple withheld even that, or if it fails the content filter (this
    // field isn't itself part of Apple's signed token, so a tampered client could still put
    // anything in it).
    const rawName = name && name.trim();
    const displayName = (rawName && !containsObjectionableContent(rawName)) ? rawName : 'Coureur';
    const referrerId = await resolveReferrerId(referralCode);
    const myReferralCode = await generateUniqueReferralCode();
    const { rows } = await sql`
      INSERT INTO users (apple_sub, email, name, referral_code, referred_by)
      VALUES (${claims.sub}, ${claims.email}, ${displayName}, ${myReferralCode}, ${referrerId})
      RETURNING id, name, xp_total, referral_code
    `;
    user = rows[0];
  } else if (!user.referral_code) {
    // Lazily backfills a code for an account created before the referral feature existed —
    // rather than leaving her (or any early user) permanently without one to share.
    user.referral_code = await generateUniqueReferralCode();
    if (user.referral_code) await sql`UPDATE users SET referral_code = ${user.referral_code} WHERE id = ${user.id}`;
  }

  const token = await signSession(user.id);
  res.status(200).json({ token, user: { id: user.id, name: user.name, xpTotal: user.xp_total, referralCode: user.referral_code } });
}

// Email + password sign-up. Passwords are never stored in plain text — only a bcrypt hash.
async function handleSignup(req, res) {
  const { email, password, name, referralCode } = req.body || {};
  const cleanName = typeof name === 'string' ? name.trim().slice(0, 60) : '';
  if (!email || !password || !cleanName) return res.status(400).json({ error: 'bad_request' });
  if (password.length < 8 || password.length > 200) return res.status(400).json({ error: 'weak_password' });
  if (containsObjectionableContent(cleanName)) return res.status(422).json({ error: 'objectionable_content' });

  const normalizedEmail = String(email).trim().toLowerCase().slice(0, 254);
  const { rows: existing } = await sql`SELECT id FROM users WHERE email = ${normalizedEmail}`;
  if (existing.length > 0) return res.status(409).json({ error: 'email_taken' });

  const passwordHash = await bcrypt.hash(password, 12);
  const referrerId = await resolveReferrerId(referralCode);
  const myReferralCode = await generateUniqueReferralCode();
  let user;
  try {
    const { rows } = await sql`
      INSERT INTO users (email, password_hash, name, referral_code, referred_by)
      VALUES (${normalizedEmail}, ${passwordHash}, ${cleanName}, ${myReferralCode}, ${referrerId})
      RETURNING id, name, xp_total, referral_code
    `;
    user = rows[0];
  } catch (e) {
    // Two concurrent signups with the same email race past the pre-check above — the unique
    // constraint is the real guard, and its violation is a 409, not a 500.
    if (String(e.message).includes('users_email_key')) {
      return res.status(409).json({ error: 'email_taken' });
    }
    throw e;
  }

  const token = await signSession(user.id);
  res.status(201).json({ token, user: { id: user.id, name: user.name, xpTotal: user.xp_total, referralCode: user.referral_code } });
}

async function handleLogin(req, res) {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'bad_request' });

  const normalizedEmail = String(email).trim().toLowerCase();
  const { rows } = await sql`SELECT id, name, xp_total, password_hash, referral_code FROM users WHERE email = ${normalizedEmail}`;
  const user = rows[0];
  // Same "invalid_credentials" whether the email doesn't exist or the password's wrong — doesn't
  // confirm to a caller which emails have an account.
  if (!user || !user.password_hash) return res.status(401).json({ error: 'invalid_credentials' });

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) return res.status(401).json({ error: 'invalid_credentials' });

  if (!user.referral_code) {
    user.referral_code = await generateUniqueReferralCode();
    if (user.referral_code) await sql`UPDATE users SET referral_code = ${user.referral_code} WHERE id = ${user.id}`;
  }

  const token = await signSession(user.id);
  res.status(200).json({ token, user: { id: user.id, name: user.name, xpTotal: user.xp_total, referralCode: user.referral_code } });
}
