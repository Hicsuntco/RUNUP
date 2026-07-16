// Toggles the caller's kudos on one activity — real per-user state (activity_kudos), not a local
// @State Set that resets whenever the app relaunches.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  const { activityId } = req.body || {};
  if (!activityId) return res.status(400).json({ error: 'bad_request' });

  const { rows: existing } = await sql`
    SELECT 1 FROM activity_kudos WHERE activity_id = ${activityId} AND user_id = ${userId}
  `;

  if (existing.length > 0) {
    await sql`DELETE FROM activity_kudos WHERE activity_id = ${activityId} AND user_id = ${userId}`;
    res.status(200).json({ kudoed: false });
  } else {
    await sql`
      INSERT INTO activity_kudos (activity_id, user_id) VALUES (${activityId}, ${userId})
      ON CONFLICT DO NOTHING
    `;
    res.status(200).json({ kudoed: true });
  }
});
