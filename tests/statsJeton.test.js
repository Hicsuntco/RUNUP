// La porte de /api/stats.
//
// Elle garde des agrégats, pas des lignes — mais une porte de service qui s'ouvre toute seule est
// une porte de service qui s'ouvre à tout le monde, et celle-ci est atteignable depuis Internet
// sans compte ni session. Le cas qui compte n'est pas « le bon jeton passe » : c'est « rien ne
// passe quand la variable d'environnement n'est pas posée ». C'est l'état par défaut d'un
// déploiement neuf, d'un aperçu Vercel, et de n'importe quelle branche.
const test = require('node:test');
const assert = require('node:assert');

const { jetonValide, memeJeton } = require('../lib/statsJeton');

test('pas de variable, pas de porte', () => {
  // L'état par défaut : RUNUP_STATS_TOKEN jamais posée.
  assert.equal(jetonValide('Bearer nimporte-quoi', undefined), false);
  assert.equal(jetonValide('Bearer nimporte-quoi', ''), false);
  assert.equal(jetonValide('Bearer nimporte-quoi', null), false);
  // Et le cas vicieux : présenter la chaîne vide quand la variable est vide.
  assert.equal(jetonValide('Bearer ', ''), false);
});

test('un jeton juste passe', () => {
  assert.equal(jetonValide('Bearer secret-de-service', 'secret-de-service'), true);
});

test('un jeton faux ne passe pas', () => {
  assert.equal(jetonValide('Bearer secret-de-servicX', 'secret-de-service'), false);
  // Un préfixe correct mais trop court : c'est l'attaque la plus naïve, et celle que la
  // comparaison à temps constant doit refuser sans donner d'indice.
  assert.equal(jetonValide('Bearer secret', 'secret-de-service'), false);
  // Plus long, même début.
  assert.equal(jetonValide('Bearer secret-de-service-et-plus', 'secret-de-service'), false);
});

test('le schéma Bearer est exigé', () => {
  assert.equal(jetonValide('secret-de-service', 'secret-de-service'), false);
  assert.equal(jetonValide('bearer secret-de-service', 'secret-de-service'), false);
  assert.equal(jetonValide('Basic secret-de-service', 'secret-de-service'), false);
  assert.equal(jetonValide('', 'secret-de-service'), false);
  assert.equal(jetonValide(undefined, 'secret-de-service'), false);
});

test('la comparaison ne se laisse pas avoir par les types', () => {
  assert.equal(memeJeton('a', 'a'), true);
  assert.equal(memeJeton('', ''), false);        // deux vides ne sont pas une autorisation
  assert.equal(memeJeton(null, null), false);
  assert.equal(memeJeton(undefined, undefined), false);
  assert.equal(memeJeton(123, 123), false);
  assert.equal(memeJeton('abc', 'abcd'), false);
});
