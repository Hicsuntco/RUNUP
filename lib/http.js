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

module.exports = { withErrorHandling };
