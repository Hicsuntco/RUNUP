// Le filtre de contenu, exigé par la règle 1.2 de l'App Store.
//
// Il garde les deux champs libres qu'une personne écrit et que d'autres voient : son nom affiché
// et le nom d'un club. C'est une liste noire assumée — pas un classifieur — et sa valeur tient
// entièrement dans sa NORMALISATION : sans elle, « s@lope » et « f u c k » passent devant elle
// sans la voir. Ce sont donc les contournements qui méritent des tests, pas les mots eux-mêmes.
const test = require('node:test');
const assert = require('node:assert');
const { containsObjectionableContent } = require('../lib/moderation');

test('laisse passer ce qui est innocent', () => {
  for (const ok of ['Charlotte', 'Les Foulées du Dimanche', 'Team 10K', 'Sarah-Jane', '', null]) {
    assert.equal(containsObjectionableContent(ok), false, `« ${ok} » ne devrait pas être bloqué`);
  }
});

test('attrape un terme évident', () => {
  assert.equal(containsObjectionableContent('salope'), true);
  assert.equal(containsObjectionableContent('Club des connards'), true);
});

test('les accents ne servent pas d’échappatoire', () => {
  assert.equal(containsObjectionableContent('enculé'), true);
  assert.equal(containsObjectionableContent('encule'), true);
  assert.equal(containsObjectionableContent('bâtard'), true);
});

test('les espaces et la ponctuation ne servent pas d’échappatoire', () => {
  assert.equal(containsObjectionableContent('f u c k'), true);
  assert.equal(containsObjectionableContent('s.a.l.o.p.e'), true);
});

// Le commentaire du module note que « @ » renvoyait autrefois vers « o », ce qui laissait passer
// la substitution la plus courante. Ce test verrouille la correction.
test('le leetspeak ne sert pas d’échappatoire', () => {
  assert.equal(containsObjectionableContent('s@lope'), true);
  assert.equal(containsObjectionableContent('b4tard'), true);
  assert.equal(containsObjectionableContent('sh1t'), true);
  assert.equal(containsObjectionableContent('$hit'), true);
});

test('la casse est indifférente', () => {
  assert.equal(containsObjectionableContent('SALOPE'), true);
  assert.equal(containsObjectionableContent('SaLoPe'), true);
});
