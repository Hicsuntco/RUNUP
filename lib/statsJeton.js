// Le jeton de service qui ouvre /api/stats, isolé ici pour une seule raison : c'est une PORTE, et
// une porte se teste. Laissée dans la route, elle n'aurait jamais eu de test — la route a besoin
// d'un Postgres, les tests de ce dépôt n'en ont pas, et une porte qu'on ne peut pas éprouver
// finit par s'ouvrir toute seule un jour de refactor.
//
// Trois règles, et la première est la plus importante :
//
//   1. PAS DE VARIABLE, PAS DE PORTE. Si RUNUP_STATS_TOKEN n'est pas définie, aucune valeur
//      présentée ne passe — pas même la chaîne vide, pas même `undefined`. Même raison que la
//      liste des admins dans lib/admin.js : un droit qui s'accorde tout seul quand une
//      configuration manque est la plus mauvaise des portes.
//   2. Comparaison à temps constant : `===` laisse fuir la longueur du préfixe commun par le
//      temps de réponse. C'est peu, et c'est gratuit à éviter.
//   3. `Bearer ` exigé, sans tolérance : accepter le jeton nu « au cas où » double la surface
//      pour zéro bénéfice.

function memeJeton(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length === 0 || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// `entete` : la valeur brute de l'en-tête Authorization. `attendu` : process.env.RUNUP_STATS_TOKEN.
function jetonValide(entete, attendu) {
  if (typeof attendu !== 'string' || attendu.length === 0) return false;
  if (typeof entete !== 'string' || !entete.startsWith('Bearer ')) return false;
  return memeJeton(entete.slice(7), attendu);
}

module.exports = { memeJeton, jetonValide };
