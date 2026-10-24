// Le plafond de douze fonctions serverless.
//
// Vercel compte UNE fonction par fichier sous api/, et le plan de ce projet en autorise douze.
// Le treizième ne se déploie pas « un peu moins bien » : le BUILD ENTIER échoue, et l'app en
// production reste sur la version précédente — pour un fichier ajouté sans y penser.
//
// C'est exactement ce qui est arrivé le 24 octobre : un `api/stats.js` pour le tableau de bord
// de la maison, treizième du dossier, et un déploiement rouge dont le message ne dit rien
// d'autre que « run this Vercel CLI command ». Une demi-heure pour relier les deux.
//
// Ce test coûte trois millisecondes et transforme cette demi-heure en une ligne rouge qui NOMME
// la cause. Si le plan passe à un palier supérieur, on change le nombre ici — délibérément, et
// pas en découvrant un jour que la production ne se met plus à jour.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const API = path.join(__dirname, '..', 'api');
const PLAFOND = 12;

function fonctions(dossier) {
  return fs.readdirSync(dossier, { withFileTypes: true }).flatMap(e =>
    e.isDirectory() ? fonctions(path.join(dossier, e.name))
      : (e.name.endsWith('.js') ? [path.join(dossier, e.name)] : []));
}

test('pas plus de douze fonctions serverless', () => {
  const trouvees = fonctions(API).map(f => path.relative(API, f)).sort();
  assert.ok(trouvees.length <= PLAFOND,
    'Vercel refuserait le déploiement : ' + trouvees.length + ' fonctions pour un plafond de '
    + PLAFOND + '.\n  ' + trouvees.join('\n  ')
    + "\n\nUne route de plus se replie sur une route existante (GET/POST, ou un [action].js),"
    + "\ncomme la lecture des agrégats dans api/events.js.");
});
