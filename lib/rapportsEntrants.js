// Les rapports de panne de l'app — premier parti, comme l'analytique, et pour la même raison
// (voir la table `events` dans db/schema.sql). Aucun SDK tiers nulle part dans RunUp.
//
// # POURQUOI CE N'EST PAS UN FICHIER SOUS `api/`, ALORS QUE C'EST UN ENDPOINT
//
// Vercel compte UN fichier sous `api/` = UNE fonction serverless, et le plan Hobby en autorise
// douze. Il y en avait douze. `api/crashes.js` a donc été le treizième, et il a fait échouer tout
// déploiement production avec « No more than 12 Serverless Functions » — exactement la panne que
// l'en-tête d'`api/account/[action].js` raconte, pour exactement la même raison, le jour où
// l'analytique a été ajoutée.
//
// Ce qui l'a établi : après avoir ramené le compte à douze, `/api/crashes` a répondu 200 en
// moins d'une minute — donc la réécriture, ce fichier ET la migration du schéma étaient tous
// arrivés d'un coup. Le déploiement entier était bloqué, pas une route.
//
// (Une première tentative de preuve était fausse et mérite d'être écrite : comparer le
// `privacy.html` servi par la production à celui du dépôt. Il rend un 404 — ce fichier est
// publié par GitHub Pages depuis `main`, pas par Vercel. La conclusion était juste, la mesure
// ne la soutenait pas.)
//
// D'où cette forme : le gestionnaire vit dans `lib/`, qui ne compte pour rien, et `api/events.js`
// l'appelle. `/api/crashes` reste l'URL publique grâce à une réécriture dans `vercel.json` — une
// réécriture n'est pas une fonction. `/api/events` n'est PAS réécrit et continue d'être servi par
// son propre fichier : la seule adresse qui dépend de la réécriture est la nouvelle, celle dont
// on n'a encore rien perdu si elle rate.
//
// # CE QUI PRODUIT CE QUE CET ENDPOINT REÇOIT
//
// Rien ici n'est écrit par un gestionnaire de signal. Le client s'abonne à MetricKit, iOS
// collecte la panne HORS du processus mort, et `RunUp/Services/Diagnostics.swift` renvoie ce
// qu'Apple lui donne au lancement suivant. Le pourquoi de ce choix — et les citations d'Apple qui
// le tranchent — est écrit en tête de ce fichier Swift : c'est une décision de client.
//
// Cinq genres arrivent, pas seulement les plantages : un gel, un dépassement de processeur, une
// écriture disque excessive et un lancement trop lent sont des pannes où l'app ne meurt pas, elle
// devient mauvaise. Ce sont exactement celles qu'un rapporteur de panne classique ne voit jamais,
// et c'est pourtant ce qu'une utilisatrice appelle « ça plante ».
//
// # TROIS CHOSES COPIÉES SUR api/events.js, DÉLIBÉRÉMENT
//
//   1. L'AUTHENTIFICATION EST FACULTATIVE. La majorité des gens n'ont pas de compte — toute l'app
//      marche sans — et une panne chez quelqu'un qui n'est pas connecté compte exactement autant.
//      Exiger un jeton ici jetterait la plus grande partie des pannes.
//   2. ÇA PREND UN LOT, pas un rapport. Le client tamponne sur disque et vide au lancement, parce
//      que le cas NORMAL d'un plantage est que l'app soit morte avant d'avoir pu poster.
//   3. UN GENRE INCONNU EST JETÉ LIGNE PAR LIGNE, jamais en 400 pour tout le lot. Une version
//      plus ancienne ou plus récente de l'app ne doit pas faire échouer la requête entière : le
//      client renverrait le même lot pour toujours et tout ce qu'il y a de bon derrière resterait
//      coincé. Les comptes reviennent dans la réponse pour qu'on puisse au moins le constater.
//
// Ce que cet endpoint accepte exactement est dans `lib/pannes.js`, seul et testé — une règle qui
// décide ce qui entre en base ne doit pas être dissoute au milieu d'une insertion SQL.
const { sql } = require('./db');
const { requireAuth } = require('./auth');
const { isUuid } = require('./http');
const { underDailyCap } = require('./rateLimit');
const { MAX_REPORTS_PER_BATCH, DAILY_BATCH_CAP, nettoyerRapport } = require('./pannes');

// Appelée par `api/events.js`, qui a déjà écarté tout ce qui n'est pas un POST et qui est déjà
// enveloppé dans `withErrorHandling` — une erreur inattendue ici rend donc un 500 propre sans
// fuir de trace d'exécution, comme partout ailleurs.
async function recevoirLesRapports(req, res) {
  // Facultatif à dessein (voir l'en-tête) — `null` est un appelant normal, pas un refus. Le
  // `.catch` compte : un hoquet de la base ou du JWKS pendant la vérification doit dégrader cet
  // appel en anonyme, jamais le faire tomber en 500. Perdre une panne parce que le rapport de
  // panne est tombé serait une petite catastrophe.
  const userId = await requireAuth(req, res).catch(() => null);

  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || 'unknown';
  const capKey = userId ? `crashes:u:${userId}` : `crashes:ip:${ip}`;
  if (!(await underDailyCap(capKey, DAILY_BATCH_CAP))) return res.status(429).json({ error: 'too_many_requests' });

  const { anonymousId, reports } = req.body || {};
  if (!Array.isArray(reports)) return res.status(400).json({ error: 'bad_request' });
  if (reports.length > MAX_REPORTS_PER_BATCH) return res.status(400).json({ error: 'payload_too_large' });

  const cleanAnonymousId = isUuid(anonymousId) ? anonymousId : null;

  const maintenant = Date.now();
  const lignes = [];
  let rejected = 0;
  for (const report of reports) {
    const ligne = nettoyerRapport(report, maintenant);
    if (!ligne) rejected++;
    else lignes.push(ligne);
  }

  await Promise.all(
    lignes.map((ligne) => sql`
      INSERT INTO crash_reports
        (user_id, anonymous_id, kind, app_version, app_build, os_version, device_type,
         is_testflight, note, payload, occurred_at)
      VALUES
        (${userId}, ${cleanAnonymousId}, ${ligne.kind}, ${ligne.appVersion}, ${ligne.appBuild},
         ${ligne.osVersion}, ${ligne.deviceType}, ${ligne.isTestflight}, ${ligne.note},
         ${ligne.payload}::jsonb, ${ligne.occurredAt})
    `)
  );

  // Élagage opportuniste, pas une tâche planifiée — même motif et même raison qu'api/events.js.
  // Cent quatre-vingts jours : au-delà, la version qui a planté n'est plus distribuée, le dSYM
  // qui permettrait de symboliser la pile n'est plus celui qu'on garde, et la ligne ne sert plus
  // qu'à faire du volume. Cette durée est aussi celle annoncée dans PRIVACY_POLICY.md ; les deux
  // doivent rester d'accord.
  if (Math.random() < 0.01) {
    sql`DELETE FROM crash_reports WHERE created_at < now() - interval '180 days'`.catch(() => {});
  }

  return res.status(200).json({ ok: true, accepted: lignes.length, rejected });
}

module.exports = { recevoirLesRapports };
