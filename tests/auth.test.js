// Les tests de la porte d'entrée du serveur.
//
// `lib/auth.js` décide qui est authentifié sur onze des douze routes de l'API. Il n'avait aucun
// test. Une régression ici ne se voit pas : tout continue de fonctionner pour les gens de bonne
// foi, et c'est précisément ce qui la rend dangereuse — le seul symptôme d'un jeton accepté à
// tort est quelqu'un qui lit les données de quelqu'un d'autre.
//
// Aucune dépendance ajoutée : le lanceur de tests intégré à Node (18+) suffit, et `lib/db` est
// remplacé dans le cache de modules avant le premier `require`. C'est possible parce que
// `verifiedSessionClaims` fait son `require('./db')` À L'INTÉRIEUR de la fonction — sans quoi il
// aurait fallu une vraie base pour vérifier une signature.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');

process.env.RUNUP_SESSION_SECRET = 'secret-de-test-uniquement-pour-la-suite';
process.env.APPLE_BUNDLE_ID = 'com.hicsuntco.runup';

// --- Faux `sql`, piloté par le test en cours ---
let dbAnswer = [{ '?column?': 1 }]; // par défaut : l'utilisateur existe et n'est pas révoqué
let dbThrows = null;
const dbPath = require.resolve('../lib/db');
require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    sql: async () => {
      if (dbThrows) throw dbThrows;
      return { rows: dbAnswer };
    },
  },
};

const { signSession, requireAuth, verifiedSessionClaims } = require('../lib/auth');
const { SignJWT } = require('jose');

const bearer = (token) => ({ headers: { authorization: `Bearer ${token}` } });

test.beforeEach(() => {
  dbAnswer = [{ '?column?': 1 }];
  dbThrows = null;
});

test('un jeton valide authentifie', async () => {
  const token = await signSession('user-42');
  assert.equal(await requireAuth(bearer(token)), 'user-42');
});

test('aucun en-tête, aucune authentification', async () => {
  assert.equal(await requireAuth({ headers: {} }), null);
});

test('un en-tête sans le préfixe Bearer est refusé', async () => {
  const token = await signSession('user-42');
  assert.equal(await requireAuth({ headers: { authorization: token } }), null);
});

test('un jeton illisible est refusé', async () => {
  assert.equal(await requireAuth(bearer('pas.un.jeton')), null);
});

// Le test qui compte le plus de toute la suite : c'est la seule chose qui empêche n'importe qui
// de fabriquer un jeton au nom de n'importe qui.
test('un jeton signé avec une AUTRE clé est refusé', async () => {
  const forged = await new SignJWT({ sub: 'victime' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('180d')
    .sign(new TextEncoder().encode('la-clé-de-quelqu-un-d-autre'));
  assert.equal(await requireAuth(bearer(forged)), null);
});

test('un jeton expiré est refusé', async () => {
  const expired = await new SignJWT({ sub: 'user-42' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt(Math.floor(Date.now() / 1000) - 7200)
    .setExpirationTime(Math.floor(Date.now() / 1000) - 3600)
    .sign(new TextEncoder().encode(process.env.RUNUP_SESSION_SECRET));
  assert.equal(await requireAuth(bearer(expired)), null);
});

// Après une suppression de compte, l'ancien jeton reste cryptographiquement valide. Sans cette
// vérification en base, il « authentifie » encore, et chaque route meurt ensuite sur une
// violation de clé étrangère — un 500 brut au lieu d'un 401 propre qui déconnecte le client.
test('un compte supprimé n’authentifie plus, jeton valide ou non', async () => {
  const token = await signSession('user-supprimé');
  dbAnswer = [];
  assert.equal(await requireAuth(bearer(token)), null);
});

test('un jeton révoqué par une déconnexion est refusé', async () => {
  const token = await signSession('user-42');
  dbAnswer = []; // la requête joint users ET revoked_tokens : aucune ligne = révoqué
  assert.equal(await requireAuth(bearer(token)), null);
});

// La table de révocation peut ne pas encore exister sur un déploiement où la migration n'a pas
// tourné. Le repli doit vérifier l'utilisateur malgré tout — et surtout ne pas déconnecter toute
// l'app en attendant.
test('table de révocation absente : on retombe sur la vérification de l’utilisateur', async () => {
  const token = await signSession('user-42');
  let call = 0;
  require.cache[dbPath].exports.sql = async () => {
    call += 1;
    if (call === 1) {
      const err = new Error('relation "revoked_tokens" does not exist');
      err.code = '42P01';
      throw err;
    }
    return { rows: [{ '?column?': 1 }] };
  };
  assert.equal(await requireAuth(bearer(token)), 'user-42');
  require.cache[dbPath].exports.sql = async () => {
    if (dbThrows) throw dbThrows;
    return { rows: dbAnswer };
  };
});

// Une panne de base ne doit jamais se traduire par « authentifié ».
test('une base en panne refuse plutôt que d’ouvrir', async () => {
  const token = await signSession('user-42');
  dbThrows = new Error('connection refused');
  assert.equal(await requireAuth(bearer(token)), null);
});

test('les claims portent bien l’identifiant demandé', async () => {
  const token = await signSession('abc-123');
  const claims = await verifiedSessionClaims(bearer(token));
  assert.equal(claims.sub, 'abc-123');
  assert.ok(claims.exp > Math.floor(Date.now() / 1000), 'le jeton doit expirer dans le futur');
});
