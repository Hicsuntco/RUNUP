// Real Strava OAuth connect/disconnect/import — client_secret never leaves this server (see
// lib/strava.js). Not functional until STRAVA_CLIENT_ID/STRAVA_CLIENT_SECRET are set in Vercel,
// from a Strava API application (https://www.strava.com/settings/api) — see lib/strava.js.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling } = require('../../lib/http');
const { exchangeCodeForTokens, validAccessToken, fetchRecentRuns } = require('../../lib/strava');

module.exports = withErrorHandling(async function handler(req, res) {
  const userId = await requireAuth(req);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'connect':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleConnect(req, res, userId);
    case 'disconnect':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleDisconnect(req, res, userId);
    case 'status':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleStatus(req, res, userId);
    case 'importActivities':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleImportActivities(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

// Completes the OAuth handshake the app kicked off via ASWebAuthenticationSession — exchanges the
// one-time authorization code for real tokens and stores them (upsert: reconnecting replaces the
// old pair rather than erroring).
async function handleConnect(req, res, userId) {
  const { code } = req.body || {};
  if (!code) return res.status(400).json({ error: 'bad_request' });

  let tokens;
  try {
    tokens = await exchangeCodeForTokens(code);
  } catch {
    return res.status(502).json({ error: 'strava_unreachable' });
  }
  if (!tokens.access_token || !tokens.athlete?.id) return res.status(502).json({ error: 'strava_invalid_response' });

  await sql`
    INSERT INTO strava_connections (user_id, strava_athlete_id, access_token, refresh_token, expires_at)
    VALUES (${userId}, ${tokens.athlete.id}, ${tokens.access_token}, ${tokens.refresh_token}, to_timestamp(${tokens.expires_at}))
    ON CONFLICT (user_id) DO UPDATE SET
      strava_athlete_id = EXCLUDED.strava_athlete_id,
      access_token = EXCLUDED.access_token,
      refresh_token = EXCLUDED.refresh_token,
      expires_at = EXCLUDED.expires_at
  `;
  res.status(200).json({ ok: true });
}

async function handleDisconnect(req, res, userId) {
  await sql`DELETE FROM strava_connections WHERE user_id = ${userId}`;
  res.status(200).json({ ok: true });
}

async function handleStatus(req, res, userId) {
  const { rows } = await sql`SELECT connected_at FROM strava_connections WHERE user_id = ${userId}`;
  res.status(200).json({ connected: rows.length > 0, connectedAt: rows[0]?.connected_at || null });
}

// Pulls recent running history from Strava and hands it back normalized — the app inserts each
// as a local RunRecord (see `StravaService.importActivities`), deduped by `stravaActivityId`
// against runs already imported, so calling this again (to pick up new Strava activity) is
// always safe.
async function handleImportActivities(req, res, userId) {
  let accessToken;
  try {
    accessToken = await validAccessToken(sql, userId);
  } catch {
    return res.status(502).json({ error: 'strava_unreachable' });
  }
  if (!accessToken) return res.status(409).json({ error: 'not_connected' });

  let runs;
  try {
    runs = await fetchRecentRuns(accessToken);
  } catch {
    return res.status(502).json({ error: 'strava_unreachable' });
  }

  res.status(200).json({
    items: runs.map((a) => ({
      stravaActivityId: a.id,
      title: a.name,
      distanceKm: a.distance / 1000,
      durationSeconds: a.moving_time,
      date: a.start_date,
      elevationGainM: Math.round(a.total_elevation_gain || 0),
      avgHeartRate: Math.round(a.average_heartrate || 0),
    })),
  });
}
