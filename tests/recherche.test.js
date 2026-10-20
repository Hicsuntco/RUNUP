// Le repli des noms pour la recherche de « Mes amis ».
//
// LE DÉFAUT QUE CES TESTS EMPÊCHENT DE REVENIR. La recherche comparait le texte tapé aux colonnes
// telles quelles : « leo » ne trouvait pas « Léo », « perret charlotte » ne trouvait pas
// « Charlotte Perret », et « jean pierre » ne trouvait pas « Jean-Pierre ». Dans une app
// française, le premier cas à lui seul couvre la moitié des prénoms.
//
// LA MOITIÉ QUI SE TESTE ICI. Le repli a deux implémentations : celle-ci, en JavaScript, pour le
// texte tapé — et `translate()` en SQL pour les colonnes. Une table unique les alimente toutes
// les deux (`lib/recherche.js`). Ces tests tiennent la table, et surtout l'invariant qui fait que
// les deux ne peuvent pas diverger : les deux colonnes de `translate` ont la même longueur, et le
// repli JavaScript rend lettre à lettre ce que le SQL rendra.
const test = require('node:test');
const assert = require('node:assert');

const {
  ACCENTS, ACCENTS_SOURCE, ACCENTS_CIBLE, normaliser, echapperPourLike,
} = require('../lib/recherche');

// --- L'invariant entre les deux implémentations --------------------------------------------------

test('les deux colonnes de translate() ont la même longueur', () => {
  // Si la source est plus longue que la cible, `translate` ne remplace pas la lettre en trop :
  // il la SUPPRIME du texte. « Zoé » deviendrait « zo », et ne se trouverait plus du tout.
  assert.strictEqual(Array.from(ACCENTS_SOURCE).length, Array.from(ACCENTS_CIBLE).length);
});

test('le repli JavaScript rend exactement ce que translate() rendra', () => {
  const source = Array.from(ACCENTS_SOURCE);
  const cible = Array.from(ACCENTS_CIBLE);
  for (let i = 0; i < source.length; i += 1) {
    assert.strictEqual(normaliser(source[i]), cible[i], `la lettre ${source[i]}`);
    // Et la même en capitale : les deux côtés passent par un `lower()` avant la table.
    assert.strictEqual(normaliser(source[i].toUpperCase()), cible[i], `la capitale de ${source[i]}`);
  }
});

test('chaque entrée de la table vaut un seul caractère des deux côtés', () => {
  for (const [accentuee, nue] of Object.entries(ACCENTS)) {
    assert.strictEqual(Array.from(accentuee).length, 1, accentuee);
    assert.strictEqual(Array.from(nue).length, 1, nue);
  }
});

// --- Les trois cas qui ne marchaient pas ----------------------------------------------------------

test('« leo » trouve « Léo »', () => {
  assert.strictEqual(normaliser('Léo'), 'leo');
  assert.ok(normaliser('Léo Durand').includes(normaliser('leo')));
});

test('« jean pierre » et « Jean-Pierre » se replient pareil', () => {
  assert.strictEqual(normaliser('Jean-Pierre'), normaliser('jean pierre'));
});

test("l'apostrophe et le point ne séparent pas deux personnes", () => {
  assert.strictEqual(normaliser("O'Connor"), 'o connor');
  assert.strictEqual(normaliser('O’Connor'), 'o connor', "l'apostrophe typographique compte aussi");
  assert.strictEqual(normaliser('J.P. Durand'), 'j p durand');
});

test('les ligatures valent leurs deux lettres', () => {
  assert.strictEqual(normaliser('Lecœur'), 'lecoeur');
  assert.strictEqual(normaliser('Lætitia'), 'laetitia');
});

test('les espaces en trop ne changent rien', () => {
  assert.strictEqual(normaliser('  Charlotte   Perret  '), 'charlotte perret');
});

test('un texte sans accent traverse intact', () => {
  assert.strictEqual(normaliser('charlotte perret'), 'charlotte perret');
});

test('ce qui n\'est pas une chaîne rend une chaîne vide', () => {
  assert.strictEqual(normaliser(undefined), '');
  assert.strictEqual(normaliser(null), '');
  assert.strictEqual(normaliser(42), '');
});

// --- Les jokers de LIKE ---------------------------------------------------------------------------

test('le souligné est échappé — c\'est une lettre de pseudo, pas un joker', () => {
  // Sans ça, chercher « jean_ » listerait tous les « jean » suivis de n'importe quoi.
  assert.strictEqual(echapperPourLike('jean_p'), 'jean\\_p');
});

test('le pourcent est échappé', () => {
  assert.strictEqual(echapperPourLike('100%'), '100\\%');
});

test('la barre oblique inverse est échappée la première', () => {
  // Sinon elle échapperait l'échappement de la lettre suivante.
  assert.strictEqual(echapperPourLike('a\\_b'), 'a\\\\\\_b');
});

test('un texte ordinaire traverse intact', () => {
  assert.strictEqual(echapperPourLike('charlotte perret'), 'charlotte perret');
});
