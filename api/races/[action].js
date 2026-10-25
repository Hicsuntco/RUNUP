// La page d'une course officielle : qui la prépare, où ils en sont, qui cherche quelqu'un à son
// allure, qui cède ou cherche un dossard, et ce qu'ils se disent.
//
// Une seule route dynamique ([action] = search | upcoming | create | follow | unfollow | page |
// post | closePost | mine), même raison que api/clubs et api/auth : neuf fichiers de vingt lignes
// partageant les mêmes gardes valent moins qu'un fichier où l'on voit la fonctionnalité entière.
//
// # CE QUE CETTE ROUTE NE FAIT PAS
//
// Elle n'encaisse rien. Le mur d'annonces met deux personnes en contact et s'arrête là : aucun
// paiement, aucune garantie, aucune vérification de dossard. La plupart des organisateurs
// INTERDISENT le transfert — courir sous le nom d'un autre, c'est la disqualification, et surtout
// des secours qui liraient le mauvais dossier médical. L'app l'affiche sur chaque annonce plutôt
// que de faire comme si la question ne se posait pas.
// `race_date` sort en CHAÎNE (`to_char`) et non en date : une colonne DATE traverse le pilote en
// objet Date JS, donc en ISO avec une heure et un fuseau, et le 4 avril devient le 3 avril à 22 h
// pour qui la relit en UTC. Une date de course n'a pas d'heure ; elle n'a pas à en gagner une au
// passage.
const { sql } = require('../../lib/db');
const { requireAuth } = require('../../lib/auth');
const { withErrorHandling, isUuid } = require('../../lib/http');
const { containsObjectionableContent } = require('../../lib/moderation');
const { underDailyCap } = require('../../lib/rateLimit');
// Le même repli que la recherche de personnes et de clubs : accents, casse, traits d'union,
// ligatures. « marathon de paris » trouve « Marathon de PARIS », et surtout l'index UNIQUE sur
// (nom replié, date) empêche les deux d'exister en même temps.
const { ACCENTS_SOURCE, ACCENTS_CIBLE, normaliser, echapperPourLike } = require('../../lib/recherche');
const { nettoyerCourse } = require('../../lib/courses');

// Ce qu'un message peut être. `partner` est une recherche de partenaire, `bib_offer` une annonce
// de cession, `bib_wanted` une recherche de dossard, `message` tout le reste.
const GENRES = ['message', 'partner', 'bib_offer', 'bib_wanted'];
const LONGUEUR_MESSAGE = 1000;

module.exports = withErrorHandling(async function handler(req, res) {
  const userId = await requireAuth(req, res);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  switch (req.query.action) {
    case 'search':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleSearch(req, res, userId);
    case 'upcoming':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleUpcoming(req, res, userId);
    case 'mine':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handleMine(req, res, userId);
    case 'page':
      if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
      return handlePage(req, res, userId);
    case 'create':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleCreate(req, res, userId);
    case 'follow':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleFollow(req, res, userId);
    case 'unfollow':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleUnfollow(req, res, userId);
    case 'post':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handlePost(req, res, userId);
    case 'kudos':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleKudos(req, res, userId);
    case 'closePost':
      if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
      return handleClosePost(req, res, userId);
    default:
      return res.status(404).json({ error: 'not_found' });
  }
});

function mapRace(row) {
  return {
    id: row.id,
    name: row.name,
    city: row.city || null,
    raceDate: row.race_date,
    distanceKm: row.distance_km === null || row.distance_km === undefined ? null : Number(row.distance_km),
    elevationGainM: row.elevation_gain_m === null ? null : row.elevation_gain_m,
    discipline: row.discipline,
    website: row.website || null,
    followerCount: row.follower_count === undefined ? null : Number(row.follower_count),
  };
}

// --- Trouver une course --------------------------------------------------------------------------

// Les courses PASSÉES ne sont jamais rendues. Une page de course sert à préparer la course :
// une fois qu'elle a eu lieu, elle n'a plus personne à mettre en relation ni de dossard à céder.
async function handleSearch(req, res, userId) {
  const raw = typeof req.query.q === 'string' ? req.query.q.trim().slice(0, 80) : '';
  if (raw.length < 2) return res.status(200).json({ items: [] });

  if (!(await underDailyCap('raceSearch:' + userId, 300))) {
    return res.status(429).json({ error: 'too_many_requests' });
  }

  const besoin = echapperPourLike(normaliser(raw));
  const { rows } = await sql`
    SELECT r.id, r.name, r.city, to_char(r.race_date, 'YYYY-MM-DD') AS race_date, r.distance_km, r.elevation_gain_m, r.discipline,
           r.website, r.is_seeded,
           (SELECT COUNT(*)::int FROM race_followers f WHERE f.race_id = r.id) AS follower_count
    FROM races r
    WHERE r.race_date >= CURRENT_DATE
      AND (r.name_key LIKE ${'%' + besoin + '%'}
           OR translate(lower(coalesce(r.city, '')), ${ACCENTS_SOURCE}, ${ACCENTS_CIBLE}) LIKE ${'%' + besoin + '%'})
    ORDER BY
      -- Ce qui commence par ce qui est tapé d'abord, puis les courses semées par l'app (elles
      -- portent le nom officiel, donc ce sont elles qu'on veut voir avant une saisie approximative
      -- du même événement), puis la plus proche dans le temps.
      (r.name_key LIKE ${besoin + '%'}) DESC,
      r.is_seeded DESC,
      r.race_date ASC
    LIMIT 25
  `;
  res.status(200).json({ items: rows.map(mapRace) });
}

// Ce qu'on propose quand rien n'est tapé : les courses les plus suivies qui approchent. La
// meilleure recherche reste celle qu'on n'a pas à taper.
async function handleUpcoming(req, res, userId) {
  const { rows } = await sql`
    SELECT r.id, r.name, r.city, to_char(r.race_date, 'YYYY-MM-DD') AS race_date, r.distance_km, r.elevation_gain_m, r.discipline,
           r.website,
           (SELECT COUNT(*)::int FROM race_followers f WHERE f.race_id = r.id) AS follower_count
    FROM races r
    WHERE r.race_date >= CURRENT_DATE
      AND r.id NOT IN (SELECT race_id FROM race_followers WHERE user_id = ${userId})
    ORDER BY follower_count DESC, r.race_date ASC
    LIMIT 20
  `;
  res.status(200).json({ items: rows.map(mapRace) });
}

// Les courses que je prépare. Peut en contenir plusieurs : on peut viser un 10 km en mars et un
// marathon en octobre, et c'est même le cas le plus courant d'une saison.
async function handleMine(req, res, userId) {
  const { rows } = await sql`
    SELECT r.id, r.name, r.city, to_char(r.race_date, 'YYYY-MM-DD') AS race_date, r.distance_km, r.elevation_gain_m, r.discipline,
           r.website,
           (SELECT COUNT(*)::int FROM race_followers f WHERE f.race_id = r.id) AS follower_count
    FROM race_followers me
    JOIN races r ON r.id = me.race_id
    WHERE me.user_id = ${userId} AND r.race_date >= CURRENT_DATE
    ORDER BY r.race_date ASC
  `;
  res.status(200).json({ items: rows.map(mapRace) });
}

// --- Créer une course ----------------------------------------------------------------------------

// LE DOUBLON EST LE SEUL VRAI RISQUE DE CETTE FONCTIONNALITÉ.
//
// Toute sa valeur tient à ce que deux personnes qui préparent la même course atterrissent sur la
// MÊME page. L'index UNIQUE sur (nom replié, date) est la garantie dure ; ce handler en fait une
// réponse utile plutôt qu'une erreur : si la course existe déjà, il la RENVOIE au lieu de refuser.
// Quelqu'un qui tape un nom déjà pris arrive donc sur la bonne page sans comprendre qu'il a failli
// créer un doublon — ce qui est exactement ce qu'on veut qu'il vive.
async function handleCreate(req, res, userId) {
  if (!(await underDailyCap('raceCreate:' + userId, 10))) {
    return res.status(429).json({ error: 'too_many_requests' });
  }

  // La validation vit dans lib/courses.js, avec ses tests : `website` finit en lien tapable sur la
  // page de la course, et une règle qui décide ce qui devient tapable mérite d'être vérifiable
  // sans serveur.
  const { erreur, course } = nettoyerCourse(req.body);
  if (erreur) return res.status(400).json({ error: erreur });

  // La modération, elle, reste ici : elle n'est pas une question de forme.
  if (containsObjectionableContent(course.name)) {
    return res.status(422).json({ error: 'objectionable_content' });
  }
  if (course.city && containsObjectionableContent(course.city)) {
    return res.status(422).json({ error: 'objectionable_content' });
  }

  const { rows } = await sql`
    INSERT INTO races (name, name_key, city, race_date, distance_km, elevation_gain_m, discipline, website, created_by)
    VALUES (${course.name}, ${course.nameKey}, ${course.city}, ${course.raceDate},
            ${course.distanceKm}, ${course.elevationGainM}, ${course.discipline}, ${course.website}, ${userId})
    ON CONFLICT (name_key, race_date) DO NOTHING
    RETURNING id, name, city, to_char(race_date, 'YYYY-MM-DD') AS race_date, distance_km, elevation_gain_m, discipline, website
  `;
  if (rows.length > 0) {
    return res.status(201).json({ race: mapRace({ ...rows[0], follower_count: 0 }), created: true });
  }

  // Elle existait déjà : on rend l'existante. Voir le commentaire en tête de ce handler.
  const { rows: deja } = await sql`
    SELECT r.id, r.name, r.city, to_char(r.race_date, 'YYYY-MM-DD') AS race_date, r.distance_km, r.elevation_gain_m, r.discipline, r.website,
           (SELECT COUNT(*)::int FROM race_followers f WHERE f.race_id = r.id) AS follower_count
    FROM races r WHERE r.name_key = ${course.nameKey} AND r.race_date = ${course.raceDate}
  `;
  if (deja.length === 0) return res.status(500).json({ error: 'could_not_create' });
  res.status(200).json({ race: mapRace(deja[0]), created: false });
}

// --- Suivre une course ---------------------------------------------------------------------------

// `sharesTraining` est un opt-in EXPLICITE, faux par défaut (voir db/schema.sql). Montrer à des
// inconnus où quelqu'un en est de son entraînement n'est pas la même chose que lui montrer qu'il
// court la même course.
async function handleFollow(req, res, userId) {
  const { raceId, targetChrono, targetPaceSecPerKm, sharesTraining, lookingForPartner } = req.body || {};
  if (!isUuid(raceId)) return res.status(400).json({ error: 'bad_request' });

  const { rows: course } = await sql`SELECT id FROM races WHERE id = ${raceId} AND race_date >= CURRENT_DATE`;
  if (course.length === 0) return res.status(404).json({ error: 'not_found' });

  const chrono = typeof targetChrono === 'string' && targetChrono.trim()
    ? targetChrono.trim().slice(0, 20) : null;
  // L'allure vient de l'app, qui sait déjà convertir un chrono et une distance en secondes par
  // kilomètre (`PaceModel`). Bornée ici parce qu'une valeur aberrante fausserait tous les
  // appariements de la course, pas seulement celui de son auteur.
  const allure = Number.isInteger(targetPaceSecPerKm)
    && targetPaceSecPerKm >= 120 && targetPaceSecPerKm <= 1200
    ? targetPaceSecPerKm : null;

  await sql`
    INSERT INTO race_followers (race_id, user_id, target_chrono, target_pace_sec_per_km, shares_training, looking_for_partner)
    VALUES (${raceId}, ${userId}, ${chrono}, ${allure}, ${sharesTraining === true}, ${lookingForPartner === true})
    ON CONFLICT (race_id, user_id) DO UPDATE SET
      target_chrono = EXCLUDED.target_chrono,
      target_pace_sec_per_km = EXCLUDED.target_pace_sec_per_km,
      shares_training = EXCLUDED.shares_training,
      looking_for_partner = EXCLUDED.looking_for_partner
  `;
  res.status(200).json({ ok: true });
}

async function handleUnfollow(req, res, userId) {
  const { raceId } = req.body || {};
  if (!isUuid(raceId)) return res.status(400).json({ error: 'bad_request' });
  await sql`DELETE FROM race_followers WHERE race_id = ${raceId} AND user_id = ${userId}`;
  res.status(200).json({ ok: true });
}

// --- La page elle-même ---------------------------------------------------------------------------

// TOUT L'ÉCRAN EN UNE REQUÊTE.
//
// Même parti pris que `clubs/mine` : une page de course affiche la course, qui la prépare, qui
// cherche quelqu'un à son allure et ce qui s'y dit. Cinq allers-retours pour un écran qu'on ouvre
// en marchant vers le métro, ce sont cinq occasions de ne rien voir.
//
// CE QUI N'EN SORT PAS. Le volume d'entraînement de quelqu'un qui n'a pas coché `shares_training`.
// Pas « masqué par le client » : jamais lu par la requête. Une donnée qu'on ne renvoie pas est la
// seule qui ne puisse pas fuir par un écran qu'on n'avait pas prévu.
async function handlePage(req, res, userId) {
  const raceId = typeof req.query.raceId === 'string' ? req.query.raceId : '';
  if (!isUuid(raceId)) return res.status(400).json({ error: 'bad_request' });

  const { rows: courseRows } = await sql`
    SELECT r.id, r.name, r.city, to_char(r.race_date, 'YYYY-MM-DD') AS race_date, r.distance_km, r.elevation_gain_m, r.discipline, r.website,
           (SELECT COUNT(*)::int FROM race_followers f WHERE f.race_id = r.id) AS follower_count
    FROM races r WHERE r.id = ${raceId}
  `;
  if (courseRows.length === 0) return res.status(404).json({ error: 'not_found' });

  const { rows: moi } = await sql`
    SELECT target_chrono, target_pace_sec_per_km, shares_training, looking_for_partner
    FROM race_followers WHERE race_id = ${raceId} AND user_id = ${userId}
  `;
  const monAllure = moi[0]?.target_pace_sec_per_km ?? null;

  // CELLES ET CEUX QUI PRÉPARENT LA COURSE.
  //
  // Le volume des quatre dernières semaines n'est calculé que pour qui l'a autorisé — le
  // `CASE WHEN` est à l'intérieur de la requête, donc la somme n'est même pas faite pour les
  // autres. Quatre semaines parce que c'est la fenêtre sur laquelle une préparation se lit : une
  // seule semaine ne dit rien, trois mois ne disent plus où l'on en est maintenant.
  const { rows: coureurs } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.avatar_data, u.avatar_url, u.is_private,
           f.target_chrono, f.target_pace_sec_per_km, f.shares_training, f.looking_for_partner,
           CASE WHEN f.shares_training THEN (
             SELECT COALESCE(SUM(a.distance_km), 0) FROM activities a
             WHERE a.user_id = u.id AND a.type = 'run'
               AND a.created_at >= now() - interval '28 days'
           ) END AS km_4_semaines,
           CASE WHEN f.shares_training THEN (
             SELECT COUNT(*)::int FROM activities a
             WHERE a.user_id = u.id AND a.type = 'run'
               AND a.created_at >= now() - interval '28 days'
           ) END AS sorties_4_semaines,
           fo.status AS follow_status
    FROM race_followers f
    JOIN users u ON u.id = f.user_id
    LEFT JOIN follows fo ON fo.follower_id = ${userId} AND fo.followee_id = u.id
    WHERE f.race_id = ${raceId}
      AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
      AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
    ORDER BY
      -- Celles et ceux qui cherchent quelqu'un d'abord : c'est la seule population de cette
      -- liste qui attend quelque chose de quelqu'un.
      f.looking_for_partner DESC,
      -- Puis par proximité d'allure avec la mienne, quand je l'ai donnée. Sans elle, par nom :
      -- un ordre arbitraire ferait croire à un classement.
      CASE WHEN ${monAllure}::int IS NULL OR f.target_pace_sec_per_km IS NULL THEN NULL
           ELSE abs(f.target_pace_sec_per_km - ${monAllure}::int) END ASC NULLS LAST,
      u.name ASC
    LIMIT 100
  `;

  // Le fil. Les messages de premier niveau d'abord, leurs réponses rattachées côté client —
  // une page de course a des dizaines de messages, pas des milliers, et deux listes à plat
  // coûtent moins qu'une requête récursive.
  const { rows: messages } = await sql`
    SELECT p.id, p.parent_id, p.kind, p.text, p.closed_at, p.created_at,
           (p.user_id = ${userId}) AS is_mine,
           (SELECT COUNT(*)::int FROM race_post_kudos k WHERE k.post_id = p.id) AS kudos,
           EXISTS(SELECT 1 FROM race_post_kudos k WHERE k.post_id = p.id AND k.user_id = ${userId}) AS kudoed_by_me,
           u.id AS author_id, u.name AS author_name, u.last_name AS author_last_name,
           u.username AS author_username, u.avatar_data, u.avatar_url
    FROM race_posts p
    JOIN users u ON u.id = p.user_id
    WHERE p.race_id = ${raceId}
      AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = ${userId})
      AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = ${userId})
    ORDER BY p.created_at ASC
    LIMIT 300
  `;

  res.status(200).json({
    race: mapRace(courseRows[0]),
    me: moi.length === 0 ? null : {
      targetChrono: moi[0].target_chrono || null,
      targetPaceSecPerKm: moi[0].target_pace_sec_per_km,
      sharesTraining: moi[0].shares_training,
      lookingForPartner: moi[0].looking_for_partner,
    },
    runners: coureurs.map((row) => ({
      id: row.id,
      name: row.name,
      lastName: row.last_name || null,
      username: row.username || null,
      avatarBase64: row.avatar_data || null,
      avatarUrl: row.avatar_url || null,
      isPrivate: row.is_private,
      followStatus: row.follow_status || null,
      targetChrono: row.target_chrono || null,
      targetPaceSecPerKm: row.target_pace_sec_per_km,
      lookingForPartner: row.looking_for_partner,
      // null = n'a pas autorisé le partage. Différent de 0, qui veut dire « n'a rien couru ».
      km4Weeks: row.km_4_semaines === null || row.km_4_semaines === undefined
        ? null : Number(row.km_4_semaines),
      runs4Weeks: row.sorties_4_semaines === null || row.sorties_4_semaines === undefined
        ? null : Number(row.sorties_4_semaines),
    })),
    posts: messages.map((row) => ({
      id: row.id,
      parentId: row.parent_id || null,
      kind: row.kind,
      text: row.text,
      closed: row.closed_at !== null,
      // Dit par le serveur et non déduit côté app : « marquer comme réglé » n'est proposé qu'à
      // l'auteur, et l'app n'a aucune raison de porter son propre identifiant pour le savoir.
      isMine: row.is_mine === true,
      kudos: row.kudos,
      kudoedByMe: row.kudoed_by_me === true,
      createdAt: row.created_at,
      author: {
        id: row.author_id,
        name: row.author_name,
        lastName: row.author_last_name || null,
        username: row.author_username || null,
        avatarBase64: row.avatar_data || null,
        avatarUrl: row.avatar_url || null,
        isPrivate: false,
      },
    })),
  });
}

// --- Le fil ---------------------------------------------------------------------------------------

async function handlePost(req, res, userId) {
  if (!(await underDailyCap('racePost:' + userId, 60))) {
    return res.status(429).json({ error: 'too_many_requests' });
  }

  const { raceId, kind, text, parentId } = req.body || {};
  if (!isUuid(raceId)) return res.status(400).json({ error: 'bad_request' });

  const propre = typeof text === 'string' ? text.trim().slice(0, LONGUEUR_MESSAGE) : '';
  if (!propre) return res.status(400).json({ error: 'bad_request' });
  if (containsObjectionableContent(propre)) return res.status(422).json({ error: 'objectionable_content' });

  const genre = GENRES.includes(kind) ? kind : 'message';

  // Une réponse appartient au même fil que le message auquel elle répond, et une réponse de
  // réponse n'existe pas : deux niveaux suffisent à une conversation de page, et au-delà
  // personne ne sait plus à qui l'on parle.
  let parent = null;
  if (parentId !== undefined && parentId !== null) {
    if (!isUuid(parentId)) return res.status(400).json({ error: 'bad_request' });
    const { rows } = await sql`
      SELECT id FROM race_posts WHERE id = ${parentId} AND race_id = ${raceId} AND parent_id IS NULL
    `;
    if (rows.length === 0) return res.status(404).json({ error: 'not_found' });
    parent = parentId;
  }

  const { rows: course } = await sql`SELECT id FROM races WHERE id = ${raceId} AND race_date >= CURRENT_DATE`;
  if (course.length === 0) return res.status(404).json({ error: 'not_found' });

  const { rows } = await sql`
    INSERT INTO race_posts (race_id, user_id, parent_id, kind, text)
    VALUES (${raceId}, ${userId}, ${parent}, ${parent ? 'message' : genre}, ${propre})
    RETURNING id, created_at
  `;
  res.status(201).json({ id: rows[0].id, createdAt: rows[0].created_at });
}

// APPLAUDIR UN MESSAGE DU MUR.
//
// Un mur où l'on ne peut pas réagir est froid : quelqu'un qui écrit « je vise 3h30, quelqu'un sur
// ce rythme ? » et ne reçoit rien ne saura jamais si personne ne l'a lu, ou si personne n'est au
// même rythme. L'applaudissement est la réponse la moins coûteuse qui dise « lu, et oui ».
//
// Une BASCULE, comme les applaudissements d'une sortie : le même appel met et retire. Deux routes
// pour un interrupteur demanderaient au client de savoir dans quel état il se trouve, et il se
// trompe dès qu'un autre appareil a changé l'état entre-temps.
async function handleKudos(req, res, userId) {
  const { postId } = req.body || {};
  if (!isUuid(postId)) return res.status(400).json({ error: 'bad_request' });

  // Le message doit exister ET appartenir à une course que je peux voir. Sans cette jointure,
  // n'importe quel identifiant valide serait applaudissable.
  const { rows: existe } = await sql`
    SELECT p.id FROM race_posts p JOIN races r ON r.id = p.race_id WHERE p.id = ${postId}
  `;
  if (existe.length === 0) return res.status(404).json({ error: 'not_found' });

  const { rows: retire } = await sql`
    DELETE FROM race_post_kudos WHERE post_id = ${postId} AND user_id = ${userId} RETURNING post_id
  `;
  if (retire.length === 0) {
    await sql`
      INSERT INTO race_post_kudos (post_id, user_id) VALUES (${postId}, ${userId})
      ON CONFLICT DO NOTHING
    `;
  }

  const { rows: compte } = await sql`
    SELECT COUNT(*)::int AS n FROM race_post_kudos WHERE post_id = ${postId}
  `;
  // Le compte RÉEL est rendu, pas un « +1 » que le client appliquerait : deux personnes qui
  // applaudissent en même temps feraient sinon diverger les deux écrans jusqu'au rechargement.
  res.status(200).json({ kudoed: retire.length === 0, kudos: compte[0].n });
}

// Retirer son annonce — le dossard est vendu, le partenaire est trouvé. On marque, on ne supprime
// pas : les réponses sous une annonce effacée deviendraient des messages sans contexte.
async function handleClosePost(req, res, userId) {
  const { postId } = req.body || {};
  if (!isUuid(postId)) return res.status(400).json({ error: 'bad_request' });
  const { rows } = await sql`
    UPDATE race_posts SET closed_at = now()
    WHERE id = ${postId} AND user_id = ${userId} AND closed_at IS NULL
    RETURNING id
  `;
  if (rows.length === 0) return res.status(403).json({ error: 'forbidden' });
  res.status(200).json({ ok: true });
}
