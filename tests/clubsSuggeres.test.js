// Les lignes proposées quand on ouvre « Rejoindre un club » sans rien taper.
//
// CE QUE CES CAS EMPÊCHENT DE REVENIR. La recherche de clubs exige deux caractères du nom, donc
// elle suppose qu'on sache déjà qu'un club existe — exactement le reproche qui avait fait retirer
// le code d'invitation à six lettres. Le champ vide ne montrait rien.
//
// La partie qui se teste ici est la seule qui se calcule sans base de données : la mise en forme
// d'une ligne, et la seule chose qui dépend de l'heure — « actif récemment ». C'est aussi la
// seule qui puisse être FAUSSE SANS BRUIT : une date illisible, une horloge de serveur en avance,
// et la mention apparaît ou disparaît sans que rien ne casse.
const test = require('node:test');
const assert = require('node:assert');

const { FRAICHEUR_JOURS, MAX_SUGGESTIONS, ligneSuggeree } = require('../lib/clubsSuggeres');

const JOUR = 24 * 60 * 60 * 1000;
const MAINTENANT = Date.parse('2026-11-09T08:00:00Z');

function ligneBrute(extra = {}) {
  return {
    id: 'c1', name: 'Les Foulées du Canal', city: 'Lyon', member_count: 12,
    seance_prevue: false, dernier_message: null, ...extra,
  };
}

test('la ligne a exactement la forme d\'un résultat de recherche, plus les deux raisons', () => {
  // L'app réutilise la même vue pour les deux listes : un champ qui manque ici fait une ligne
  // qui se dessine à moitié, sans erreur.
  const ligne = ligneSuggeree(ligneBrute(), MAINTENANT);
  assert.deepStrictEqual(Object.keys(ligne).sort(),
    ['actifRecemment', 'city', 'id', 'memberCount', 'name', 'seancePrevue']);
  assert.strictEqual(ligne.name, 'Les Foulées du Canal');
  assert.strictEqual(ligne.city, 'Lyon');
  assert.strictEqual(ligne.memberCount, 12);
});

test('une ville absente devient null, jamais une chaîne vide', () => {
  // « Les Foulées ·  » avec un séparateur suivi de rien est pire qu'un nom seul.
  assert.strictEqual(ligneSuggeree(ligneBrute({ city: '' }), MAINTENANT).city, null);
  assert.strictEqual(ligneSuggeree(ligneBrute({ city: null }), MAINTENANT).city, null);
});

test('un message d\'hier rend le club actif', () => {
  const ligne = ligneSuggeree(
    ligneBrute({ dernier_message: new Date(MAINTENANT - JOUR).toISOString() }), MAINTENANT);
  assert.strictEqual(ligne.actifRecemment, true);
});

test('la bordure des quatorze jours tombe du bon côté', () => {
  const pile = ligneSuggeree(
    ligneBrute({ dernier_message: new Date(MAINTENANT - FRAICHEUR_JOURS * JOUR).toISOString() }),
    MAINTENANT);
  assert.strictEqual(pile.actifRecemment, true, 'quatorze jours pile doit compter comme actif');

  const unePoussiereApres = ligneSuggeree(
    ligneBrute({ dernier_message: new Date(MAINTENANT - FRAICHEUR_JOURS * JOUR - 1000).toISOString() }),
    MAINTENANT);
  assert.strictEqual(unePoussiereApres.actifRecemment, false);
});

test('un club qui n\'a jamais rien écrit n\'est pas actif', () => {
  assert.strictEqual(ligneSuggeree(ligneBrute(), MAINTENANT).actifRecemment, false);
});

test('UNE DATE ILLISIBLE NE REND PAS « ACTIF » PAR ACCIDENT', () => {
  // `new Date('n\'importe quoi')` rend NaN, et NaN comparé à quoi que ce soit rend false. Le
  // piège est l'inverse : une comparaison écrite dans l'autre sens aurait rendu `true`.
  const ligne = ligneSuggeree(ligneBrute({ dernier_message: 'pas une date' }), MAINTENANT);
  assert.strictEqual(ligne.actifRecemment, false);
});

test('UN MESSAGE DATÉ DANS LE FUTUR NE REND PAS « ACTIF » NON PLUS', () => {
  // Une horloge en avance, une insertion mal datée : « il y a -3 jours » est inférieur à quatorze
  // jours, donc la seule comparaison de fraîcheur l'aurait accepté.
  const ligne = ligneSuggeree(
    ligneBrute({ dernier_message: new Date(MAINTENANT + 3 * JOUR).toISOString() }), MAINTENANT);
  assert.strictEqual(ligne.actifRecemment, false);
});

test('une séance à venir se lit telle quelle, et n\'est jamais indéfinie', () => {
  assert.strictEqual(ligneSuggeree(ligneBrute({ seance_prevue: true }), MAINTENANT).seancePrevue, true);
  assert.strictEqual(ligneSuggeree(ligneBrute({ seance_prevue: null }), MAINTENANT).seancePrevue, false);
});

test('cinq suggestions, pas une liste à faire défiler', () => {
  // Une liste qu'on fait défiler demande de choisir ; cinq lignes demandent d'en essayer une.
  assert.strictEqual(MAX_SUGGESTIONS, 5);
});
