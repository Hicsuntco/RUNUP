// Ce qu'on accepte quand quelqu'un crée la page d'une course.
//
// CE QUE CE FICHIER PROTÈGE. Une course créée par un coureur porte un champ `website` que l'app
// affiche en LIEN TAPABLE à tous ceux qui suivront cette course. Un champ libre affiché est une
// chose ; un champ libre rendu tapable au doigt de quelqu'un d'autre en est une autre. La règle
// qui décide ce qui devient tapable est donc seule dans lib/courses.js, et testée ici — pas
// dissoute au milieu d'une insertion SQL où personne ne la relira.
//
// Le deuxième défaut qu'ils empêchent : un nom qui ne se replie sur rien. L'unicité d'une course
// tient à l'index UNIQUE (name_key, race_date). Si `name_key` peut être vide, toutes les courses
// faites de ponctuation entrent en collision entre elles, et la première gagne pour toujours.
const test = require('node:test');
const assert = require('node:assert');

const { DISCIPLINES, nettoyerCourse } = require('../lib/courses');

// Toutes les entrées de ces tests se situent par rapport à une date fixe, passée en second
// argument : un test qui dépendrait de la vraie date d'aujourd'hui finirait par échouer tout seul.
const JOUR = '2026-10-25';
const base = { name: 'Marathon de Paris', raceDate: '2027-04-11' };

function course(extra) {
  const r = nettoyerCourse({ ...base, ...extra }, JOUR);
  assert.strictEqual(r.erreur, undefined, 'refusée alors qu\'elle devait passer : ' + r.erreur);
  return r.course;
}

function refus(extra) {
  const r = nettoyerCourse({ ...base, ...extra }, JOUR);
  assert.ok(r.erreur, 'acceptée alors qu\'elle devait être refusée');
  assert.strictEqual(r.course, undefined);
  return r.erreur;
}

// --- Le site, la raison d'être de ce fichier ----------------------------------------------------

test('UNE ADRESSE javascript: N\'EST JAMAIS RENDUE', () => {
  // Le cas qui justifie tout le reste.
  assert.strictEqual(course({ website: 'javascript:alert(1)' }).website, null);
  assert.strictEqual(course({ website: 'JavaScript:alert(1)' }).website, null);
  assert.strictEqual(course({ website: '  javascript:alert(1)  ' }).website, null);
});

test('data: et file: non plus', () => {
  assert.strictEqual(course({ website: 'data:text/html,<script>0</script>' }).website, null);
  assert.strictEqual(course({ website: 'file:///etc/passwd' }).website, null);
});

test('une adresse sans schéma est refusée plutôt que complétée', () => {
  // Compléter en `https://` serait deviner. Une adresse qu'on devine n'est pas celle qu'on
  // propose au doigt de quelqu'un.
  assert.strictEqual(course({ website: 'schneiderelectricmarathondeparis.com' }).website, null);
});

test('une vraie adresse passe, http comme https', () => {
  assert.strictEqual(
    course({ website: 'https://www.schneiderelectricmarathondeparis.com' }).website,
    'https://www.schneiderelectricmarathondeparis.com'
  );
  assert.strictEqual(course({ website: 'http://utmb.world/fr' }).website, 'http://utmb.world/fr');
});

test('UNE ADRESSE MAL COLLÉE NE BLOQUE PAS LA CRÉATION DE LA COURSE', () => {
  // Le site est facultatif. Punir quelqu'un d'une course entière pour un copier-coller raté
  // d'un champ optionnel serait disproportionné : on garde la course, on jette l'adresse.
  const c = course({ website: 'pas une adresse du tout' });
  assert.strictEqual(c.website, null);
  assert.strictEqual(c.name, 'Marathon de Paris');
});

test('une adresse trop longue est coupée, pas refusée', () => {
  const longue = 'https://exemple.fr/' + 'a'.repeat(500);
  assert.strictEqual(course({ website: longue }).website.length, 300);
});

test('une adresse avec un espace ou un chevron est refusée', () => {
  // L'espace et `<` sont ce par quoi on sort d'un attribut.
  assert.strictEqual(course({ website: 'https://exemple.fr/a b' }).website, null);
  assert.strictEqual(course({ website: 'https://exemple.fr/"><img' }).website, null);
});

// --- La date ------------------------------------------------------------------------------------

test('LE 31 FÉVRIER EST REFUSÉ', () => {
  // Il passe la forme AAAA-MM-JJ et n'existe pas. Postgres refuserait la ligne avec une erreur
  // 500 ; ici c'est un 400 qui dit laquelle.
  assert.strictEqual(refus({ raceDate: '2027-02-31' }), 'bad_date');
  assert.strictEqual(refus({ raceDate: '2027-13-01' }), 'bad_date');
  assert.strictEqual(refus({ raceDate: '2027-04-00' }), 'bad_date');
});

test('le 29 février d\'une année bissextile passe', () => {
  assert.strictEqual(course({ raceDate: '2028-02-29' }).raceDate, '2028-02-29');
});

test('le 29 février d\'une année non bissextile est refusé', () => {
  assert.strictEqual(refus({ raceDate: '2027-02-29' }), 'bad_date');
});

test('une date mal formée est refusée', () => {
  assert.strictEqual(refus({ raceDate: '11/04/2027' }), 'bad_date');
  assert.strictEqual(refus({ raceDate: '2027-4-11' }), 'bad_date');
  assert.strictEqual(refus({ raceDate: '' }), 'bad_date');
  assert.strictEqual(refus({ raceDate: undefined }), 'bad_date');
  assert.strictEqual(refus({ raceDate: 20270411 }), 'bad_date');
});

test('une date passée est refusée, celle du jour acceptée', () => {
  // La recherche ne rend pas les courses passées : en créer une ne ferait qu'ajouter une ligne
  // que personne ne reverrait jamais.
  assert.strictEqual(refus({ raceDate: '2026-10-23' }), 'past_date');
  assert.strictEqual(refus({ raceDate: '2025-10-25' }), 'past_date');
  assert.strictEqual(course({ raceDate: JOUR }).raceDate, JOUR);
});

test('LA VEILLE PASSE : LE FUSEAU DU TÉLÉPHONE N\'EST PAS CELUI DU SERVEUR', () => {
  // Le jour vient du sélecteur de date de l'app. « Aujourd'hui » à Los Angeles est encore hier à
  // Paris pendant huit heures : refuser au jour près ferait échouer la création d'une course du
  // jour pour tout l'ouest du monde.
  assert.strictEqual(course({ raceDate: '2026-10-24' }).raceDate, '2026-10-24');
});

test('la veille du 1er mars se calcule juste, même une année bissextile', () => {
  // `setUTCDate(0)` sur mars donne le 29 février 2028 et le 28 février 2027.
  assert.strictEqual(nettoyerCourse({ ...base, raceDate: '2028-02-29' }, '2028-03-01').erreur, undefined);
  assert.strictEqual(nettoyerCourse({ ...base, raceDate: '2028-02-28' }, '2028-03-01').erreur, 'past_date');
});

test('un horodatage complet est accepté par sa date', () => {
  // L'app envoie parfois un ISO 8601 entier.
  assert.strictEqual(course({ raceDate: '2027-04-11T08:00:00Z' }).raceDate, '2027-04-11');
});

// --- Le nom -------------------------------------------------------------------------------------

test('un nom vide ou absent est refusé', () => {
  assert.strictEqual(refus({ name: '' }), 'bad_request');
  assert.strictEqual(refus({ name: '   ' }), 'bad_request');
  assert.strictEqual(refus({ name: undefined }), 'bad_request');
  assert.strictEqual(refus({ name: 42 }), 'bad_request');
});

test('UN NOM QUI NE SE REPLIE SUR RIEN EST REFUSÉ', () => {
  // `name_key` sert la recherche ET l'index UNIQUE. Vide, toutes ces courses-là se percuteraient
  // entre elles et la première gagnerait pour toujours.
  assert.strictEqual(refus({ name: '...' }), 'bad_request');
  assert.strictEqual(refus({ name: '---' }), 'bad_request');
});

test('le nom garde ses accents et sa casse, la clé non', () => {
  const c = course({ name: '  Grand Raid de la Réunion  ' });
  assert.strictEqual(c.name, 'Grand Raid de la Réunion');
  assert.strictEqual(c.nameKey, 'grand raid de la reunion');
});

test('un nom trop long est coupé', () => {
  assert.strictEqual(course({ name: 'A'.repeat(300) }).name.length, 120);
});

// --- Les mesures --------------------------------------------------------------------------------

test('une distance plausible est gardée, une aberrante effacée', () => {
  assert.strictEqual(course({ distanceKm: 42.195 }).distanceKm, 42.195);
  assert.strictEqual(course({ distanceKm: '42.195' }).distanceKm, 42.195);
  assert.strictEqual(course({ distanceKm: 0 }).distanceKm, null);
  assert.strictEqual(course({ distanceKm: -10 }).distanceKm, null);
  assert.strictEqual(course({ distanceKm: 99999 }).distanceKm, null);
  assert.strictEqual(course({ distanceKm: 'quarante-deux' }).distanceKm, null);
  assert.strictEqual(course({ distanceKm: undefined }).distanceKm, null);
});

test('un dénivelé non entier ou aberrant est effacé, pas arrondi', () => {
  assert.strictEqual(course({ elevationGainM: 10000 }).elevationGainM, 10000);
  assert.strictEqual(course({ elevationGainM: 0 }).elevationGainM, 0);
  assert.strictEqual(course({ elevationGainM: 1234.5 }).elevationGainM, null);
  assert.strictEqual(course({ elevationGainM: -5 }).elevationGainM, null);
  assert.strictEqual(course({ elevationGainM: 999999 }).elevationGainM, null);
});

// --- La discipline ------------------------------------------------------------------------------

test('une discipline inconnue retombe sur la course à pied', () => {
  // La colonne est NOT NULL et l'app n'a pas de pictogramme pour « quidditch ».
  assert.strictEqual(course({ discipline: 'quidditch' }).discipline, 'run');
  assert.strictEqual(course({ discipline: '' }).discipline, 'run');
  assert.strictEqual(course({ discipline: undefined }).discipline, 'run');
});

test('chacune des disciplines de l\'app est acceptée telle quelle', () => {
  for (const d of DISCIPLINES) {
    assert.strictEqual(course({ discipline: d }).discipline, d);
  }
});

// --- La ville -----------------------------------------------------------------------------------

test('la ville est facultative et nettoyée', () => {
  assert.strictEqual(course({ city: '  Paris ' }).city, 'Paris');
  assert.strictEqual(course({ city: '' }).city, null);
  assert.strictEqual(course({ city: undefined }).city, null);
  assert.strictEqual(course({ city: 'V'.repeat(200) }).city.length, 80);
});

// --- L'entrée elle-même -------------------------------------------------------------------------

test('une entrée absente ne fait pas tomber la fonction', () => {
  // Un corps de requête vide arrive pour de vrai. Il doit donner un 400, pas une exception.
  assert.strictEqual(nettoyerCourse(undefined, JOUR).erreur, 'bad_request');
  assert.strictEqual(nettoyerCourse(null, JOUR).erreur, 'bad_request');
  assert.strictEqual(nettoyerCourse({}, JOUR).erreur, 'bad_request');
});

test('sans jour donné, la fonction prend aujourd\'hui sans se plaindre', () => {
  // Le serveur l'appelle sans second argument.
  const dansDixAns = new Date(Date.now() + 10 * 365 * 86400000).toISOString().slice(0, 10);
  assert.strictEqual(nettoyerCourse({ ...base, raceDate: dansDixAns }).erreur, undefined);
  assert.strictEqual(nettoyerCourse({ ...base, raceDate: '2000-01-01' }).erreur, 'past_date');
});
