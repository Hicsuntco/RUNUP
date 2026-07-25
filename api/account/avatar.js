// Sets (or clears) the caller's profile photo — a data URI, resized/compressed client-side
// (see ProfileView.setAvatar) before it ever reaches here. Stored directly in Postgres rather
// than a real object-storage service: at a small-club scale and with the client already capping
// it to a ~240pt JPEG thumbnail, this stays cheap without needing a new external dependency.
// TODO once real scale hits: move to object storage (Vercel Blob/S3) and return a URL instead of
// inlining the blob in every leaderboard/feed/comments row — fine for now, not forever.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

// Generous for a compressed 240pt-thumbnail data URI, tight enough that a tampered client can't
// use this column to smuggle in something much larger.
const MAX_LENGTH = 200000;

// The client always sends a JPEG (ProfileView.setAvatar calls UIImage.jpegData) — checking the
// real magic bytes, not just the client-declared "data:image/..." prefix, is what actually stops
// a tampered client from storing (and serving to every club member via the leaderboard/feed
// queries) something that isn't a real image at all, including an SVG with an embedded <script>.
function isValidJpeg(buffer) {
  return buffer.length > 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
}

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  // Per-user daily cap — every other write endpoint in this codebase has one (coach_usage
  // pattern), this was the one missing it: with no limit, a buggy retry loop or a scripted
  // attacker could hammer this with 200KB uploads indefinitely, unbounded write/storage cost.
  try {
    const { rows } = await sql`
      INSERT INTO coach_usage (key, day, count) VALUES (${'avatar:' + userId}, CURRENT_DATE, 1)
      ON CONFLICT (key, day) DO UPDATE SET count = coach_usage.count + 1
      RETURNING count
    `;
    if (rows[0] && rows[0].count > 20) return res.status(429).json({ error: 'too_many_uploads' });
  } catch { /* the cap must never take avatar upload down with it */ }

  const { avatarDataURI } = req.body || {};
  if (avatarDataURI === null || avatarDataURI === undefined) {
    await sql`UPDATE users SET avatar_data = NULL WHERE id = ${userId}`;
    return res.status(200).json({ ok: true });
  }

  if (typeof avatarDataURI !== 'string' || avatarDataURI.length > MAX_LENGTH || !avatarDataURI.startsWith('data:image/jpeg;base64,')) {
    return res.status(400).json({ error: 'bad_request' });
  }
  const base64 = avatarDataURI.slice('data:image/jpeg;base64,'.length);
  let decoded;
  try {
    decoded = Buffer.from(base64, 'base64');
  } catch {
    return res.status(400).json({ error: 'bad_request' });
  }
  if (!isValidJpeg(decoded)) return res.status(400).json({ error: 'not_an_image' });

  await sql`UPDATE users SET avatar_data = ${avatarDataURI} WHERE id = ${userId}`;
  res.status(200).json({ ok: true });
});
