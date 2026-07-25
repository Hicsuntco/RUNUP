// Sets (or clears) the caller's profile photo — a data URI, resized/compressed client-side
// (see ProfileView.setAvatar) before it ever reaches here. Stored directly in Postgres rather
// than a real object-storage service: at a small-club scale and with the client already capping
// it to a ~240pt JPEG thumbnail, this stays cheap without needing a new external dependency.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

// Generous for a compressed 240pt-thumbnail data URI, tight enough that a tampered client can't
// use this column to smuggle in something much larger.
const MAX_LENGTH = 200000;

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  const { avatarDataURI } = req.body || {};
  if (avatarDataURI !== null && avatarDataURI !== undefined) {
    if (typeof avatarDataURI !== 'string' || avatarDataURI.length > MAX_LENGTH || !avatarDataURI.startsWith('data:image/')) {
      return res.status(400).json({ error: 'bad_request' });
    }
  }

  await sql`UPDATE users SET avatar_data = ${avatarDataURI || null} WHERE id = ${userId}`;
  res.status(200).json({ ok: true });
});
