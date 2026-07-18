// Real push via Apple's HTTP/2 provider API — signed with an APNs Authentication Key (.p8), not
// a per-app certificate, so one key works for every RunUp build without renewal. Needs three env
// vars set in Vercel (Project Settings → Environment Variables):
//   APNS_KEY_ID    — the Key ID shown on the key's page in Apple Developer
//   APNS_TEAM_ID   — the account's Team ID (same as project.yml's DEVELOPMENT_TEAM: SW49TQ25NV)
//   APNS_PRIVATE_KEY — the full contents of the downloaded AuthKey_XXXX.p8 file, as-is (multi-line
//                      PEM, Vercel's env var editor accepts real newlines)
// Optional: APNS_ENV = 'production' (default 'development'/sandbox — matches project.yml's
// current aps-environment; flip this once builds start coming from TestFlight/App Store instead
// of an Xcode debug run, since a token's environment must match the server it's sent to).
const http2 = require('http2');
const { SignJWT, importPKCS8 } = require('jose');

const APNS_HOST = process.env.APNS_ENV === 'production' ? 'api.push.apple.com' : 'api.sandbox.push.apple.com';

let cachedProviderToken = null; // { token, issuedAt }

// Provider tokens are valid up to an hour — cached and reused across invocations within that
// window (harmless if a cold start discards the cache; it just signs a fresh one).
async function providerToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedProviderToken && now - cachedProviderToken.issuedAt < 55 * 60) {
    return cachedProviderToken.token;
  }
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const privateKeyPem = process.env.APNS_PRIVATE_KEY;
  if (!keyId || !teamId || !privateKeyPem) throw new Error('apns_not_configured');

  const key = await importPKCS8(privateKeyPem, 'ES256');
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuedAt(now)
    .setIssuer(teamId)
    .sign(key);

  cachedProviderToken = { token, issuedAt: now };
  return token;
}

// Sends one push to one device token. Never throws on a per-device failure — the caller is
// usually fanning this out to several devices/members at once, and one bad token shouldn't sink
// the rest. `shouldDelete` tells the caller the token is dead (unregistered, app deleted) and
// should stop being sent to.
async function sendPush(deviceToken, { title, body, sound = 'default' } = {}) {
  const bundleId = process.env.APNS_BUNDLE_ID || 'com.hicsuntco.runup';
  let token;
  try {
    token = await providerToken();
  } catch {
    return { ok: false, shouldDelete: false };
  }
  const payload = JSON.stringify({ aps: { alert: { title, body }, sound } });

  return new Promise((resolve) => {
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      resolve(result);
    };

    const client = http2.connect(`https://${APNS_HOST}`);
    client.on('error', () => finish({ ok: false, shouldDelete: false }));

    const req = client.request({
      ':method': 'POST',
      ':path': `/3/device/${deviceToken}`,
      authorization: `bearer ${token}`,
      'apns-topic': bundleId,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
    });
    req.setEncoding('utf8');
    let status = 0;
    req.on('response', (headers) => {
      status = headers[':status'];
    });
    req.on('data', () => {});
    req.on('end', () => {
      client.close();
      // 410 Gone (unregistered) or 400 BadDeviceToken both mean the token is dead.
      finish({ ok: status === 200, shouldDelete: status === 410 || status === 400 });
    });
    req.on('error', () => finish({ ok: false, shouldDelete: false }));
    req.end(payload);
  });
}

// Sends one push to every device a user has registered (there can be more than one row — several
// devices, or a stale token from a reinstall) and cleans up any the OS reports as dead along the
// way. Never throws — a push failure is never supposed to fail the API call that triggered it.
async function sendPushToUser(sql, userId, notification) {
  try {
    const { rows } = await sql`SELECT token FROM device_tokens WHERE user_id = ${userId}`;
    await Promise.all(
      rows.map(async (row) => {
        const result = await sendPush(row.token, notification);
        if (result.shouldDelete) {
          await sql`DELETE FROM device_tokens WHERE token = ${row.token}`;
        }
      })
    );
  } catch {
    // Never let a push failure surface as an error to whatever real action triggered it.
  }
}

module.exports = { sendPush, sendPushToUser };
