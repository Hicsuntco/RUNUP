#!/usr/bin/env node
// Applique `db/schema.sql` à la base, AVANT que le code qui en dépend ne soit déployé.
//
// # LE DÉFAUT QUE CE SCRIPT FERME
//
// `db/schema.sql` ne s'exécutait jamais tout seul : il décrivait l'état voulu, et quelqu'un le
// collait à la main dans la console Neon. Tant que les deux allaient ensemble, ça tenait. Le jour
// où une requête déployée a lu une colonne qui n'existait pas encore, Postgres a refusé la requête
// ENTIÈRE — pas seulement ce champ — et les trois fils de l'app ont rendu une erreur au lieu de
// s'afficher. Les tests étaient verts, le déploiement était vert, et le contrôle de déploiement ne
// pouvait rien voir : il vérifie qu'une route ne rend pas 404, et une route sans jeton répond 401
// avant même de toucher la base.
//
// # POURQUOI PENDANT LA CONSTRUCTION, ET PAS AU DÉMARRAGE DU SERVEUR
//
// La première idée était de faire appliquer le schéma par le serveur lui-même, à sa première
// requête. Le pilote Neon parle en HTTP : chaque requête est sa propre connexion, sans session.
// Il n'y a donc PAS de verrou consultatif possible (`pg_advisory_lock` serait relâché aussitôt),
// et deux démarrages à froid simultanés appliqueraient le fichier en même temps — ce que Postgres
// tolère mal même avec des `IF NOT EXISTS`. Il aurait fallu reconstruire un verrou à partir
// d'insertions atomiques, dans le chemin critique de la première requête de chaque instance.
//
// Pendant la construction, il n'y a qu'UN processus, aucune concurrence, et surtout : si ce script
// échoue, la construction échoue, donc RIEN n'est déployé et l'ancienne version continue de
// servir. « Déployé » implique « migré », par construction et non par discipline.
//
// # CE QU'IL NE FAIT PAS
//
// Il ne supprime rien, ne renomme rien, ne touche à aucune donnée. `db/schema.sql` n'est fait que
// d'instructions idempotentes (`IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, trois blocs `DO` qui
// vérifient avant d'agir) — c'est ce qui permet de le rejouer à chaque déploiement sans y penser.
const fs = require('fs');
const path = require('path');
const { neon } = require('@neondatabase/serverless');
const { decouper } = require('../lib/decoupeSQL');

const RACINE = path.resolve(__dirname, '..');
const FICHIER = path.join(RACINE, 'db/schema.sql');

// Le hachage du fichier, pour ne pas rejouer quatre-vingts instructions à chaque déploiement quand
// rien n'a changé. Le rejeu serait sans effet, mais il coûte autant d'allers-retours HTTP.
function empreinte(texte) {
  const valeur = require('crypto').createHash('sha256').update(texte).digest('hex');
  // Interpolée dans le SQL plus bas — faute de pouvoir paramétrer avec la voie de repli. Le
  // hachage est hexadécimal par construction ; l'affirmer ici plutôt que l'espérer.
  if (!/^[0-9a-f]{64}$/.test(valeur)) throw new Error('empreinte inattendue');
  return valeur;
}

/// Neon expose `sql.query(texte)` pour une instruction construite ailleurs. Au cas où cette API
/// changerait de nom, on retombe sur la forme balisée en fabriquant un littéral de gabarit — un
/// tableau qui porte son propre `raw`, ce qu'attend toute fonction balisée.
function executeur(client) {
  if (typeof client.query === 'function') {
    return (texte) => client.query(texte);
  }
  return (texte) => {
    const morceaux = [texte];
    morceaux.raw = [texte];
    return client(morceaux);
  };
}

async function main() {
  const url = process.env.DATABASE_URL || process.env.POSTGRES_URL;
  if (!url) {
    console.error('');
    console.error('DATABASE_URL absente : le schéma ne peut pas être appliqué.');
    console.error('');
    console.error("Sur Vercel, elle est injectée par l'intégration Neon (Storage → Neon) et doit");
    console.error("être disponible à la CONSTRUCTION, pas seulement à l'exécution. Dans les");
    console.error('réglages du projet → Environment Variables, vérifie que la variable est cochée');
    console.error('pour « Build » en plus de « Runtime ».');
    console.error('');
    console.error('Échouer ici est VOLONTAIRE : construire sans migrer redéploierait exactement le');
    console.error("défaut que ce script existe pour fermer. L'ancienne version continue de servir.");
    return 1;
  }

  const source = fs.readFileSync(FICHIER, 'utf8');
  const instructions = decouper(source);
  const hachage = empreinte(source);
  const client = neon(url);
  const executer = executeur(client);

  console.log(`Schéma : ${instructions.length} instructions, empreinte ${hachage.slice(0, 12)}`);

  // Le registre d'abord, et à la main : il ne peut pas se décrire lui-même dans le fichier qu'il
  // sert à suivre.
  await executer(`
    CREATE TABLE IF NOT EXISTS schema_versions (
      empreinte TEXT PRIMARY KEY,
      applique_le TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  const deja = await executer(
    `SELECT 1 FROM schema_versions WHERE empreinte = '${hachage}'`
  );
  const lignes = Array.isArray(deja) ? deja : (deja && deja.rows) || [];
  if (lignes.length > 0) {
    console.log('Déjà appliqué — rien à faire.');
    return 0;
  }

  const debut = Date.now();
  for (let i = 0; i < instructions.length; i += 1) {
    const instruction = instructions[i].trim();
    try {
      await executer(instruction);
    } catch (erreur) {
      // L'INSTRUCTION FAUTIVE EST NOMMÉE. Sans ça, « syntax error at or near » sur
      // quatre-vingts instructions ne dit pas laquelle, et il faut bissecter à la main.
      console.error(`\nInstruction ${i + 1}/${instructions.length} refusée :\n`);
      console.error(instruction.split('\n').slice(0, 12).join('\n'));
      console.error(`\n→ ${erreur.message}`);
      return 1;
    }
  }

  await executer(
    `INSERT INTO schema_versions (empreinte) VALUES ('${hachage}') ON CONFLICT DO NOTHING`
  );
  console.log(`Appliqué en ${((Date.now() - debut) / 1000).toFixed(1)} s.`);
  return 0;
}

main()
  .then((code) => process.exit(code))
  .catch((erreur) => {
    console.error(erreur);
    process.exit(1);
  });
