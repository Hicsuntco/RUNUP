// Ce qu'on accepte d'un rapport de panne.
//
// CE QUE CE FICHIER PROTÈGE. `api/crashes.js` n'exige PAS de jeton — délibérément : la majorité
// des gens n'ont pas de compte, et une panne chez quelqu'un qui n'est pas connecté compte autant
// que les autres. Cette décision est juste, et elle a un prix : tout ce qui arrive ici peut venir
// d'un client trafiqué. Les bornes de `lib/pannes.js` sont la seule chose qui sépare une table de
// diagnostics d'un champ de texte libre écrivable par n'importe qui.
//
// Le deuxième défaut qu'ils empêchent est plus retors, et c'est celui qui a motivé la forme de ce
// module : la DÉGRADATION. Un rapport dont la charge est abîmée doit perdre sa pile d'appels et
// garder sa ligne, parce que « combien de plantages sur la 2.9 » reste une information sans la
// pile. Un module qui refuserait tout le rapport ferait disparaître le plantage au lieu de la
// pile — exactement l'inverse de ce qu'on veut, et invisible, puisqu'une table de pannes vide
// ressemble à une app qui ne plante pas.
const test = require('node:test');
const assert = require('node:assert');

const {
  KNOWN_KINDS,
  MAX_PAYLOAD_CHARS,
  MAX_NOTE_CHARS,
  MAX_FIELD_CHARS,
  nettoyerRapport,
} = require('../lib/pannes');

// Toutes les dates de ces tests se situent par rapport à un instant fixe : un test qui
// dépendrait de la vraie heure finirait par échouer tout seul.
const MAINTENANT = Date.parse('2026-11-08T12:00:00.000Z');
const base = {
  kind: 'crash',
  appVersion: '2.9',
  appBuild: '412',
  osVersion: '18.1',
  deviceType: 'iPhone15,2',
  isTestflight: false,
  note: 'signal 11 / exception 1',
  payload: '{"callStackTree":{"callStacks":[]}}',
  occurredAt: '2026-11-08T11:58:30.000Z',
};

function ligne(extra) {
  const r = nettoyerRapport({ ...base, ...extra }, MAINTENANT);
  assert.ok(r, 'rejetée alors qu\'elle devait passer');
  return r;
}

function rejet(extra) {
  assert.strictEqual(nettoyerRapport({ ...base, ...extra }, MAINTENANT), null);
}

// --- Le vocabulaire : le SEUL motif de rejet complet --------------------------------------------

test('les cinq genres de MetricKit passent', () => {
  for (const kind of ['crash', 'hang', 'cpu_exception', 'disk_write_exception', 'app_launch']) {
    assert.strictEqual(ligne({ kind }).kind, kind);
  }
  assert.strictEqual(KNOWN_KINDS.size, 5);
});

test('un genre inconnu est rejeté, et c\'est le seul rejet complet', () => {
  rejet({ kind: 'segfault' });
  rejet({ kind: '' });
  rejet({ kind: null });
  rejet({ kind: 42 });
});

test('un rapport vide ou absent est rejeté sans lever', () => {
  assert.strictEqual(nettoyerRapport(null, MAINTENANT), null);
  assert.strictEqual(nettoyerRapport(undefined, MAINTENANT), null);
  assert.strictEqual(nettoyerRapport({}, MAINTENANT), null);
});

// --- LA DÉGRADATION, la raison d'être de ce fichier --------------------------------------------

test('UNE CHARGE ABÎMÉE COÛTE LA PILE, JAMAIS LA LIGNE', () => {
  // Le cas qui justifie tout le reste. Le plantage doit survivre à sa pile d'appels.
  const r = ligne({ payload: '{"callStackTree": [[[' });
  assert.strictEqual(r.payload, null);
  assert.strictEqual(r.kind, 'crash');
  assert.strictEqual(r.appBuild, '412');
});

test('une charge trop grosse coûte la pile, pas la ligne', () => {
  const enorme = JSON.stringify({ a: 'x'.repeat(MAX_PAYLOAD_CHARS) });
  assert.ok(enorme.length > MAX_PAYLOAD_CHARS);
  const r = ligne({ payload: enorme });
  assert.strictEqual(r.payload, null);
  assert.strictEqual(r.kind, 'crash');
});

test('une charge absente est normale — le client la retire au-dessus de son plafond', () => {
  assert.strictEqual(ligne({ payload: null }).payload, null);
  assert.strictEqual(ligne({ payload: undefined }).payload, null);
});

test('un scalaire est du JSON valide mais n\'est pas un rapport', () => {
  // `jsonb` accepterait `42` ou `"bonjour"`. Aucune requête ne saurait quoi en faire.
  assert.strictEqual(ligne({ payload: '42' }).payload, null);
  assert.strictEqual(ligne({ payload: '"bonjour"' }).payload, null);
  assert.strictEqual(ligne({ payload: 'null' }).payload, null);
  // Un tableau est un objet : accepté, parce que MetricKit pourrait en rendre un.
  assert.strictEqual(ligne({ payload: '[]' }).payload, '[]');
});

test('une charge valide est reparsée puis resérialisée, pas recopiée', () => {
  // L'aller-retour n'est pas gratuit : c'est lui qui garantit que la colonne reçoit du JSON.
  // Les espaces du client disparaissent, ce qui est la preuve qu'il a bien eu lieu.
  assert.strictEqual(ligne({ payload: '{ "a" :  1 }' }).payload, '{"a":1}');
});

// --- Les champs courts : des colonnes, pas du texte libre --------------------------------------

test('une chaîne vide devient NULL, parce que vide et nul ne se filtrent pas pareil', () => {
  const r = ligne({ appVersion: '', appBuild: '   ', osVersion: '\n' });
  assert.strictEqual(r.appVersion, null);
  assert.strictEqual(r.appBuild, null);
  assert.strictEqual(r.osVersion, null);
});

test('les espaces autour sont retirés', () => {
  assert.strictEqual(ligne({ appVersion: '  2.9  ' }).appVersion, '2.9');
});

test('un champ trop long devient NULL plutôt que tronqué', () => {
  // Tronquer fabriquerait une version qui n'existe pas, et elle serait agrégée comme telle.
  assert.strictEqual(ligne({ appVersion: 'v'.repeat(MAX_FIELD_CHARS + 1) }).appVersion, null);
  assert.strictEqual(ligne({ appVersion: 'v'.repeat(MAX_FIELD_CHARS) }).appVersion,
                     'v'.repeat(MAX_FIELD_CHARS));
  assert.strictEqual(ligne({ note: 'n'.repeat(MAX_NOTE_CHARS + 1) }).note, null);
});

test('un champ qui n\'est pas une chaîne devient NULL sans lever', () => {
  const r = ligne({ appVersion: 2.9, appBuild: ['412'], note: { texte: 'x' } });
  assert.strictEqual(r.appVersion, null);
  assert.strictEqual(r.appBuild, null);
  assert.strictEqual(r.note, null);
});

test('isTestflight n\'accepte qu\'un vrai booléen', () => {
  assert.strictEqual(ligne({ isTestflight: true }).isTestflight, true);
  assert.strictEqual(ligne({ isTestflight: false }).isTestflight, false);
  // 'true' et 1 seraient devenus `true` en base par coercition, et la colonne mentirait.
  assert.strictEqual(ligne({ isTestflight: 'true' }).isTestflight, null);
  assert.strictEqual(ligne({ isTestflight: 1 }).isTestflight, null);
  assert.strictEqual(ligne({ isTestflight: undefined }).isTestflight, null);
});

// --- La date : celle de la panne, pas celle de l'arrivée ---------------------------------------

test('une date plausible est gardée telle quelle', () => {
  assert.strictEqual(ligne({ occurredAt: '2026-11-08T11:58:30.000Z' }).occurredAt,
                     '2026-11-08T11:58:30.000Z');
});

test('UN MOIS DE RETARD EST LÉGITIME ET DOIT ÊTRE GARDÉ', () => {
  // Un appareil hors ligne garde ses rapports jusqu'au prochain envoi réussi. Écraser cette date
  // attribuerait le plantage à la version d'aujourd'hui — celle qui l'a peut-être corrigé.
  const ilYATroisSemaines = new Date(MAINTENANT - 21 * 24 * 3600 * 1000).toISOString();
  assert.strictEqual(ligne({ occurredAt: ilYATroisSemaines }).occurredAt, ilYATroisSemaines);
});

test('au-delà d\'un mois, l\'horloge de l\'appareil est fausse : on prend celle du serveur', () => {
  const ilYADeuxAns = new Date(MAINTENANT - 730 * 24 * 3600 * 1000).toISOString();
  assert.strictEqual(ligne({ occurredAt: ilYADeuxAns }).occurredAt,
                     new Date(MAINTENANT).toISOString());
});

test('une date dans le futur est ramenée, sauf la dérive de quelques minutes', () => {
  const dansDeuxMinutes = new Date(MAINTENANT + 2 * 60 * 1000).toISOString();
  assert.strictEqual(ligne({ occurredAt: dansDeuxMinutes }).occurredAt, dansDeuxMinutes);
  const dansUnAn = new Date(MAINTENANT + 365 * 24 * 3600 * 1000).toISOString();
  assert.strictEqual(ligne({ occurredAt: dansUnAn }).occurredAt, new Date(MAINTENANT).toISOString());
});

test('une date illisible ou absente devient l\'heure du serveur, jamais une ligne perdue', () => {
  for (const brut of ['hier', '', null, undefined, 1762603110000]) {
    assert.strictEqual(ligne({ occurredAt: brut }).occurredAt, new Date(MAINTENANT).toISOString());
  }
});

// --- L'endpoint lui-même -----------------------------------------------------------------------

test('le gestionnaire passe bien par ces règles et borne le lot', () => {
  // Les bornes pourraient être justes et n'être appelées par personne.
  const source = require('node:fs').readFileSync(require.resolve('../lib/rapportsEntrants.js'), 'utf8');
  assert.match(source, /nettoyerRapport/);
  assert.match(source, /MAX_REPORTS_PER_BATCH/);
  // L'élagage et la politique de confidentialité doivent annoncer la même durée.
  assert.match(source, /180 days/);
  const politique = require('node:fs').readFileSync(
    require('node:path').join(__dirname, '..', 'PRIVACY_POLICY.md'), 'utf8');
  assert.match(politique, /180 jours/,
               'PRIVACY_POLICY.md n\'annonce pas la durée de conservation des rapports de panne');
});

// --- LE CÂBLAGE, qui est la pièce la plus fragile de tout ce chantier ------------------------

test('/api/crashes EST RÉÉCRIT VERS /api/events, sinon l\'app poste dans le vide', () => {
  // Le gestionnaire vit dans `lib/`, qui n'est pas une route : sans cette réécriture, l'adresse
  // que `Diagnostics.swift` appelle rend 404, l'app reçoit un refus définitif, et elle JETTE le
  // rapport (voir `permanentlyRefused` côté client). La panne serait silencieuse des deux côtés.
  const vercel = JSON.parse(require('node:fs').readFileSync(
    require('node:path').join(__dirname, '..', 'vercel.json'), 'utf8'));
  const regle = (vercel.rewrites || []).find((r) => r.source === '/api/crashes');
  assert.ok(regle, 'aucune réécriture pour /api/crashes dans vercel.json');
  assert.strictEqual(regle.destination, '/api/events');
});

test('api/events.js aiguille sur `reports`, et sur le corps plutôt que sur le chemin', () => {
  // Sur le chemin, ce que la fonction lit dépend du détail d'implémentation de la réécriture.
  const source = require('node:fs').readFileSync(require.resolve('../api/events.js'), 'utf8');
  assert.match(source, /Array\.isArray\(\(req\.body \|\| \{\}\)\.reports\)/);
  assert.match(source, /recevoirLesRapports/);
});

test('UNE SEULE FONCTION DE PLUS ET PLUS RIEN NE SE DÉPLOIE', () => {
  // Vercel compte un fichier sous `api/` = une fonction, et le plan Hobby en autorise douze.
  // Le treizième fait échouer TOUT déploiement production, sans qu'aucune chaîne ne rougisse.
  // C'est arrivé deux fois dans ce dépôt : à l'ajout de l'analytique, puis le 8 novembre 2026
  // à l'ajout de `api/crashes.js`. `ci_scripts/check_fonctions.py` garde le compte ; ce cas-ci
  // est là pour que la limite soit aussi écrite du côté où on lit les tests du serveur.
  const fs = require('node:fs');
  const path = require('node:path');
  const api = path.join(__dirname, '..', 'api');
  const compter = (dossier) => fs.readdirSync(dossier, { withFileTypes: true })
    .reduce((n, e) => n + (e.isDirectory() ? compter(path.join(dossier, e.name))
                                          : (e.name.endsWith('.js') ? 1 : 0)), 0);
  assert.ok(compter(api) <= 12, `${compter(api)} fonctions sous api/ : le plafond Hobby est 12`);
});
