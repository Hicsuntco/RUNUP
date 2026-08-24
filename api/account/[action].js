// Les deux opérations sur le compte lui-même : la photo de profil et la suppression.
//
// Elles vivaient dans deux fichiers (`avatar.js` et `delete.js`). Or Vercel compte UN fichier
// sous `api/` = UNE fonction serverless, et le plan Hobby en autorise douze : le treizième
// fichier (`api/events.js`, ajouté avec l'analytique) a fait échouer TOUT déploiement production,
// CLI comme git, avec « No more than 12 Serverless Functions ». Les regrouper derrière le même
// routeur `[action]` que `activities`, `friends`, `clubs`, `auth`, `moderation` et `strava` rend
// le déploiement à nouveau possible sans rien changer aux URL : `/api/account/avatar` et
// `/api/account/delete` répondent exactement comme avant, donc aucune version de l'app déjà
// installée n'est affectée.
const { put, del } = require('@vercel/blob');
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

// Generous for a compressed 240pt-thumbnail data URI, tight enough that a tampered client can't
// use this to smuggle in something much larger.
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

  switch (req.query.action) {
    case 'avatar':
      return handleAvatar(req, res, userId);
    case 'delete':
      return handleDelete(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Sets (or clears) the caller's profile photo — a data URI, resized/compressed client-side
// (see ProfileView.setAvatar) before it ever reaches here. Uploaded to Vercel Blob storage and
// only the resulting URL is kept in Postgres (`users.avatar_url`) — the old approach inlined the
// full base64 blob directly in the `users` row, which meant every leaderboard/feed/comments query
// that joined in an avatar was shipping a several-hundred-KB payload down the wire even though
// only a 40pt circle was ever drawn from it. A URL is a few dozen bytes; the client fetches and
// caches the actual image itself, once, only where it's shown.
//
// Requires a Blob store connected to this Vercel project (Storage tab → Create Database → Blob) —
// once connected, Vercel injects BLOB_READ_WRITE_TOKEN automatically, nothing else to configure.
async function handleAvatar(req, res, userId) {
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

  // Best-effort: delete the previous blob (if any) so a removed/replaced avatar doesn't linger
  // in storage forever. Never blocks the actual update on failure — a stray orphaned blob costs
  // pennies; failing her avatar change over cleanup wouldn't be a fair trade.
  const { rows: existingRows } = await sql`SELECT avatar_url FROM users WHERE id = ${userId}`;
  const previousUrl = existingRows[0]?.avatar_url;

  const { avatarDataURI } = req.body || {};
  if (avatarDataURI === null || avatarDataURI === undefined) {
    await sql`UPDATE users SET avatar_data = NULL, avatar_url = NULL WHERE id = ${userId}`;
    if (previousUrl) del(previousUrl).catch(() => {});
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

  const blob = await put(`avatars/${userId}.jpg`, decoded, {
    access: 'public',
    contentType: 'image/jpeg',
    // A stable, user-scoped path means a re-upload replaces the same object rather than
    // accumulating one blob per change — addRandomSuffix would defeat that and leak storage.
    addRandomSuffix: false,
    // Every re-upload needs a fresh cache-bust: the pathname (and therefore the URL) stays the
    // same, so without this her old photo would keep showing from CDN/client caches after a
    // real change until each cache's own TTL happened to expire.
    cacheControlMaxAge: 3600,
  });

  await sql`UPDATE users SET avatar_data = NULL, avatar_url = ${blob.url} WHERE id = ${userId}`;
  if (previousUrl && previousUrl !== blob.url) del(previousUrl).catch(() => {});
  res.status(200).json({ ok: true, avatarUrl: blob.url });
}

// Account deletion — required by App Store guideline 5.1.1(v) whenever an app offers account
// creation: users must be able to delete their account from inside the app, not just deactivate
// it. Deleting the user row cascades (ON DELETE CASCADE in db/schema.sql) to their club
// membership, posted activities, and kudos — nothing about them is left behind on the server.
async function handleDelete(req, res, userId) {
  // Revoke RunUp's Strava grant before the row (and its tokens) vanish — otherwise the app
  // stays authorized on her Strava account invisibly, with no way left to undo it from our side.
  try {
    const { rows } = await sql`SELECT access_token FROM strava_connections WHERE user_id = ${userId}`;
    if (rows[0]) {
      await fetch('https://www.strava.com/oauth/deauthorize', {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: `access_token=${encodeURIComponent(rows[0].access_token)}`,
      });
    }
  } catch { /* deletion must not fail because Strava is unreachable */ }

  await sql`DELETE FROM users WHERE id = ${userId}`;
  // coach_usage rows are keyed by string ("<prefix>:<id>"), not an FK — clean them up explicitly
  // so no user-linked identifier survives deletion (guideline 5.1.1(v)). A suffix match instead of
  // an exact prefix list so a future cap (a new "<prefix>:" key) can't silently be forgotten here
  // the way "avatar:<id>" originally was.
  await sql`DELETE FROM coach_usage WHERE key LIKE ${'%:' + userId}`;
  res.status(200).json({ ok: true });
}
