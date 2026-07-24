// Wraps a route handler so an unexpected error (DB hiccup, upstream JWKS fetch failure, etc.)
// returns a clean 500 instead of Vercel's default crash page, and never leaks a stack trace.
function withErrorHandling(handler) {
  return async (req, res) => {
    try {
      await handler(req, res);
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).json({ error: 'internal_error' });
    }
  };
}

// A non-UUID string in an id field reaches Postgres as a cast error and surfaces as a generic
// 500 — validating up front turns malformed input into the 400 it actually is.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function isUuid(value) {
  return typeof value === 'string' && UUID_RE.test(value);
}

module.exports = { withErrorHandling, isUuid };
