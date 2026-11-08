// Ce qu'on accepte d'un rapport de panne, et sous quelle forme il entre en base.
//
// # POURQUOI CES RÈGLES SONT SEULES ICI
//
// Même raison que `lib/courses.js` : une règle qui décide ce qui entre en base ne doit pas être
// dissoute au milieu d'une insertion SQL où personne ne la relira. Celles-ci bornent ce qu'un
// client — y compris un client trafiqué, puisque cet endpoint n'exige pas de jeton — peut écrire
// dans `crash_reports`, et chacune a un cas de test dans tests/crashes.test.js.
//
// # LE VOCABULAIRE, ET CE QU'IL EMPÊCHE
//
// `KNOWN_KINDS` doit concorder avec `Diagnostics.Genre` côté Swift, et
// `ci_scripts/check_pannes.py` compare les deux listes dans les DEUX SENS. Ce n'est pas une
// précaution de principe : la même duplication entre `Analytics.EventName` et `KNOWN_EVENTS` a
// jeté onze événements en silence pendant des mois, avec un 200 OK à chaque envoi. Ici ce serait
// pire, parce qu'un rapport de panne n'arrive que quand ça va mal : il n'y a pas de volume
// quotidien dont la chute sauterait aux yeux, et une table vide ressemble à une app qui ne
// plante pas.
const KNOWN_KINDS = new Set([
  'crash',
  'hang',
  'cpu_exception',
  'disk_write_exception',
  'app_launch',
]);

// Un appareil qui plante en boucle est le cas qu'on veut VOIR, pas celui qu'on veut laisser
// écrire sans fin. Cinq rapports par lot et vingt lots par jour laissent passer cent pannes
// quotidiennes d'un même appareil : au-delà, la centième dit déjà tout ce que dirait la millième.
const MAX_REPORTS_PER_BATCH = 5;
const DAILY_BATCH_CAP = 20;
// La pile d'appels non symbolisée d'un plantage à cinquante fils fait des dizaines de
// kilo-octets. C'est la seule chose qui permette de symboliser la panne plus tard avec le dSYM,
// donc on la garde en entier ou pas du tout — le client applique le MÊME plafond et envoie la
// ligne sans sa charge plutôt que du JSON coupé au milieu, qui n'est plus du JSON.
const MAX_PAYLOAD_CHARS = 120000;
const MAX_NOTE_CHARS = 300;
// Version, build, version d'iOS, modèle d'appareil : des chaînes courtes par nature. Le plafond
// n'est pas là pour la place mais pour qu'un client trafiqué ne fasse pas de ces colonnes un
// champ de texte libre.
const MAX_FIELD_CHARS = 100;
// Un appareil hors ligne garde ses rapports jusqu'au prochain envoi réussi : un mois de retard
// est légitime. Au-delà, l'horloge de l'appareil est fausse, et l'heure du serveur — fausse de
// quelques jours au pire — vaut mieux qu'une date qui ment de dix ans. Mêmes bornes
// qu'api/events.js, pour les mêmes raisons.
const MAX_BACKDATE_MS = 30 * 24 * 3600 * 1000;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;

// Rend la ligne à insérer, ou `null` si le rapport n'est pas d'un genre connu — le SEUL motif de
// rejet complet. Tout le reste se dégrade champ par champ : un rapport dont la charge est abîmée
// perd sa pile d'appels et garde sa ligne, parce que « combien de plantages sur la 2.9 » reste
// une information sans la pile.
function nettoyerRapport(brut, maintenant) {
  if (!brut || !KNOWN_KINDS.has(brut.kind)) return null;
  return {
    kind: brut.kind,
    appVersion: texteCourt(brut.appVersion, MAX_FIELD_CHARS),
    appBuild: texteCourt(brut.appBuild, MAX_FIELD_CHARS),
    osVersion: texteCourt(brut.osVersion, MAX_FIELD_CHARS),
    deviceType: texteCourt(brut.deviceType, MAX_FIELD_CHARS),
    isTestflight: typeof brut.isTestflight === 'boolean' ? brut.isTestflight : null,
    note: texteCourt(brut.note, MAX_NOTE_CHARS),
    payload: chargeValide(brut.payload),
    occurredAt: dateDuClient(brut.occurredAt, maintenant),
  };
}

// Une chaîne non vide, bornée — ou `null`. Une colonne vide et une colonne nulle ne se filtrent
// pas pareil, et `NULL` est la vérité quand MetricKit n'a rien donné.
function texteCourt(brut, plafond) {
  if (typeof brut !== 'string') return null;
  const propre = brut.trim();
  if (!propre || propre.length > plafond) return null;
  return propre;
}

// La charge arrive en TEXTE et non en objet imbriqué, pour que ce soit ici — et pas au milieu du
// corps de la requête — qu'un JSON abîmé se refuse. Elle est reparsée puis resérialisée : ce
// n'est pas un aller-retour pour rien, c'est ce qui garantit que la colonne `jsonb` reçoit du
// JSON et que l'insertion ne tombe pas sur un texte malformé.
function chargeValide(brut) {
  if (typeof brut !== 'string') return null;
  if (!brut || brut.length > MAX_PAYLOAD_CHARS) return null;
  try {
    const analyse = JSON.parse(brut);
    // Un scalaire est du JSON valide mais pas un rapport : `jsonb` l'accepterait, et aucune
    // requête ne saurait quoi en faire.
    if (!analyse || typeof analyse !== 'object') return null;
    return JSON.stringify(analyse);
  } catch {
    return null;
  }
}

// La date de la panne : celle du client si elle est plausible, l'heure du serveur sinon.
function dateDuClient(brut, maintenant) {
  if (typeof brut !== 'string') return new Date(maintenant).toISOString();
  const analyse = Date.parse(brut);
  if (Number.isNaN(analyse)) return new Date(maintenant).toISOString();
  if (analyse < maintenant - MAX_BACKDATE_MS || analyse > maintenant + MAX_CLOCK_SKEW_MS) {
    return new Date(maintenant).toISOString();
  }
  return new Date(analyse).toISOString();
}

module.exports = {
  KNOWN_KINDS,
  MAX_REPORTS_PER_BATCH,
  DAILY_BATCH_CAP,
  MAX_PAYLOAD_CHARS,
  MAX_NOTE_CHARS,
  MAX_FIELD_CHARS,
  nettoyerRapport,
};
