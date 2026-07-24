// Vercel serverless function — the only place RunUp's real Anthropic API key lives. The app
// calls this endpoint instead of api.anthropic.com directly, so no end user ever needs their own
// key. See IOS_SETUP.md § "Coach backend" for the deploy/config steps.
//
// Two env vars, set in the Vercel project (never committed): ANTHROPIC_API_KEY, RUNUP_APP_SECRET.

const { sql } = require('../lib/db');
const { requireAuth } = require('../lib/auth');
const { withErrorHandling } = require('../lib/http');

const ALLOWED_MODEL = 'claude-opus-4-8';
const MAX_TOKENS_CAP = 500;
// Generous for a human actually chatting with her coach (a heavy day is a few dozen messages),
// tight for anyone trying to use this endpoint as a free LLM proxy billed to the owner's key.
const DAILY_REQUEST_CAP = 250;
const MAX_MESSAGES = 40;
const MAX_TOTAL_CHARS = 30000;
const MAX_SYSTEM_CHARS = 20000;

module.exports = withErrorHandling(async function handler(req, res) {
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
  if (typeof system !== 'string' || !system || !Array.isArray(messages)) {
    res.status(400).json({ error: 'bad_request' });
    return;
  }
  // Size caps — the app never comes close to these in real use (CoachService sends the last few
  // turns of one conversation); only a script replaying huge payloads through the shared secret
  // would, and each oversized call would bill the owner's key.
  if (system.length > MAX_SYSTEM_CHARS || messages.length > MAX_MESSAGES) {
    res.status(400).json({ error: 'payload_too_large' });
    return;
  }
  let totalChars = 0;
  for (const m of messages) {
    if (!m || typeof m.content !== 'string' || (m.role !== 'user' && m.role !== 'assistant')) {
      res.status(400).json({ error: 'bad_request' });
      return;
    }
    totalChars += m.content.length;
  }
  if (totalChars > MAX_TOTAL_CHARS) {
    res.status(400).json({ error: 'payload_too_large' });
    return;
  }

  // Per-key daily rate limit: the signed-in user's id when there is one, the caller's IP
  // otherwise (the coach deliberately works without an account, so IP is the only handle for
  // anonymous use). Fails open on a DB hiccup — a broken rate limiter should degrade to "coach
  // still works", not "coach is down".
  try {
    const userId = await requireAuth(req).catch(() => null);
    const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || 'unknown';
    const key = userId ? `u:${userId}` : `ip:${ip}`;
    const { rows } = await sql`
      INSERT INTO coach_usage (key, day, count) VALUES (${key}, CURRENT_DATE, 1)
      ON CONFLICT (key, day) DO UPDATE SET count = coach_usage.count + 1
      RETURNING count
    `;
    if (rows[0].count > DAILY_REQUEST_CAP) {
      res.status(429).json({ error: 'rate_limited' });
      return;
    }
  } catch (err) {
    console.error('coach rate limit unavailable:', err.message);
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
});
