// La règle d'autorisation sociale du serveur.
//
// `canViewActivity` répond à « cette personne a-t-elle le droit de voir, d'applaudir et de
// commenter cette sortie ». Elle garde les trois seuls chemins d'écriture sociale — les
// applaudissements, la lecture des commentaires et leur création — et elle n'avait AUCUN test.
//
// Elle encode quatre décisions qui ne se devinent pas en la lisant vite :
//
//   · l'autrice passe toujours, sans autre vérification ;
//   · un blocage DANS UN SENS OU DANS L'AUTRE l'emporte sur tout le reste ;
//   · l'appartenance au club se vérifie contre l'adhésion PRÉSENTE de la lectrice, pas contre le
//     club où l'autrice se trouvait au moment du post ;
//   · le suivi compte à sens unique, et seulement une fois accepté.
//
// Le cas qui casserait sans bruit : une activité dont le club a été supprimé porte `club_id` à
// NULL, et la règle retombe alors sur le suivi. C'est voulu. Une réécriture qui traiterait ce NULL
// comme « aucune restriction de club » ouvrirait chaque activité orpheline à tout le monde, et la
// suite resterait verte. Ce fichier l'épingle.
const test = require('node:test');
const assert = require('node:assert');

// Le faux `sql` doit être en place AVANT le premier `require` de `lib/social`, qui le charge à
// l'ouverture du module et non dans la fonction.
let etat = {};
const dbPath = require.resolve('../lib/db');
require.cache[dbPath] = {
  id: dbPath, filename: dbPath, loaded: true,
  exports: {
    sql: async (strings) => {
      const requete = strings.join('?');
      if (requete.includes('FROM blocks')) return { rows: etat.bloque ? [{ '?column?': 1 }] : [] };
      if (requete.includes('FROM club_members')) return { rows: etat.memeClub ? [{ '?column?': 1 }] : [] };
      if (requete.includes('FROM follows')) return { rows: etat.suitAccepte ? [{ '?column?': 1 }] : [] };
      throw new Error('requête inattendue : ' + requete);
    },
  },
};

const { canViewActivity } = require('../lib/social');

function contexte({ bloque = false, memeClub = false, suitAccepte = false } = {}) {
  etat = { bloque, memeClub, suitAccepte };
}

test('l’autrice voit toujours sa propre sortie', async () => {
  contexte({ bloque: true });
  assert.equal(await canViewActivity('u1', 'u1', 'club-1'), true);
});

test('un blocage l’emporte sur l’appartenance au club', async () => {
  contexte({ bloque: true, memeClub: true, suitAccepte: true });
  assert.equal(await canViewActivity('u1', 'u2', 'club-1'), false);
});

test('être du même club suffit', async () => {
  contexte({ memeClub: true });
  assert.equal(await canViewActivity('u1', 'u2', 'club-1'), true);
});

test('le club de l’activité ne suffit pas si la lectrice n’y est plus', async () => {
  contexte({ memeClub: false, suitAccepte: false });
  assert.equal(await canViewActivity('u1', 'u2', 'club-1'), false);
});

test('un suivi accepté suffit, même sans club', async () => {
  contexte({ suitAccepte: true });
  assert.equal(await canViewActivity('u1', 'u2', null), true);
});

test('un suivi en attente ne suffit pas', async () => {
  contexte({ suitAccepte: false });
  assert.equal(await canViewActivity('u1', 'u2', null), false);
});

// Le cas de l'activité orpheline, nommé plus haut : club supprimé, `club_id` à NULL. La règle doit
// retomber sur le suivi, et donc REFUSER quelqu'un qui ne suit pas.
test('une activité sans club ne s’ouvre pas à tout le monde', async () => {
  contexte({ memeClub: true, suitAccepte: false });
  assert.equal(await canViewActivity('u1', 'u2', null), false,
    'le club vrai ne doit pas être consulté quand l’activité n’en a pas');
});

test('un blocage seul, sans club ni suivi, refuse', async () => {
  contexte({ bloque: true });
  assert.equal(await canViewActivity('u1', 'u2', null), false);
});
