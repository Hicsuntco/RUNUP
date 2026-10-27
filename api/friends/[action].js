// Real friends/follow graph, independent of clubs — search | profile | follow | unfollow |
// respond | removeFollower | list | feed | setPrivate | updateProfile. Consolidated into one
// dynamic route, same pattern as api/clubs/[action].js and api/activities/[action].js.
//
// `profile` VIT ICI PLUTÔT QUE DANS UNE ROUTE À LUI, et pas seulement par goût du rangement :
// le plan Vercel du projet plafonne à douze fonctions serverless, et `api/` en compte déjà
// douze. Une treizième ferait échouer le déploiement entier — donc une fonctionnalité de plus
// se range dans la route dont elle relève, ce qui est ici le bon endroit de toute façon : une
// page de profil est une question du graphe d'abonnements.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling, isUuid } = require('../../lib/http');
const { sendPushToUser } = require('../../lib/apns');
const { isBlockedEitherWay, activityMetrics } = require('../../lib/social');
const { underDailyCap } = require('../../lib/rateLimit');
const { containsObjectionableContent } = require('../../lib/moderation');
// Le repli des noms pour la recherche — accents, casse, traits d'union, ligatures. Une seule
// table, partagée entre le texte tapé (replié ici, en JavaScript) et les colonnes (repliées par
// `translate` dans les requêtes ci-dessous). Voir l'en-tête de `lib/recherche.js`.
const {
  ACCENTS_SOURCE, ACCENTS_CIBLE, normaliser, echapperPourLike,
} = require('../../lib/recherche');

module.exports = withErrorHandling(async function handler(req, res) {
  const userId = await requireAuth(req, res);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'search':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleSearch(req, res, userId);
    case 'profile':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleProfile(req, res, userId);
    case 'suggestions':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleSuggestions(req, res, userId);
    case 'matchContacts':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleMatchContacts(req, res, userId);
    case 'follow':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleFollow(req, res, userId);
    case 'unfollow':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleUnfollow(req, res, userId);
    case 'respond':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRespond(req, res, userId);
    case 'removeFollower':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleRemoveFollower(req, res, userId);
    case 'list':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleList(req, res, userId);
    case 'feed':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleFeed(req, res, userId);
    case 'setPrivate':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleSetPrivate(req, res, userId);
    case 'updateProfile':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleUpdateProfile(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

function mapUser(row) {
  return {
    id: row.id,
    name: row.name,
    lastName: row.last_name || null,
    username: row.username || null,
    avatarBase64: row.avatar_data || null,
    avatarUrl: row.avatar_url || null,
    isPrivate: row.is_private,
    followStatus: row.follow_status || null,
  };
}

const USERNAME_RE = /^[a-z0-9_]{3,20}$/;

// Trouve de vrais comptes à suivre. Trois façons de chercher, selon ce qui a été tapé :
//
//   · une adresse e-mail (contient « @ ») : correspondance EXACTE, jamais partielle — une adresse
//     ne se cherche pas par morceaux, sans quoi ce point d'entrée servirait à moissonner
//     l'annuaire ;
//   · sinon : un pseudo qui COMMENCE par ce qui est tapé, ou un nom qui le CONTIENT.
//
// # CE QUI RENDAIT LA RECHERCHE DIFFICILE, ET QUI NE L'EST PLUS
//
// Elle comparait `name || ' ' || last_name` au texte tapé, tels quels. Trois conséquences, toutes
// vécues :
//
//   · « leo » ne trouvait pas « Léo ». `ILIKE` ignore la casse, pas les accents — dans une app
//     française, c'est la moitié des prénoms ;
//   · « perret charlotte » ne trouvait pas « Charlotte Perret ». La chaîne était toujours
//     construite prénom-puis-nom, et chercher quelqu'un par son nom est pourtant le réflexe de
//     qui le connaît peu ;
//   · « jean pierre » ne trouvait pas « Jean-Pierre », et réciproquement.
//
// Les deux côtés sont donc repliés par la même table (`lib/recherche.js`), et la comparaison se
// fait dans LES DEUX ORDRES. Le tri met en tête ce qui ressemble le plus à une intention : le
// pseudo exact d'abord, puis un prénom qui commence par ce qui est tapé, puis le reste.
//
// Exclut soi-même et toute personne bloquée dans un sens ou dans l'autre. `followStatus` est vu
// DEPUIS L'APPELANTE — est-ce qu'ELLE suit déjà ce résultat — pour que le client affiche le bon
// bouton (Suivre / Demande envoyée / Abonné·e) sans un aller-retour par ligne.
async function handleSearch(req, res, userId) {
  const raw = typeof req.query.q === 'string' ? req.query.q.trim().slice(0, 60) : '';
  if (raw.length < 2) return res.status(200).json({ items: [] });

  // Same daily cap every write path in this file uses. Search is a read, but it's the one endpoint
  // that walks the whole user directory, so it's what a script would hammer to enumerate accounts
  // one prefix at a time. 300/day is far past any real use: the client searches as she types, so
  // looking someone up costs a handful of requests. Counted after the <2 char guard so keystrokes
  // that never reach the database don't burn the quota.
  if (!(await underDailyCap('search:' + userId, 300))) return res.status(429).json({ error: 'too_many_requests' });

  let rows;
  if (raw.includes('@')) {
    ({ rows } = await sql`
      SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private, f.status AS follow_status
      FROM users u
      LEFT JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = u.id
      WHERE u.id != ${userId} AND lower(u.email) = lower(${raw})
        AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
        AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
      LIMIT 5
    `);
  } else {
    // Replié ici, comparé replié là-bas : `besoin` est ce que la requête cherche réellement.
    const besoin = echapperPourLike(normaliser(raw));
    const pseudo = echapperPourLike(normaliser(raw.replace(/^@/, '')).replace(/\s+/g, ''));
    ({ rows } = await sql`
      SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private, f.status AS follow_status
      FROM users u
      LEFT JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = u.id
      WHERE u.id != ${userId}
        AND (
          lower(u.username) LIKE ${pseudo + '%'}
          OR translate(lower(replace(replace(replace(
               u.name || ' ' || coalesce(u.last_name, ''), '-', ' '), 'œ', 'oe'), 'æ', 'ae')),
               ${ACCENTS_SOURCE}, ${ACCENTS_CIBLE}) LIKE ${'%' + besoin + '%'}
          OR translate(lower(replace(replace(replace(
               coalesce(u.last_name, '') || ' ' || u.name, '-', ' '), 'œ', 'oe'), 'æ', 'ae')),
               ${ACCENTS_SOURCE}, ${ACCENTS_CIBLE}) LIKE ${'%' + besoin + '%'}
        )
        AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
        AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
      ORDER BY
        (lower(u.username) = ${pseudo}) DESC,
        (translate(lower(u.name), ${ACCENTS_SOURCE}, ${ACCENTS_CIBLE}) LIKE ${besoin + '%'}) DESC,
        (translate(lower(coalesce(u.last_name, '')), ${ACCENTS_SOURCE}, ${ACCENTS_CIBLE}) LIKE ${besoin + '%'}) DESC,
        u.name ASC
      LIMIT 20
    `);
  }
  res.status(200).json({ items: rows.map(mapUser) });
}

// LES GENS QU'ON N'A PAS BESOIN DE CHERCHER.
//
// La meilleure recherche est celle qu'on n'a pas à taper. Deux populations sont connues du
// serveur sans que personne n'ait rien à écrire :
//
//   · les membres de ses clubs qu'elle ne suit pas encore — elle est dans le même club qu'eux,
//     c'est à peu près la définition de « quelqu'un que je connais » dans cette app ;
//   · celles et ceux qui la suivent sans qu'elle les suive en retour.
//
// L'écran les affichait déjà… non : il affichait « Personne à suivre pour l'instant » et un
// champ de recherche, à quelqu'un dont le club était plein de gens à suivre. C'est le défaut que
// cette route répare.
//
// Les deux sources portent leur RAISON, parce qu'une liste de noms sans explication ressemble à
// un annuaire — et qu'on ne suit pas un annuaire. Le client affiche « Dans ton club » ou
// « Te suit déjà ».
//
// Pas de cap journalier ici : c'est une lecture bornée à vingt lignes, déclenchée par l'ouverture
// d'un écran et non par une frappe, et elle ne renvoie que des gens déjà reliés à l'appelante —
// il n'y a pas d'annuaire à moissonner par cette porte.
async function handleSuggestions(req, res, userId) {
  const { rows } = await sql`
    WITH mes_clubs AS (
      SELECT club_id FROM club_members WHERE user_id = ${userId}
    ),
    candidats AS (
      -- Les membres de mes clubs. DISTINCT parce que deux clubs partagés ne font pas deux
      -- personnes.
      SELECT DISTINCT cm.user_id AS id, 'club'::text AS raison
      FROM club_members cm
      WHERE cm.club_id IN (SELECT club_id FROM mes_clubs) AND cm.user_id != ${userId}
      UNION
      -- Celles et ceux qui me suivent. Une demande en attente ne compte pas : elle n'a pas
      -- encore été acceptée, et proposer de suivre quelqu'un dont on n'a pas validé la demande
      -- inverse les rôles.
      SELECT fo.follower_id AS id, 'follower'::text AS raison
      FROM follows fo
      WHERE fo.followee_id = ${userId} AND fo.status = 'accepted'
    )
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private,
           f.status AS follow_status,
           -- Un même compte peut être dans les deux : « dans ton club » est la raison la plus
           -- parlante des deux, donc elle gagne.
           min(c.raison) AS raison
    FROM candidats c
    JOIN users u ON u.id = c.id
    LEFT JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = u.id
    WHERE f.status IS NULL
      AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
      AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
    GROUP BY u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private, f.status
    ORDER BY min(c.raison) ASC, u.name ASC
    LIMIT 20
  `;
  res.status(200).json({ items: rows.map((row) => ({ ...mapUser(row), reason: row.raison })) });
}

// Retrouve, parmi les comptes existants, ceux dont l'adresse e-mail est dans le carnet d'adresses
// de l'appelante — sans jamais recevoir ce carnet.
//
// Le téléphone hache chaque adresse (SHA-256 de l'adresse en minuscules, sans espaces) et n'envoie
// que les empreintes. Ce point d'entrée compare des empreintes à la colonne générée
// `users.email_sha256` : il ne voit aucune adresse, n'en écrit aucune, et ne garde rien de ce
// qu'on lui envoie. Une empreinte qui ne correspond à personne ne laisse aucune trace.
//
// Ce que ça NE trouve pas, et il vaut mieux le savoir que le découvrir : quelqu'un inscrit avec une
// adresse que l'appelante n'a pas dans ses contacts, et quiconque s'est inscrit avec « Masquer mon
// adresse e-mail » d'Apple, dont l'adresse relais n'existe dans le carnet de personne. La
// recherche par nom et par identifiant reste le chemin pour ces cas-là.
async function handleMatchContacts(req, res, userId) {
  const raw = Array.isArray(req.body?.hashes) ? req.body.hashes : null;
  if (!raw) return res.status(400).json({ error: 'hashes_required' });

  // Empreintes SHA-256 en hexadécimal, et rien d'autre. Le filtre n'est pas cosmétique : sans lui,
  // ce point d'entrée accepterait n'importe quelle chaîne, et la première personne qui essaierait
  // d'y passer des adresses en clair réussirait — l'app enverrait alors le carnet d'adresses que
  // tout ce montage existe pour ne pas envoyer.
  const hashes = [...new Set(
    raw.filter((h) => typeof h === 'string' && /^[a-f0-9]{64}$/.test(h))
  )].slice(0, 1000);
  if (hashes.length === 0) return res.status(200).json({ items: [] });

  // Plafond quotidien plus bas que celui de la recherche : un carnet d'adresses ne change pas
  // vingt fois par jour, et chaque appel compare mille empreintes d'un coup. Vingt suffisent
  // largement à un usage réel, et bornent ce qu'un script pourrait tester d'adresses.
  if (!(await underDailyCap('contacts:' + userId, 20))) return res.status(429).json({ error: 'too_many_requests' });

  const { rows } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private, f.status AS follow_status
    FROM users u
    LEFT JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = u.id
    WHERE u.id != ${userId} AND u.email_sha256 = ANY(${hashes})
      AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
      AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
    ORDER BY u.name ASC
    LIMIT 100
  `;
  res.status(200).json({ items: rows.map(mapUser) });
}

// Sets the caller's own chosen handle and/or last name — both optional, either can be sent alone.
// `username` is validated (lowercase letters/digits/underscore, 3-20 chars) and must be globally
// unique (case-insensitively — see the DB's functional unique index); `lastName` gets the same
// content filter as every other user-visible free-text field.
// LE PRÉNOM EST MODIFIABLE, ET CE N'EST PAS UN CONFORT.
//
// Il était écrit UNE FOIS, à l'inscription, et plus jamais. Or « Se connecter avec Apple » ne
// transmet `fullName` qu'à la TOUTE PREMIÈRE autorisation d'un identifiant Apple pour cette
// app : une réinstallation, un second appareil, ou un compte Apple qui avait déjà ouvert RUNUP
// une fois n'envoient rien. Le serveur rangeait alors le compte sous « Coureur » — et personne
// ne pouvait plus le corriger, depuis aucun écran.
//
// Résultat : la recherche de « Mes amis » cherche dans `name || ' ' || last_name`, donc taper le
// vrai prénom de quelqu'un ne le trouvait pas. Et taper « Coureur » les trouvait tous, identiques.
//
// Contrairement au pseudo et au nom, le prénom ne peut pas être EFFACÉ : la colonne est
// `NOT NULL`, et un compte sans nom n'a rien à afficher dans un fil d'activité.
async function handleUpdateProfile(req, res, userId) {
  const { name, username, lastName } = req.body || {};
  const updates = {};

  if (name !== undefined) {
    const cleanName = typeof name === 'string' ? name.trim().slice(0, 60) : '';
    if (!cleanName) return res.status(400).json({ error: 'bad_request' });
    if (containsObjectionableContent(cleanName)) return res.status(422).json({ error: 'objectionable_content' });
    updates.name = cleanName;
  }

  if (username !== undefined) {
    if (username === null || username === '') {
      updates.username = null;
    } else {
      const cleanUsername = typeof username === 'string' ? username.trim().toLowerCase() : '';
      if (!USERNAME_RE.test(cleanUsername)) return res.status(400).json({ error: 'bad_username' });
      if (containsObjectionableContent(cleanUsername)) return res.status(422).json({ error: 'objectionable_content' });
      updates.username = cleanUsername;
    }
  }
  if (lastName !== undefined) {
    if (lastName === null || lastName === '') {
      updates.lastName = null;
    } else {
      const cleanLastName = typeof lastName === 'string' ? lastName.trim().slice(0, 60) : '';
      if (!cleanLastName) return res.status(400).json({ error: 'bad_request' });
      if (containsObjectionableContent(cleanLastName)) return res.status(422).json({ error: 'objectionable_content' });
      updates.lastName = cleanLastName;
    }
  }
  if (Object.keys(updates).length === 0) return res.status(400).json({ error: 'bad_request' });

  try {
    if ('name' in updates) await sql`UPDATE users SET name = ${updates.name} WHERE id = ${userId}`;
    if ('username' in updates) await sql`UPDATE users SET username = ${updates.username} WHERE id = ${userId}`;
    if ('lastName' in updates) await sql`UPDATE users SET last_name = ${updates.lastName} WHERE id = ${userId}`;
  } catch (e) {
    if (String(e.message).includes('uniq_users_username_lower')) {
      return res.status(409).json({ error: 'username_taken' });
    }
    throw e;
  }
  res.status(200).json({ ok: true });
}

// Follows a real account — instant ('accepted') unless they've gone private, in which case it's
// a request they must approve (see `respond`). Idempotent on the (follower_id, followee_id) pair:
// re-tapping "Suivre" on an already pending/accepted target just returns the current state.
async function handleFollow(req, res, userId) {
  const { userId: targetId } = req.body || {};
  if (!isUuid(targetId) || targetId === userId) return res.status(400).json({ error: 'bad_request' });
  if (await isBlockedEitherWay(userId, targetId)) return res.status(404).json({ error: 'not_found' });
  if (!(await underDailyCap('follow:' + userId, 150))) return res.status(429).json({ error: 'too_many_requests' });

  const { rows: targetRows } = await sql`SELECT is_private FROM users WHERE id = ${targetId}`;
  const target = targetRows[0];
  if (!target) return res.status(404).json({ error: 'not_found' });

  const status = target.is_private ? 'pending' : 'accepted';
  const { rows: inserted } = await sql`
    INSERT INTO follows (follower_id, followee_id, status) VALUES (${userId}, ${targetId}, ${status})
    ON CONFLICT (follower_id, followee_id) DO NOTHING
    RETURNING status
  `;
  if (inserted.length === 0) {
    const { rows: existing } = await sql`SELECT status FROM follows WHERE follower_id = ${userId} AND followee_id = ${targetId}`;
    return res.status(200).json({ status: existing[0]?.status || status });
  }

  // Before the response — Vercel may freeze the function once it's sent.
  const { rows: me } = await sql`SELECT name FROM users WHERE id = ${userId}`;
  const myName = me[0]?.name || 'Quelqu’un';
  await sendPushToUser(sql, targetId, {
    title: 'Amis',
    body: status === 'pending' ? `${myName} a demandé à te suivre` : `${myName} te suit maintenant`,
  });

  res.status(200).json({ status: inserted[0].status });
}

async function handleUnfollow(req, res, userId) {
  const { userId: targetId } = req.body || {};
  if (!isUuid(targetId)) return res.status(400).json({ error: 'bad_request' });
  await sql`DELETE FROM follows WHERE follower_id = ${userId} AND followee_id = ${targetId}`;
  res.status(200).json({ ok: true });
}

// The FOLLOWEE approves/declines a request targeting them — the only case a follow needs a
// second step (private accounts). Accept flips the row to 'accepted'; decline just deletes it,
// same as the requester never having followed at all.
async function handleRespond(req, res, userId) {
  const { userId: followerId, accept } = req.body || {};
  if (!isUuid(followerId) || typeof accept !== 'boolean') return res.status(400).json({ error: 'bad_request' });

  if (!accept) {
    await sql`DELETE FROM follows WHERE follower_id = ${followerId} AND followee_id = ${userId} AND status = 'pending'`;
    return res.status(200).json({ ok: true });
  }

  const { rows } = await sql`
    UPDATE follows SET status = 'accepted' WHERE follower_id = ${followerId} AND followee_id = ${userId} AND status = 'pending'
    RETURNING follower_id
  `;
  if (rows.length === 0) return res.status(404).json({ error: 'not_found' });

  const { rows: me } = await sql`SELECT name FROM users WHERE id = ${userId}`;
  await sendPushToUser(sql, followerId, {
    title: 'Amis',
    body: `${me[0]?.name || 'Quelqu’un'} a accepté ta demande`,
  });

  res.status(200).json({ ok: true });
}

// Lets the FOLLOWEE remove someone following them without either side unfollowing the other —
// same distinction most social apps make between "unfollow" (my side) and "remove follower"
// (their side).
async function handleRemoveFollower(req, res, userId) {
  const { userId: followerId } = req.body || {};
  if (!isUuid(followerId)) return res.status(400).json({ error: 'bad_request' });
  await sql`DELETE FROM follows WHERE follower_id = ${followerId} AND followee_id = ${userId}`;
  res.status(200).json({ ok: true });
}

// LES TROIS SEULES LECTURES DU DÉPÔT SANS PLAFOND, et elles servent l'écran Amis, ouvert souvent.
// Le quota de suivi est de 150 par jour, donc un compte d'un an peut suivre des dizaines de
// milliers de personnes — et rien ne borne le nombre d'abonnés. La réponse grossissait sans limite,
// chaque ligne pouvant porter un avatar en base64 hérité de plusieurs centaines de kilo-octets.
//
// `avatar_data` n'est plus renvoyée quand une URL existe : le client lit l'URL en priorité, donc
// c'était du poids mort sur chaque ligne. Elle reste servie pour les comptes anciens qui n'ont que
// ça, sans quoi leur photo disparaîtrait.
async function handleList(req, res, userId) {
  const { rows: meRows } = await sql`SELECT is_private FROM users WHERE id = ${userId}`;
  const { rows: following } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_url, u.is_private,
           CASE WHEN u.avatar_url IS NULL THEN u.avatar_data END AS avatar_data
    FROM follows f JOIN users u ON u.id = f.followee_id
    WHERE f.follower_id = ${userId} AND f.status = 'accepted'
    ORDER BY u.name ASC
    LIMIT 500
  `;
  const { rows: followers } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_url, u.is_private,
           CASE WHEN u.avatar_url IS NULL THEN u.avatar_data END AS avatar_data
    FROM follows f JOIN users u ON u.id = f.follower_id
    WHERE f.followee_id = ${userId} AND f.status = 'accepted'
    ORDER BY u.name ASC
    LIMIT 500
  `;
  const { rows: incoming } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_url, u.is_private,
           CASE WHEN u.avatar_url IS NULL THEN u.avatar_data END AS avatar_data
    FROM follows f JOIN users u ON u.id = f.follower_id
    WHERE f.followee_id = ${userId} AND f.status = 'pending'
    ORDER BY f.created_at ASC
    LIMIT 500
  `;
  res.status(200).json({
    isPrivate: meRows[0]?.is_private || false,
    following: following.map(mapUser),
    followers: followers.map(mapUser),
    incomingRequests: incoming.map(mapUser),
  });
}

// Real activities from people she follows — same response shape as api/activities/feed (club
// feed) so the client renders both with the same row component, just sourced from the follow
// graph instead of club membership. One-way: only accepted follows in HER OWN follower→followee
// direction, matching `canViewActivity` in lib/social.js so a post visible here is always also
// kudos/comment-able there.
async function handleFeed(req, res, userId) {
  const { rows } = await sql`
    SELECT a.id, a.text, a.created_at, u.name, u.id AS user_id, u.avatar_data, u.avatar_url,
           a.distance_km, a.duration_seconds, a.avg_pace, a.elevation_gain_m, a.is_personal_record,
           a.content_key, a.discipline,
           -- MÊME CARTE, MÊMES CHAMPS. Les deux fils sont décodés par le MÊME type côté app, et
           -- celui-ci ne sélectionnait ni le tracé, ni le titre, ni la note, ni la date
           -- d'édition : la même sortie s'affichait avec sa carte et son titre dans l'onglet
           -- Club, et nue dans l'onglet Amis. Aucune erreur nulle part — les champs sont
           -- optionnels au décodage, donc l'absence passait inaperçue.
           a.route_preview, a.title, a.note, a.edited_at, a.photo_url,
           (SELECT COUNT(*)::int FROM activity_kudos k WHERE k.activity_id = a.id) AS kudos,
           EXISTS(SELECT 1 FROM activity_kudos k WHERE k.activity_id = a.id AND k.user_id = ${userId}) AS kudoed_by_me,
           (SELECT COUNT(*)::int FROM activity_comments c WHERE c.activity_id = a.id) AS comments_count
    FROM activities a
    JOIN users u ON u.id = a.user_id
    JOIN follows f ON f.follower_id = ${userId} AND f.followee_id = a.user_id AND f.status = 'accepted'
    WHERE a.user_id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
      AND a.user_id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
    ORDER BY a.created_at DESC
    LIMIT 50
  `;
  res.status(200).json({
    items: rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      name: r.name,
      avatarBase64: r.avatar_data || null,
      avatarUrl: r.avatar_url || null,
      text: r.text,
      title: r.title || null,
      note: r.note || null,
      editedAt: r.edited_at || null,
      routePreview: r.route_preview || null,
      photoUrl: r.photo_url || null,
      createdAt: r.created_at,
      ...activityMetrics(r),
      kudos: r.kudos,
      kudoedByMe: r.kudoed_by_me,
      commentsCount: r.comments_count,
    })),
  });
}

// --- LA PAGE DE QUELQU'UN -------------------------------------------------------------------
//
// # CE QU'ELLE REND, ET CE QU'ELLE REFUSE DE RENDRE
//
// Trois réponses possibles, et la différence entre les deux dernières est tout l'objet de cette
// fonction :
//
//   · BLOQUÉ, d'un côté ou de l'autre → 404, volontairement indistinguable d'un compte qui
//     n'existe pas. Dire « cette personne t'a bloqué » serait lui retirer le bénéfice du blocage ;
//   · COMPTE PRIVÉ que je ne suis pas → l'en-tête SEUL. Le nom, la photo, le mot de présentation,
//     les compteurs et les badges — de quoi reconnaître la bonne personne et demander à la
//     suivre. Pas une seule de ses sorties. C'est la règle d'Instagram, et c'est la seule qui
//     rende un compte privé utilisable : invisible, personne ne pourrait le retrouver pour le
//     suivre ; ouvert, il ne serait pas privé.
//   · SINON → l'en-tête et ses vingt dernières sorties.
//
// Les sorties ne sont pas « masquées par le client » : quand `canSeeRuns` est faux, la requête
// n'est pas faite. Une donnée qu'on ne lit pas est la seule qui ne puisse pas fuir par un écran
// qu'on n'avait pas prévu.
async function handleProfile(req, res, userId) {
  const cible = typeof req.query.userId === 'string' ? req.query.userId : '';
  if (!isUuid(cible)) return res.status(400).json({ error: 'bad_request' });

  if (cible !== userId && await isBlockedEitherWay(userId, cible)) {
    return res.status(404).json({ error: 'not_found' });
  }

  const { rows: personnes } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.bio, u.avatar_data, u.avatar_url,
           u.is_private, u.created_at,
           (SELECT COUNT(*)::int FROM follows f WHERE f.followee_id = u.id AND f.status = 'accepted') AS followers,
           (SELECT COUNT(*)::int FROM follows f WHERE f.follower_id = u.id AND f.status = 'accepted') AS following,
           (SELECT COUNT(*)::int FROM activities a WHERE a.user_id = u.id AND a.type = 'run') AS runs,
           -- Le total de kilomètres de ses sorties, pas un compteur tenu à part : un compteur
           -- dérive dès qu'une sortie est supprimée, et il en existe un chemin (api/activities
           -- delete).
           (SELECT COALESCE(SUM(a.distance_km), 0) FROM activities a
             WHERE a.user_id = u.id AND a.type = 'run') AS total_km,
           (SELECT ARRAY_AGG(b.badge_key) FROM user_badges b WHERE b.user_id = u.id) AS badge_keys,
           (SELECT f.status FROM follows f WHERE f.follower_id = ${userId} AND f.followee_id = u.id) AS follow_status,
           EXISTS(SELECT 1 FROM follows f WHERE f.follower_id = u.id AND f.followee_id = ${userId} AND f.status = 'accepted') AS follows_me
    FROM users u WHERE u.id = ${cible}
  `;
  if (personnes.length === 0) return res.status(404).json({ error: 'not_found' });
  const p = personnes[0];

  const cestMoi = cible === userId;
  const canSeeRuns = cestMoi || !p.is_private || p.follow_status === 'accepted';

  let sorties = [];
  if (canSeeRuns) {
    const { rows } = await sql`
      SELECT a.id, a.text, a.created_at, a.distance_km, a.duration_seconds, a.avg_pace,
             a.elevation_gain_m, a.is_personal_record, a.content_key, a.discipline,
             a.route_preview, a.title, a.note, a.edited_at, a.photo_url,
             (SELECT COUNT(*)::int FROM activity_kudos k WHERE k.activity_id = a.id) AS kudos,
             EXISTS(SELECT 1 FROM activity_kudos k WHERE k.activity_id = a.id AND k.user_id = ${userId}) AS kudoed_by_me,
             (SELECT COUNT(*)::int FROM activity_comments c WHERE c.activity_id = a.id) AS comments_count
      FROM activities a
      WHERE a.user_id = ${cible}
      ORDER BY a.created_at DESC
      LIMIT 20
    `;
    sorties = rows.map((r) => ({
      id: r.id,
      userId: cible,
      name: p.name,
      avatarBase64: p.avatar_data || null,
      avatarUrl: p.avatar_url || null,
      text: r.text,
      title: r.title || null,
      note: r.note || null,
      editedAt: r.edited_at || null,
      routePreview: r.route_preview || null,
      photoUrl: r.photo_url || null,
      createdAt: r.created_at,
      ...activityMetrics(r),
      kudos: r.kudos,
      kudoedByMe: r.kudoed_by_me,
      commentsCount: r.comments_count,
    }));
  }

  res.status(200).json({
    profile: {
      id: p.id,
      name: p.name,
      lastName: p.last_name || null,
      username: p.username || null,
      bio: p.bio || null,
      avatarBase64: p.avatar_data || null,
      avatarUrl: p.avatar_url || null,
      isPrivate: p.is_private,
      isMe: cestMoi,
      followStatus: p.follow_status || null,
      followsMe: p.follows_me === true,
      followers: p.followers,
      following: p.following,
      runs: p.runs,
      totalKm: Number(p.total_km),
      badgeKeys: p.badge_keys || [],
      joinedAt: p.created_at,
      // Dit EXPLICITEMENT plutôt que déduit d'une liste vide : « ce compte est privé » et « cette
      // personne n'a encore rien couru » sont deux écrans différents, et le client ne peut pas
      // les distinguer autrement.
      canSeeRuns,
    },
    items: sorties,
  });
}

async function handleSetPrivate(req, res, userId) {
  const { isPrivate } = req.body || {};
  if (typeof isPrivate !== 'boolean') return res.status(400).json({ error: 'bad_request' });
  await sql`UPDATE users SET is_private = ${isPrivate} WHERE id = ${userId}`;
  res.status(200).json({ ok: true });
}
