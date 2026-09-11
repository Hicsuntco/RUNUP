// Le plafond quotidien partagé, qui garde dix points d'entrée.
//
// Sa borne est du genre à se décaler d'un cran sans qu'on s'en aperçoive : `<=` au lieu de `<`
// laisse passer une requête de plus, `<` au lieu de `<=` en refuse une de trop, et dans les deux
// cas personne ne le remarque avant qu'un abus ou une plainte n'arrive. Trois lignes de code,
// aucun test jusqu'ici.
//
// Le choix qui mérite d'être épinglé : en cas d'erreur du compteur, la fonction LAISSE PASSER.
// C'est délibéré et documenté — un plafond ne doit jamais faire tomber la fonctionnalité qu'il
// protège — mais c'est exactement le genre de décision qu'une réécriture inverse « pour être
// prudent », en coupant l'app entière au premier hoquet de la base.
const test = require('node:test');
const assert = require('node:assert');

let reponse = { rows: [{ count: 1 }] };
let leve = null;
const dbPath = require.resolve('../lib/db');
require.cache[dbPath] = {
  id: dbPath, filename: dbPath, loaded: true,
  exports: {
    sql: async () => {
      if (leve) throw leve;
      return reponse;
    },
  },
};

const { underDailyCap } = require('../lib/rateLimit');

test('sous la limite, ça passe', async () => {
  leve = null; reponse = { rows: [{ count: 3 }] };
  assert.equal(await underDailyCap('u:1', 10), true);
});

test('la limite EXACTE passe encore — c’est la dernière requête autorisée', async () => {
  leve = null; reponse = { rows: [{ count: 10 }] };
  assert.equal(await underDailyCap('u:1', 10), true);
});

test('un cran au-dessus est refusé', async () => {
  leve = null; reponse = { rows: [{ count: 11 }] };
  assert.equal(await underDailyCap('u:1', 10), false);
});

test('un compteur en panne laisse passer, et c’est voulu', async () => {
  leve = new Error('base injoignable');
  assert.equal(await underDailyCap('u:1', 10), true,
    'un plafond ne doit jamais emporter la fonctionnalité qu’il protège');
});

test('une réponse vide laisse passer aussi', async () => {
  leve = null; reponse = { rows: [] };
  assert.equal(await underDailyCap('u:1', 10), true);
});
