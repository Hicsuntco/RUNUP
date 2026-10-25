#!/usr/bin/env node
// Écrit db/courses_semees.sql — les quelques grandes courses que l'app connaît d'avance.
//
// POURQUOI UN GÉNÉRATEUR ET PAS UN FICHIER SQL ÉCRIT À LA MAIN. Chaque course porte un `name_key`,
// le nom replié (accents, casse, traits d'union) sur lequel repose à la fois la recherche et
// l'index UNIQUE (name_key, race_date). Si la clé semée diffère d'un seul caractère de ce que
// `normaliser()` produirait, la course semée devient introuvable ET un doublon créé à la main
// pourra exister à côté d'elle. La clé n'est donc jamais tapée : elle est calculée par la même
// fonction que le serveur.
//
// CE QUI N'EST PAS SEMÉ. Seules les dates réellement annoncées par l'organisateur. Une date
// inventée serait pire qu'une course absente : les courses semées passent AVANT les autres dans
// la recherche (is_seeded DESC), donc elles ont l'air officielles — et quelqu'un construirait un
// plan d'entraînement de seize semaines dessus. UTMB 2027, Grand Raid de La Réunion 2027 et
// Marseille-Cassis 2027 n'y sont pas pour cette seule raison : au moment d'écrire, leur date
// n'était pas publiée.
//
// À REFAIRE CHAQUE ANNÉE. Les courses passées ne sont jamais rendues (api/races). Ce fichier est
// donc à relancer quand les éditions suivantes sont annoncées :
//   node db/semer_courses.js   puis coller db/courses_semees.sql dans la console Neon.
// Le INSERT est idempotent : le relancer deux fois ne crée rien en double.
const fs = require('fs');
const path = require('path');
const { normaliser } = require('../lib/recherche');
const { nettoyerCourse, DISCIPLINES } = require('../lib/courses');

// `distanceKm` et `elevationGainM` restent absents pour les événements à plusieurs formats
// (EcoTrail, Marathon du Mont-Blanc) : annoncer une distance quand il y en a six serait faux pour
// cinq personnes sur six, et l'app sait afficher une course sans distance.
//
// `website` aussi est souvent absent, et pour une raison plus sérieuse : l'app en fait un LIEN
// TAPABLE. Un lien officiel vaut mieux qu'une recherche ; un lien deviné vaut moins que rien. Le
// Marathon de Paris change d'organisateur en 2027 et Berlin change de partenaire-titre — leurs
// adresses actuelles peuvent cesser d'être les bonnes. Dans le doute, pas de lien.
const COURSES = [
  // --- France ---
  {
    name: 'Marathon des Alpes-Maritimes Nice-Cannes',
    city: 'Nice', raceDate: '2026-11-08', distanceKm: 42.195, discipline: 'run',
    website: 'https://www.marathon06.com',
  },
  {
    name: 'SaintéLyon',
    // La nuit du 28 au 29 novembre : le départ de Saint-Étienne est donné le 28 au soir.
    city: 'Saint-Étienne', raceDate: '2026-11-28', distanceKm: 78, elevationGainM: 2000,
    discipline: 'trail', website: 'https://www.saintelyon.com',
  },
  {
    name: 'Semi-Marathon de Paris',
    city: 'Paris', raceDate: '2027-03-07', distanceKm: 21.0975, discipline: 'run',
  },
  {
    name: 'EcoTrail Paris',
    // Plusieurs distances, du 10 km au 120 km, départ Rambouillet, arrivée pont d'Iéna.
    city: 'Paris', raceDate: '2027-03-20', discipline: 'trail',
  },
  {
    name: 'Marathon de Paris',
    // 50e édition, nouvel organisateur (Cadence), tirage au sort.
    city: 'Paris', raceDate: '2027-04-04', distanceKm: 42.195, discipline: 'run',
  },
  {
    name: 'Marathon du Mont-Blanc',
    // L'événement court du 24 au 27 juin ; le marathon lui-même est le dimanche.
    city: 'Chamonix', raceDate: '2027-06-27', discipline: 'trail',
    website: 'https://www.marathonmontblanc.fr',
  },
  // --- Ailleurs : l'app est en trois langues, et un dossard se cède aussi pour Berlin ---
  {
    name: 'TCS London Marathon',
    // Édition en deux jours, une seule fois : samedi 24 et dimanche 25 avril. Le dimanche est le
    // jour historique de la course.
    city: 'London', raceDate: '2027-04-25', distanceKm: 42.195, discipline: 'run',
    website: 'https://www.tcslondonmarathon.com',
  },
  {
    name: 'Generali Berlin Marathon',
    // Generali remplace BMW comme partenaire-titre à partir de 2027.
    city: 'Berlin', raceDate: '2027-09-26', distanceKm: 42.195, discipline: 'run',
  },
  {
    name: 'TCS New York City Marathon',
    // Toujours le premier dimanche de novembre.
    city: 'New York', raceDate: '2027-11-07', distanceKm: 42.195, discipline: 'run',
    website: 'https://www.nyrr.org',
  },
];

function litteral(valeur) {
  if (valeur === null || valeur === undefined) return 'NULL';
  if (typeof valeur === 'number') return String(valeur);
  // Une seule façon d'échapper une chaîne SQL, et elle s'applique aussi aux apostrophes des noms
  // de ville. Ce fichier est généré, pas concaténé depuis une entrée d'utilisateur.
  return "'" + valeur.replace(/'/g, "''") + "'";
}

const lignes = [];
for (const brute of COURSES) {
  // Même porte que le serveur : si une entrée de cette liste ne passerait pas `create`, elle ne
  // doit pas entrer par la porte de service.
  const { erreur, course } = nettoyerCourse(brute, '1970-01-01');
  if (erreur) throw new Error(`« ${brute.name} » refusée : ${erreur}`);
  if (course.nameKey !== normaliser(brute.name)) throw new Error('clé incohérente');
  if (!DISCIPLINES.includes(course.discipline)) throw new Error('discipline inconnue');
  if (brute.website && !course.website) throw new Error(`site refusé : ${brute.name}`);

  lignes.push('  (' + [
    litteral(course.name), litteral(course.nameKey), litteral(course.city),
    litteral(course.raceDate), litteral(course.distanceKm), litteral(course.elevationGainM),
    litteral(course.discipline), litteral(course.website),
  ].join(', ') + ')');
}

const sql = `-- GÉNÉRÉ PAR db/semer_courses.js — NE PAS MODIFIER À LA MAIN.
-- Relancer \`node db/semer_courses.js\` après avoir mis la liste à jour dans ce script.
--
-- Les ${COURSES.length} courses que l'app connaît d'avance. Tout le reste se crée depuis l'app, par les
-- coureurs eux-mêmes : une page de course n'a pas besoin d'un catalogue mondial pour servir, elle
-- a besoin que la course que TOI tu prépares existe.
--
-- \`created_by\` reste NULL : personne n'a créé ces pages, elles étaient là. \`is_seeded\` les fait
-- passer avant les saisies approximatives du même événement dans la recherche.
INSERT INTO races (name, name_key, city, race_date, distance_km, elevation_gain_m, discipline, website, created_by, is_seeded)
SELECT v.name, v.name_key, v.city, v.race_date::date, v.distance_km::numeric, v.elevation_gain_m::int,
       v.discipline, v.website, NULL, true
FROM (VALUES
${lignes.join(',\n')}
) AS v (name, name_key, city, race_date, distance_km, elevation_gain_m, discipline, website)
ON CONFLICT (name_key, race_date) DO NOTHING;
`;

const cible = path.join(__dirname, 'courses_semees.sql');
fs.writeFileSync(cible, sql, 'utf8');
process.stdout.write(`${COURSES.length} courses écrites dans ${cible}\n`);
