// Fallback web page for a tapped referral link (`https://<domain>/r/CODE`, rewritten here by
// vercel.json) when RunUp isn't installed yet — the universal link itself
// (public/.well-known/apple-app-site-association) opens the app directly and skips this entirely
// when it is. `code` comes straight from the URL an attacker fully controls, not just from a
// legitimately-generated code, so it's whitelisted to the same alphanumeric shape
// `randomReferralCode()` actually generates before ever being interpolated into HTML.
module.exports = async function handler(req, res) {
  const code = String(req.query.code || '').replace(/[^A-Za-z0-9]/g, '').toUpperCase().slice(0, 20);
  const html = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RunUp</title>
<style>
  body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #0E0E14; color: #fff; font-family: -apple-system, BlinkMacSystemFont, sans-serif; text-align: center; padding: 24px; box-sizing: border-box; }
  .card { max-width: 360px; }
  h1 { font-size: 22px; margin: 0 0 8px; }
  p { font-size: 14px; color: rgba(255,255,255,0.6); line-height: 1.5; }
  .code { display: inline-block; margin: 16px 0; padding: 10px 18px; border-radius: 12px; background: rgba(255,255,255,0.08); font-family: monospace; font-size: 18px; letter-spacing: 2px; }
</style>
</head>
<body>
  <div class="card">
    <h1>Télécharge RunUp</h1>
    <p>Ton code de parrainage :</p>
    <div class="code">${code || '—'}</div>
    <p>Installe RunUp puis entre ce code à la création de ton compte pour débloquer la récompense de parrainage.</p>
  </div>
</body>
</html>`;
  res.setHeader('content-type', 'text/html; charset=utf-8');
  res.status(200).send(html);
};
