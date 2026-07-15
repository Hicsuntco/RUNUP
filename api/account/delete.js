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

  await sql`DELETE FROM users WHERE id = ${userId}`;
  res.status(200).json({ ok: true });
});
