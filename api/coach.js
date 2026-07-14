// Vercel serverless function — the only place RunUp's real Anthropic API key lives. The app
// calls this endpoint instead of api.anthropic.com directly, so no end user ever needs their own
// key. See IOS_SETUP.md § "Coach backend" for the deploy/config steps.
//
// Two env vars, set in the Vercel project (never committed): ANTHROPIC_API_KEY, RUNUP_APP_SECRET.

const ALLOWED_MODEL = 'claude-opus-4-8';
const MAX_TOKENS_CAP = 500;

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const secret = req.headers['x-runup-secret'];
  if (!secret || secret !== process.env.RUNUP_APP_SECRET) {
    res.status(401).json({ error: 'unauthorized' });
    return;
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    res.status(500).json({ error: 'server_misconfigured' });
    return;
  }

  const { system, messages } = req.body || {};
  if (!system || !Array.isArray(messages)) {
    res.status(400).json({ error: 'bad_request' });
    return;
  }

  // Ignore whatever model/max_tokens the client sent — always force our own values, so a
  // tampered client can't route arbitrary paid requests through this key.
  const body = {
    model: ALLOWED_MODEL,
    max_tokens: MAX_TOKENS_CAP,
    system,
    messages,
  };

  try {
    const upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    // Passed straight through, unlogged — this function never writes chat content to disk or
    // console, only relays it in real time (see PRIVACY_POLICY.md).
    const text = await upstream.text();
    res.status(upstream.status).setHeader('content-type', 'application/json').send(text);
  } catch {
    res.status(502).json({ error: 'upstream_unreachable' });
  }
}
