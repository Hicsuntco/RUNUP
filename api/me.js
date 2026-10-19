// Bootstrap call after sign-in / on app launch — current user's identity, XP total, and which
// club (if any) they belong to.
const { sql } = require('../lib/db');
const { requireAuth } = require('../lib/auth');
const { withErrorHandling } = require('../lib/http');
const { estAdmin, listeConfiguree } = require('../lib/admin');

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).json({ error: 'method_not_allowed' });
  const userId = await requireAuth(req, res);
  if (!userId) return res.status(401).json({ error: 'unauthorized' });

  const { rows } = await sql`
    SELECT u.id, u.name, u.last_name, u.username, u.xp_total, u.email, cm.club_id
    FROM users u
    LEFT JOIN club_members cm ON cm.user_id = u.id
    WHERE u.id = ${userId}
  `;
  const row = rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });

  res.status(200).json({
    id: row.id,
    name: row.name,
    lastName: row.last_name || null,
    username: row.username || null,
    xpTotal: row.xp_total,
    clubId: row.club_id || null,
    // L'ADRESSE DU COMPTE, RENVOYÉE À CE COMPTE ET À LUI SEUL.
    //
    // Ce n'est pas une fuite : c'est sa propre adresse, et la route est derrière `requireAuth`.
    // Elle est là parce que l'app ne la connaît pas — elle ne la revoit jamais après
    // l'inscription — et parce que « Se connecter avec Apple » peut créer un compte sous un
    // `…@privaterelay.appleid.com` que personne ne devine. La fiche admin l'affiche pour qu'on
    // sache quelle adresse mettre dans `RUNUP_ADMIN_EMAILS`, au lieu d'essayer les trois qu'on
    // croit avoir. Voir `lib/admin.js`.
    email: row.email || null,
    isAdmin: estAdmin(row.email),
    // « Tu n'es pas dans la liste » et « il n'y a pas de liste » se ressemblent à l'écran et se
    // corrigent à deux endroits différents. Ce drapeau ne dit RIEN du contenu de la liste, juste
    // qu'elle existe.
    adminListConfigured: listeConfiguree(),
  });
});
