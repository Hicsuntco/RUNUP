// Real Strava OAuth — the app never sees STRAVA_CLIENT_SECRET, only this server does. Needs two
// env vars set in Vercel (Project Settings → Environment Variables), from a Strava API
// application created at https://www.strava.com/settings/api:
//   STRAVA_CLIENT_ID     — public; also embedded in the iOS app (see StravaService.swift)
//   STRAVA_CLIENT_SECRET — private, server-side only, never committed
const TOKEN_URL = 'https://www.strava.com/oauth/token';
const ACTIVITIES_URL = 'https://www.strava.com/api/v3/athlete/activities';

function credentials() {
  const clientId = process.env.STRAVA_CLIENT_ID;
  const clientSecret = process.env.STRAVA_CLIENT_SECRET;
  if (!clientId || !clientSecret) throw new Error('strava_not_configured');
  return { clientId, clientSecret };
}

// One-time exchange of the authorization code (from the in-app OAuth flow, see
// `ASWebAuthenticationSession` in StravaService.swift) for a real access + refresh token pair.
async function exchangeCodeForTokens(code) {
  const { clientId, clientSecret } = credentials();
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, code, grant_type: 'authorization_code' }),
  });
  if (!res.ok) throw new Error('strava_token_exchange_failed');
  return res.json(); // { access_token, refresh_token, expires_at, athlete: { id } }
}

async function refreshTokens(refreshToken) {
  const { clientId, clientSecret } = credentials();
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, refresh_token: refreshToken, grant_type: 'refresh_token' }),
  });
  // 400/401 from the token endpoint means the user revoked RunUp's access on Strava's side (or
  // the token is otherwise dead) — permanently, not a transient outage. Marked so the caller can
  // drop the connection instead of reporting "Strava unreachable" forever.
  if (res.status === 400 || res.status === 401) {
    const err = new Error('strava_token_revoked');
    err.revoked = true;
    throw err;
  }
  if (!res.ok) throw new Error('strava_token_refresh_failed');
  return res.json(); // { access_token, refresh_token, expires_at }
}

// Returns a real, currently-valid access token for this user — refreshing against Strava first
// if the stored one has expired (or is about to, within a minute), and persisting the refreshed
// pair back to `strava_connections` so the next call doesn't need to refresh again. Returns null
// if this user never connected Strava at all — never a fabricated/expired token.
async function validAccessToken(sql, userId) {
  const { rows } = await sql`SELECT access_token, refresh_token, expires_at FROM strava_connections WHERE user_id = ${userId}`;
  const connection = rows[0];
  if (!connection) return null;

  const expiresAt = new Date(connection.expires_at).getTime();
  if (expiresAt > Date.now() + 60_000) return connection.access_token;

  let refreshed;
  try {
    refreshed = await refreshTokens(connection.refresh_token);
  } catch (e) {
    if (e.revoked) {
      // Revoked on Strava's side: drop the dead connection so the client gets `not_connected`
      // (409) and can offer to reconnect, instead of an eternal "Strava unreachable" 502.
      await sql`DELETE FROM strava_connections WHERE user_id = ${userId}`;
      return null;
    }
    throw e;
  }
  await sql`
    UPDATE strava_connections
    SET access_token = ${refreshed.access_token}, refresh_token = ${refreshed.refresh_token},
        expires_at = to_timestamp(${refreshed.expires_at})
    WHERE user_id = ${userId}
  `;
  return refreshed.access_token;
}

// Recent activities from Strava's own history, filtered to running only — Strava's activities
// feed includes every sport a member logs, not just runs.
async function fetchRecentRuns(accessToken) {
  const res = await fetch(`${ACTIVITIES_URL}?per_page=50`, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new Error('strava_activities_failed');
  const activities = await res.json();
  return activities.filter((a) => a.type === 'Run' || a.sport_type === 'Run');
}

module.exports = { exchangeCodeForTokens, refreshTokens, validAccessToken, fetchRecentRuns };
