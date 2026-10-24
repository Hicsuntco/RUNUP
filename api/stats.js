// Le tableau de bord de la maison lit RUNUP par ici.
//
// ─── POURQUOI CET ENDPOINT EXISTE ──────────────────────────────────────────────────────────────
//
// Hukaia et RUNUP sont publiées par le même compte Apple, et le livre de comptes de la maison
// (app.hukaia.com/comptes) voyait donc les TÉLÉCHARGEMENTS de RUNUP — ils arrivent dans les mêmes
// rapports de ventes — et rien d'autre. Pas une ouverture, pas une course, pas un compte : tout
// le reste vit sur ce Postgres-ci, que rien là-bas ne sait lire.
//
// Charlotte, 24 octobre : « je veux un vrai Dashboard pour suivre les deux applications
// parfaitement, savoir comment elles fonctionnent, ce qui fonctionne et ce qui ne fonctionne
// pas ». D'où ce point de lecture : des AGRÉGATS, et rien d'autre.
//
// ─── CE QUI N'EN SORT JAMAIS ───────────────────────────────────────────────────────────────────
//
// Aucune ligne, aucun identifiant, aucune adresse, aucun nom. Que des comptages. La table
// `events` porte un `anonymous_id` par appareil et un `user_id` par compte : les faire sortir
// d'ici reviendrait à exporter le parcours de gens qui n'ont rien demandé, vers une autre base,
// pour afficher un chiffre qu'un COUNT() donne aussi bien.
//
// ─── LA PORTE ──────────────────────────────────────────────────────────────────────────────────
//
// Deux façons d'entrer, et aucune par défaut :
//
//   1. un jeton de service, posé dans RUNUP_STATS_TOKEN (Vercel → Settings → Environment
//      Variables). C'est ce que la collecte quotidienne de Hukaia utilise : une machine parle à
//      une machine, sans compte ni session ;
//   2. une session d'administrateur (les mêmes adresses que lib/admin.js), pour regarder depuis
//      un navigateur sans rien configurer.
//
// Variable non définie ET pas d'admin connecté : 401. Pas de repli, pas de valeur par défaut —
// même règle que la liste des admins, pour la même raison : « un droit qui s'accorde tout seul
// quand une configuration manque est la plus mauvaise des portes ».
const { sql } = require('../lib/db');
const { requireAuth } = require('../lib/auth');
const { withErrorHandling } = require('../lib/http');
const { estAdmin } = require('../lib/admin');
const { jetonValide } = require('../lib/statsJeton');

// La porte vit dans lib/statsJeton.js, et pas ici : une route a besoin d'un Postgres, les tests
// de ce dépôt n'en ont pas, et une porte qu'on ne peut pas éprouver finit par s'ouvrir toute
// seule un jour de refactor. Voir tests/statsJeton.test.js.
async function autorise(req, res) {
  if (jetonValide(req.headers.authorization, process.env.RUNUP_STATS_TOKEN)) return true;

  // Pas de jeton de service valable : reste la session d'un administrateur.
  const userId = await requireAuth(req, res);
  if (!userId) return false;
  const { rows } = await sql`SELECT email FROM users WHERE id = ${userId}`;
  return !!(rows[0] && estAdmin(rows[0].email));
}

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
  if (!(await autorise(req, res))) {
    if (!res.headersSent) res.status(401).json({ error: 'unauthorized' });
    return;
  }

  // La fenêtre, bornée des deux côtés : un `?jours=100000` ferait un balayage complet de la table
  // qui grossit le plus vite d'ici, pour un chiffre que personne ne regarde.
  const jours = Math.min(Math.max(parseInt(req.query.jours, 10) || 30, 1), 365);
  const depuis = new Date(Date.now() - jours * 86400000).toISOString();

  // Un seul aller-retour par famille de questions plutôt qu'un COUNT() par ligne du tableau de
  // bord : chaque requête de ce driver est un appel HTTP, et quinze appels séquentiels pour
  // quinze nombres rendraient cet endpoint plus lent que tout le reste de l'API réuni.
  const [comptes, usage, courses, clubs, entonnoir, parJour] = await Promise.all([
    sql`
      SELECT count(*)::int AS total,
             count(*) FILTER (WHERE created_at >= ${depuis})::int AS neufs,
             count(*) FILTER (WHERE last_seen_at >= ${depuis})::int AS actifs,
             -- Jamais revenu : vu pour la dernière fois dans les minutes de son inscription, ou
             -- jamais vu du tout. C'est le chiffre qui décide de tous les autres.
             count(*) FILTER (WHERE last_seen_at IS NULL
                                 OR last_seen_at <= created_at + interval '5 minutes')::int AS jamais_revenus
        FROM users`,
    sql`
      SELECT count(*) FILTER (WHERE name = 'app_opened')::int AS ouvertures,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'app_opened')::int AS appareils,
             count(*) FILTER (WHERE name = 'coach_message_sent')::int AS messages_coach,
             count(DISTINCT user_id) FILTER (WHERE name = 'coach_message_sent')::int AS gens_coach
        FROM events WHERE created_at >= ${depuis}`,
    sql`
      SELECT count(*) FILTER (WHERE type = 'run')::int AS courses,
             count(DISTINCT user_id) FILTER (WHERE type = 'run')::int AS coureurs,
             coalesce(sum(distance_km) FILTER (WHERE type = 'run'), 0)::float AS km
        FROM activities WHERE created_at >= ${depuis}`,
    sql`
      SELECT (SELECT count(*)::int FROM clubs) AS clubs,
             (SELECT count(*)::int FROM club_members) AS membres`,
    // L'entonnoir d'avant-compte, le seul endroit où RUNUP perd des gens sans jamais le savoir :
    // l'onboarding se termine entièrement sans se connecter, et la plupart ne se connectent
    // jamais. On compte des APPAREILS (anonymous_id), parce qu'il n'y a pas encore de compte.
    sql`
      SELECT count(DISTINCT anonymous_id) FILTER (WHERE name = 'onboarding_started')::int AS commences,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'onboarding_finished')::int AS finis,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'first_run_started')::int AS premiere_lancee,
             count(DISTINCT anonymous_id) FILTER (WHERE name = 'first_run_completed')::int AS premiere_finie
        FROM events WHERE created_at >= ${depuis}`,
    sql`
      SELECT created_at::date AS jour,
             count(*) FILTER (WHERE name = 'app_opened')::int AS ouvertures,
             count(DISTINCT anonymous_id)::int AS appareils
        FROM events WHERE created_at >= ${depuis}
       GROUP BY 1 ORDER BY 1`,
  ]);

  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).json({
    app: 'runup',
    jours,
    releve_le: new Date().toISOString(),
    comptes: comptes.rows[0],
    usage: usage.rows[0],
    courses: courses.rows[0],
    clubs: clubs.rows[0],
    entonnoir: entonnoir.rows[0],
    par_jour: parJour.rows,
  });
});
