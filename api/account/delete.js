// Account deletion — required by App Store guideline 5.1.1(v) whenever an app offers account
// creation: users must be able to delete their account from inside the app, not just deactivate
// it. Deleting the user row cascades (ON DELETE CASCADE in db/schema.sql) to their club
// membership, posted activities, and kudos — nothing about them is left behind on the server.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

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
});
