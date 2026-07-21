// Shared by api/auth/[action].js (assigning a code at signup) and api/me.js (backfilling a code
// for any account created before the referral feature existed) — was duplicated in both files
// before this, which is how api/me.js ended up never backfilling at all.
const { sql } = require('./db');

// No 0/O/1/I — avoids ambiguity when a code is read aloud, screenshotted, or typed by hand.
function randomReferralCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return code;
}

async function generateUniqueReferralCode() {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomReferralCode();
    const { rows } = await sql`SELECT 1 FROM users WHERE referral_code = ${code}`;
    if (rows.length === 0) return code;
  }
  return null; // astronomically unlikely — this one account just goes without a code
}

module.exports = { generateUniqueReferralCode };
