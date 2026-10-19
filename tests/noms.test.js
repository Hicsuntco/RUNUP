// Ce que le serveur fait du nom d'un compte — à sa création, et à chaque connexion ensuite.
//
// LE DÉFAUT QUE CES TESTS EMPÊCHENT DE REVENIR. « Se connecter avec Apple » ne transmet
// `fullName` qu'à la toute première autorisation d'un identifiant Apple pour cette app. Tous les
// comptes créés autrement — réinstallation, second appareil, identifiant Apple qui avait déjà
// ouvert RUNUP une fois — étaient rangés sous « Coureur », pour toujours : aucun écran ne
// permettait de corriger le prénom. La recherche de « Mes amis » interroge
// `name || ' ' || last_name`, donc leur vrai prénom ne les trouvait pas, et « Coureur » les
// trouvait tous à la fois.
//
// La réparation ouvre une porte qu'il faut tenir étroite : une connexion ne doit JAMAIS pouvoir
// écraser un nom que quelqu'un a choisi. C'est la moitié de ce fichier.
const test = require('node:test');
const assert = require('node:assert');

const { NOM_PAR_DEFAUT, LONGUEUR_MAX, nomALaCreation, nomDeReparation } = require('../lib/noms');

// --- À la création -----------------------------------------------------------------------------

test('un prénom normal est gardé tel quel', () => {
  assert.strictEqual(nomALaCreation('Charlotte'), 'Charlotte');
});

test('les espaces autour sont retirés', () => {
  assert.strictEqual(nomALaCreation('  Léo  '), 'Léo');
});

test("Apple muet donne le nom de repli, jamais une chaîne vide", () => {
  // La colonne est NOT NULL : rendre une chaîne vide ferait échouer l'inscription entière.
  assert.strictEqual(nomALaCreation(undefined), NOM_PAR_DEFAUT);
  assert.strictEqual(nomALaCreation(null), NOM_PAR_DEFAUT);
  assert.strictEqual(nomALaCreation(''), NOM_PAR_DEFAUT);
  assert.strictEqual(nomALaCreation('   '), NOM_PAR_DEFAUT);
});

test('un type inattendu ne passe pas pour un nom', () => {
  assert.strictEqual(nomALaCreation(42), NOM_PAR_DEFAUT);
  assert.strictEqual(nomALaCreation({ name: 'Charlotte' }), NOM_PAR_DEFAUT);
});

test('un nom trop long est coupé à la longueur de la colonne', () => {
  const long = 'a'.repeat(LONGUEUR_MAX + 40);
  assert.strictEqual(nomALaCreation(long).length, LONGUEUR_MAX);
});

// --- À la connexion : la réparation --------------------------------------------------------------

test('un compte rangé sous le nom de repli est réparé', () => {
  assert.strictEqual(nomDeReparation(NOM_PAR_DEFAUT, 'Charlotte'), 'Charlotte');
});

test('UN NOM CHOISI N\'EST JAMAIS REMPLACÉ', () => {
  // La règle qui tient la porte. Sans elle, n'importe quelle connexion pourrait renommer le
  // compte — et un client trafiqué n'aurait qu'à envoyer ce qu'il veut à chaque fois.
  assert.strictEqual(nomDeReparation('Charlotte', 'AutreChose'), null);
  assert.strictEqual(nomDeReparation('Léo', NOM_PAR_DEFAUT), null);
});

test('rien à réparer quand le client n\'envoie rien', () => {
  assert.strictEqual(nomDeReparation(NOM_PAR_DEFAUT, undefined), null);
  assert.strictEqual(nomDeReparation(NOM_PAR_DEFAUT, ''), null);
  assert.strictEqual(nomDeReparation(NOM_PAR_DEFAUT, '   '), null);
});

test('la réparation ne peut pas remplacer le repli par le repli', () => {
  // Pas une erreur, mais une écriture pour rien à chaque connexion de chaque compte concerné.
  assert.strictEqual(nomDeReparation(NOM_PAR_DEFAUT, NOM_PAR_DEFAUT), NOM_PAR_DEFAUT);
});

test('la réparation coupe à la même longueur que la création', () => {
  const long = 'b'.repeat(LONGUEUR_MAX + 40);
  assert.strictEqual(nomDeReparation(NOM_PAR_DEFAUT, long).length, LONGUEUR_MAX);
});

// --- Le filtre de contenu, des deux côtés --------------------------------------------------------

test('la création et la réparation appliquent le même filtre', () => {
  // Le point de tout le module : un nom refusé à la création ne doit pas repasser par la porte
  // de la connexion. On ne code pas la liste en dur ici — on vérifie que les deux fonctions
  // répondent pareil, quelle qu'elle soit.
  const { containsObjectionableContent } = require('../lib/moderation');
  const candidats = ['Charlotte', 'Léo', 'Zoé-Marie', "O'Connor"];
  for (const candidat of candidats) {
    const accepte = !containsObjectionableContent(candidat);
    assert.strictEqual(nomALaCreation(candidat) === candidat, accepte, candidat);
    assert.strictEqual(nomDeReparation(NOM_PAR_DEFAUT, candidat) === candidat, accepte, candidat);
  }
});
