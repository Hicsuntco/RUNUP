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

const {
  signSession, requireAuth, verifiedSessionClaims,
  shouldRenewSession, sessionStartOf, RENEWAL_HEADER,
  SESSION_LIFETIME_DAYS, ABSOLUTE_SESSION_DAYS,
} = require('../lib/auth');
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

// ─── Le renouvellement glissant ───────────────────────────────────────────────────────────────
//
// Il décide tout seul, sur chaque requête authentifiée, s'il faut renvoyer un jeton neuf. Deux
// façons de se tromper, et les deux sont silencieuses : ne jamais renouveler déconnecte quelqu'un
// tous les mois sans que personne ne sache pourquoi, et renouveler sans plafond rend un jeton volé
// éternel pour qui s'en sert.

const JOUR = 86400;
const maintenant = () => Math.floor(Date.now() / 1000);

/// Un jeu de claims comme en produit `signSession` : émis il y a `ageJours`, valable 30 jours à
/// partir de là, et appartenant à une session commencée il y a `sessionJours`.
function claims({ ageJours, sessionJours = null }) {
  const t = maintenant();
  return {
    sub: 'user-42',
    iat: t - ageJours * JOUR,
    exp: t - ageJours * JOUR + SESSION_LIFETIME_DAYS * JOUR,
    sid: t - (sessionJours ?? ageJours) * JOUR,
  };
}

test('un jeton neuf ne se renouvelle pas', () => {
  assert.equal(shouldRenewSession(claims({ ageJours: 1 })), false);
});

test('un jeton passé à mi-vie se renouvelle', () => {
  assert.equal(shouldRenewSession(claims({ ageJours: 16 })), true);
});

test('la bascule se fait bien à la moitié de la vie du jeton', () => {
  const avant = claims({ ageJours: 0 });
  const t = maintenant();
  // Exactement la moitié restante : pas encore. Une seconde de moins : oui.
  avant.exp = t + (SESSION_LIFETIME_DAYS * JOUR) / 2;
  assert.equal(shouldRenewSession(avant, t), false);
  avant.exp = t + (SESSION_LIFETIME_DAYS * JOUR) / 2 - 1;
  assert.equal(shouldRenewSession(avant, t), true);
});

// LE PLAFOND. Sans lui, un jeton volé dont le voleur se sert se renouvelle à l'infini.
test('au-delà du plafond absolu, plus aucun renouvellement', () => {
  const vieux = claims({ ageJours: 20, sessionJours: ABSOLUTE_SESSION_DAYS + 1 });
  assert.equal(shouldRenewSession(vieux), false);
});

test('juste en deçà du plafond, le renouvellement a encore lieu', () => {
  const presque = claims({ ageJours: 20, sessionJours: ABSOLUTE_SESSION_DAYS - 1 });
  assert.equal(shouldRenewSession(presque), true);
});

test('un jeton déjà expiré ne ressuscite pas', () => {
  const mort = claims({ ageJours: SESSION_LIFETIME_DAYS + 1 });
  assert.equal(shouldRenewSession(mort), false);
});

test('des claims absents ou sans expiration ne renouvellent rien', () => {
  assert.equal(shouldRenewSession(null), false);
  assert.equal(shouldRenewSession({ sub: 'x' }), false);
});

// Les jetons émis avant que `sid` n'existe : leur plafond court depuis leur propre émission, et
// surtout PAS depuis maintenant — sinon il se repousserait à chaque renouvellement et le plafond
// ne plafonnerait rien.
test('un jeton sans `sid` fait courir son plafond depuis sa date d’émission', () => {
  const t = maintenant();
  assert.equal(sessionStartOf({ iat: t - 10 * JOUR }), t - 10 * JOUR);
  const ancien = { sub: 'u', iat: t - (ABSOLUTE_SESSION_DAYS + 5) * JOUR, exp: t + JOUR };
  assert.equal(shouldRenewSession(ancien, t), false, 'un vieux jeton sans sid ne se renouvelle pas');
});

test('`signSession` pose un début de session, et le recopie quand on le lui donne', async () => {
  const frais = await verifiedSessionClaims(bearer(await signSession('user-42')));
  assert.ok(Number.isFinite(frais.sid), 'un jeton neuf porte un `sid`');
  assert.ok(Math.abs(frais.sid - maintenant()) < 5, '`sid` vaut maintenant à la connexion');

  const debut = maintenant() - 40 * JOUR;
  const renouvele = await verifiedSessionClaims(bearer(await signSession('user-42', debut)));
  assert.equal(renouvele.sid, debut, 'le renouvellement garde le début d’origine');
  assert.ok(renouvele.exp > maintenant() + 29 * JOUR, 'et repart pour 30 jours');
});

// Le bout qui relie la décision à la réponse HTTP.
//
// `signSession` donne toujours trente jours, donc il ne peut pas produire un jeton proche de
// l'expiration : celui-ci est signé à la main avec la même clé, pour que l'assertion « l'en-tête
// est posé » porte vraiment sur quelque chose. Un test qui n'exerce pas le cas qu'il annonce est
// pire que pas de test — il fait croire que la ligne est couverte.
async function jetonExpirantDans(secondes, { sid = null } = {}) {
  const { SignJWT } = require('jose');
  const t = maintenant();
  return await new SignJWT({ sub: 'user-42', sid: sid ?? t })
    .setProtectedHeader({ alg: 'HS256' })
    .setJti('jti-de-test')
    .setIssuedAt(t)
    .setExpirationTime(t + secondes)
    .sign(new TextEncoder().encode(process.env.RUNUP_SESSION_SECRET));
}

test('`requireAuth` pose l’en-tête quand le jeton a passé la mi-vie', async () => {
  const entetes = {};
  const res = { headersSent: false, setHeader: (k, v) => { entetes[k] = v; } };

  const presqueExpire = await jetonExpirantDans(2 * JOUR);
  assert.equal(await requireAuth(bearer(presqueExpire), res), 'user-42');
  const renouvele = entetes[RENEWAL_HEADER];
  assert.ok(typeof renouvele === 'string' && renouvele.length > 20, 'un jeton doit être renvoyé');

  // Et ce jeton-là est utilisable, porte le même début de session, et repart pour trente jours.
  const neufClaims = await verifiedSessionClaims(bearer(renouvele));
  assert.equal(neufClaims.sub, 'user-42');
  assert.ok(neufClaims.exp > maintenant() + 29 * JOUR, 'le jeton rendu repart pour 30 jours');
});

test('un jeton neuf ne fait poser aucun en-tête', async () => {
  const entetes = {};
  const res = { headersSent: false, setHeader: (k, v) => { entetes[k] = v; } };
  assert.equal(await requireAuth(bearer(await signSession('user-42')), res), 'user-42');
  assert.equal(entetes[RENEWAL_HEADER], undefined);
});

// Le plafond, vu depuis la route : une session trop ancienne cesse d'être prolongée même quand
// son jeton est à bout de souffle. C'est là que le voleur s'arrête.
test('passé le plafond, la route ne renouvelle plus rien', async () => {
  const entetes = {};
  const res = { headersSent: false, setHeader: (k, v) => { entetes[k] = v; } };
  const vieilleSession = await jetonExpirantDans(
    2 * JOUR, { sid: maintenant() - (ABSOLUTE_SESSION_DAYS + 1) * JOUR });
  assert.equal(await requireAuth(bearer(vieilleSession), res), 'user-42',
               'la session reste valable jusqu’à son expiration');
  assert.equal(entetes[RENEWAL_HEADER], undefined, 'mais elle n’est plus prolongée');
});

test('sans `res`, l’authentification fonctionne toujours', async () => {
  const presqueExpire = await jetonExpirantDans(2 * JOUR);
  assert.equal(await requireAuth(bearer(presqueExpire)), 'user-42');
  assert.equal(await requireAuth(bearer(presqueExpire), null), 'user-42');
});

test('un jeton refusé ne pose jamais d’en-tête', async () => {
  const entetes = {};
  const res = { headersSent: false, setHeader: (k, v) => { entetes[k] = v; } };
  assert.equal(await requireAuth({ headers: {} }, res), null);
  assert.equal(entetes[RENEWAL_HEADER], undefined);
});

// ─── Les comptes de la maison ────────────────────────────────────────────────────────────────

const { estAdmin, listeConfiguree } = require('../lib/admin');

function avecListe(valeur, corps) {
  const avant = process.env.RUNUP_ADMIN_EMAILS;
  process.env.RUNUP_ADMIN_EMAILS = valeur;
  try { corps(); } finally {
    if (avant === undefined) delete process.env.RUNUP_ADMIN_EMAILS;
    else process.env.RUNUP_ADMIN_EMAILS = avant;
  }
}

test("sans liste, personne n'est admin", () => {
  // Un droit qui s'accorde tout seul quand une configuration manque est la plus mauvaise des
  // portes : c'est celle qui s'ouvre précisément le jour où on a oublié quelque chose.
  avecListe('', () => {
    assert.equal(listeConfiguree(), false);
    assert.equal(estAdmin('qui.que.ce.soit@exemple.com'), false);
    assert.equal(estAdmin(''), false);
    assert.equal(estAdmin(null), false);
    assert.equal(estAdmin(undefined), false);
  });
});

test("la casse ne retire pas le droit", () => {
  // La base a un index unique sur `lower(email)` : deux casses sont déjà le même compte. Les
  // traiter autrement ici ferait qu'une majuscule à l'inscription retirerait l'accès.
  avecListe('Chef@Exemple.COM', () => {
    assert.equal(estAdmin('chef@exemple.com'), true);
    assert.equal(estAdmin('CHEF@EXEMPLE.COM'), true);
    assert.equal(estAdmin(' chef@exemple.com '), true);
  });
});

test("plusieurs adresses, parce qu'un compte Apple en crée une autre", () => {
  // Le défaut qu'Hukaia a vécu : une seule adresse codée en dur, et le péage s'est refermé sur
  // la personne qui a écrit l'app — son iPhone s'était connecté avec Apple, sous une autre
  // adresse. RUNUP a la même porte, et Apple peut en plus masquer l'adresse derrière un relais.
  avecListe('a@exemple.com, b@exemple.fr ,c@privaterelay.appleid.com', () => {
    assert.equal(listeConfiguree(), true);
    assert.equal(estAdmin('a@exemple.com'), true);
    assert.equal(estAdmin('b@exemple.fr'), true);
    assert.equal(estAdmin('c@privaterelay.appleid.com'), true);
    assert.equal(estAdmin('d@exemple.com'), false);
  });
});

test("une liste qui n'est que des virgules ne configure rien", () => {
  avecListe(' , ,, ', () => {
    assert.equal(listeConfiguree(), false);
    assert.equal(estAdmin(''), false);
  });
});

test("la liste est relue à chaque appel", () => {
  // Elle n'est pas figée au chargement du module : changer la variable sur Vercel prend effet au
  // prochain démarrage de fonction, sans redéploiement du code.
  avecListe('un@exemple.com', () => assert.equal(estAdmin('un@exemple.com'), true));
  avecListe('deux@exemple.com', () => {
    assert.equal(estAdmin('un@exemple.com'), false);
    assert.equal(estAdmin('deux@exemple.com'), true);
  });
});
