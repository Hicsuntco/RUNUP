// Real APNs device-token registration — see lib/apns.js for how a token is actually used to send
// a push. /api/notifications/register is called by NotificationService.sendPendingDeviceTokenIfSignedIn
// on iOS, right after the OS hands back a token and whenever she signs in.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'register':
      return handleRegister(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Upserts on `token` (not `user_id`) — the primary key is the physical device, so a device that
// re-registers after a different account signs in on it moves ownership to that account instead
// of leaving a duplicate row still pointing at whoever used it before.
async function handleRegister(req, res, userId) {
  const { deviceToken } = req.body || {};
  // A real APNs token is 64 hex chars — the format check rejects arbitrary junk being stored
  // (and later sent to Apple) as a "token", with headroom in the length cap for format changes.
  if (!deviceToken || typeof deviceToken !== 'string' || deviceToken.length > 200 || !/^[0-9a-f]+$/i.test(deviceToken)) {
    return res.status(400).json({ error: 'bad_request' });
  }
  // Only iOS exists today — `platform` is stored for whenever that stops being true, not read yet.
  await sql`
    INSERT INTO device_tokens (token, user_id, platform)
    VALUES (${deviceToken}, ${userId}, 'ios')
    ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id
  `;
  res.status(200).json({ ok: true });
}
