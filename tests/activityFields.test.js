// Les champs qu'une autrice possède sur sa sortie : le titre, la note, le tracé.
//
// Deux d'entre eux sont du texte libre qui atterrit dans le fil de tout un club — la seule
// catégorie de contenu que la règle 1.2 de l'App Store oblige à filtrer. Le troisième est une
// position GPS, c'est-à-dire la donnée la plus sensible que cette app manipule. Les trois entrent
// par ici.
const test = require('node:test');
const assert = require('node:assert');
const {
  MAX_TITLE, MAX_NOTE, MAX_FEED_ROUTE_POINTS, MAX_SPLITS, REJECTED,
  sanitizeOwnText, sanitizeRoutePreview,
  sanitizeAltitudes, sanitizeSplits, sanitizeEntierBorne,
} = require('../lib/activityFields');

test('un titre ordinaire passe tel quel', () => {
  assert.equal(sanitizeOwnText('Mon premier 10 km', MAX_TITLE), 'Mon premier 10 km');
});

test('les blancs de bordure disparaissent, et un champ vide vaut « pas de titre »', () => {
  assert.equal(sanitizeOwnText('  Sortie longue  ', MAX_TITLE), 'Sortie longue');
  assert.equal(sanitizeOwnText('   ', MAX_TITLE), null);
  assert.equal(sanitizeOwnText('', MAX_TITLE), null);
});

test('ce qui n’est pas une chaîne ne devient pas un titre', () => {
  for (const bad of [null, undefined, 42, {}, ['a'], true]) {
    assert.equal(sanitizeOwnText(bad, MAX_TITLE), null);
  }
});

test('un titre trop long est coupé, pas refusé', () => {
  const long = 'a'.repeat(MAX_TITLE + 50);
  assert.equal(sanitizeOwnText(long, MAX_TITLE).length, MAX_TITLE);
});

// Le point de tout ce fichier : sans le marqueur, un titre injurieux rendrait `null`, serait
// enregistré comme « pas de titre », et la modération aurait échoué sans que personne le sache.
test('un texte injurieux est REFUSÉ, et ne se confond pas avec un texte absent', () => {
  assert.equal(sanitizeOwnText('salope', MAX_TITLE), REJECTED);
  assert.notEqual(sanitizeOwnText('salope', MAX_TITLE), null);
  assert.equal(sanitizeOwnText('f u c k', MAX_NOTE), REJECTED, 'les contournements aussi');
});

test('la note suit les mêmes règles, avec sa propre longueur', () => {
  assert.equal(sanitizeOwnText('a'.repeat(MAX_NOTE + 10), MAX_NOTE).length, MAX_NOTE);
  assert.ok(MAX_NOTE > MAX_TITLE, 'une note est un paragraphe, un titre une ligne');
});

// ── Le tracé ────────────────────────────────────────────────────────────────

test('un tracé plausible passe', () => {
  const points = [[45.76, 4.83], [45.77, 4.84], [45.78, 4.85]];
  assert.deepEqual(sanitizeRoutePreview(points), points);
});

test('tout ce qui n’est pas une liste de coordonnées est écarté', () => {
  for (const bad of [null, undefined, 'ici', {}, [], [[45.76, 4.83]],
                     [[45.76, 4.83], [91, 4.84]],          // latitude impossible
                     [[45.76, 4.83], [45.77, 181]],        // longitude impossible
                     [[45.76, 4.83], [NaN, 4.84]],
                     [[45.76, 4.83], [45.77]],             // paire incomplète
                     [[45.76, 4.83], '45.77,4.84']]) {
    assert.equal(sanitizeRoutePreview(bad), null, `${JSON.stringify(bad)} ne doit pas passer`);
  }
});

test('un tracé refusé rend null, jamais une erreur', () => {
  // Un tracé malformé est un défaut d'affichage ; perdre la course qui le portait serait pire.
  assert.doesNotThrow(() => sanitizeRoutePreview([[999, 999]]));
});

test('un tracé trop long est borné', () => {
  const many = Array.from({ length: MAX_FEED_ROUTE_POINTS + 200 }, (_, i) => [45 + i / 10000, 4.8]);
  assert.equal(sanitizeRoutePreview(many).length, MAX_FEED_ROUTE_POINTS);
});

// --- Le tracé : borné AVANT d'être parcouru, et échantillonné plutôt que tronqué ---

test('un tracé démesuré est refusé sans être parcouru', () => {
  const { MAX_FEED_ROUTE_INPUT } = require('../lib/activityFields');
  const enorme = Array.from({ length: MAX_FEED_ROUTE_INPUT + 1 }, () => [48.85, 2.35]);
  assert.equal(sanitizeRoutePreview(enorme), null);
});

test('un tracé plus long que la borne garde sa FORME, pas son début', () => {
  // Cent mille mètres en ligne droite, de 0 à 1 de longitude. Une troncature par la tête rendrait
  // un trait qui s'arrête au centième de la course ; l'échantillonnage garde les deux bouts.
  const long = Array.from({ length: 1000 }, (_, i) => [48.85, i / 1000]);
  const out = sanitizeRoutePreview(long);
  assert.equal(out.length, MAX_FEED_ROUTE_POINTS);
  assert.deepEqual(out[0], long[0], 'le départ est gardé');
  assert.deepEqual(out[out.length - 1], long[long.length - 1], 'et l’arrivée aussi');
  // Un point du milieu doit venir du milieu, pas du début.
  assert.ok(out[Math.floor(out.length / 2)][1] > 0.4, 'le milieu du tracé est au milieu');
});

test('un tracé court est rendu tel quel', () => {
  const court = [[48.85, 2.35], [48.86, 2.36], [48.87, 2.37]];
  assert.deepEqual(sanitizeRoutePreview(court), court);
});

// LES ALTITUDES SUIVENT LE TRACÉ, OU NE PARTENT PAS.
//
// Un profil de dénivelé décalé d'un cran ne plante rien : il désigne simplement les mauvais
// kilomètres, et personne ne s'en aperçoit. C'est pour ça que ces tests existent.

test('les altitudes sont échantillonnées SUR LES MÊMES points que le tracé', () => {
  // Chaque altitude vaut l'indice de son point : si les deux échantillonnages coïncident,
  // l'altitude gardée en position k vaut l'indice d'origine du point gardé en position k.
  const n = 1000;
  const trace = Array.from({ length: n }, (_, i) => [48.85, i / n]);
  const altitudes = Array.from({ length: n }, (_, i) => i);
  const points = sanitizeRoutePreview(trace);
  const sortie = sanitizeAltitudes(altitudes, n);
  assert.equal(points.length, MAX_FEED_ROUTE_POINTS);
  assert.equal(sortie.length, MAX_FEED_ROUTE_POINTS);
  points.forEach((point, k) => {
    assert.equal(Math.round(point[1] * n), sortie[k], `point ${k} et son altitude`);
  });
});

test('une liste d’altitudes d’une autre longueur que le tracé est refusée en entier', () => {
  assert.equal(sanitizeAltitudes([10, 20, 30], 4), null);
  assert.equal(sanitizeAltitudes([10, 20, 30], 2), null);
  assert.deepEqual(sanitizeAltitudes([10, 20, 30], 3), [10, 20, 30]);
});

test('un trou d’altitude est gardé, un trou PARTOUT ne vaut pas un profil', () => {
  assert.deepEqual(sanitizeAltitudes([12, null, 14], 3), [12, null, 14],
                   'une mesure manquante au milieu reste un profil');
  assert.equal(sanitizeAltitudes([null, null, null], 3), null,
               'aucune mesure du tout n’est un profil vide, pas un profil troué');
});

test('une altitude hors du monde fait tomber le profil, pas la sortie', () => {
  assert.equal(sanitizeAltitudes([10, 99999, 12], 3), null);
  assert.equal(sanitizeAltitudes([10, -4000, 12], 3), null);
  assert.equal(sanitizeAltitudes([10, Infinity, 12], 3), null);
});

test('les splits ne passent qu’en « m:ss »', () => {
  assert.deepEqual(sanitizeSplits(['5:12', '4:58', '12:03']), ['5:12', '4:58', '12:03']);
  assert.equal(sanitizeSplits(['5:72']), null, 'soixante-douze secondes n’existent pas');
  assert.equal(sanitizeSplits(['512']), null);
  assert.equal(sanitizeSplits(['<b>5:12</b>']), null, 'rien d’autre que des chiffres n’entre');
  assert.equal(sanitizeSplits([]), null);
  assert.equal(sanitizeSplits(Array.from({ length: MAX_SPLITS + 1 }, () => '5:00')), null);
});

test('zéro n’est jamais une fréquence cardiaque', () => {
  assert.equal(sanitizeEntierBorne(152, 30, 250), 152);
  assert.equal(sanitizeEntierBorne(0, 30, 250), null, 'pas de cardio ≠ 0 bpm');
  assert.equal(sanitizeEntierBorne(400, 30, 250), null);
  assert.equal(sanitizeEntierBorne('152', 30, 250), null, 'une chaîne n’est pas une mesure');
  assert.equal(sanitizeEntierBorne(151.6, 30, 250), 152, 'arrondi, pas tronqué');
});
