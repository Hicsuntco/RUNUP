// Découper du SQL sans se faire avoir par les points-virgules qui ne terminent rien.
//
// CE QUE CES TESTS PROTÈGENT. `db/schema.sql` est appliqué par une machine à chaque construction
// (voir ci_scripts/appliquer_schema.js), et le pilote Neon n'envoie qu'une instruction par
// requête. Un découpage faux ne casse pas le script : il envoie du SQL tronqué, que Postgres
// refuse avec un message qui ne désigne pas le vrai coupable — « unterminated dollar-quoted
// string » pour un point-virgule mal lu quarante lignes plus haut.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const { decouper, estVide } = require('../lib/decoupeSQL');

test('deux instructions simples', () => {
  assert.deepStrictEqual(
    decouper('SELECT 1; SELECT 2;').map((s) => s.trim()),
    ['SELECT 1', 'SELECT 2']
  );
});

test("la dernière instruction compte même sans point-virgule final", () => {
  assert.strictEqual(decouper('SELECT 1').length, 1);
});

test('UN POINT-VIRGULE DANS UN BLOC $$ NE COUPE RIEN', () => {
  // Le cas qui justifie tout ce fichier : trois blocs de `db/schema.sql` ont cette forme.
  const source = `
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'x') THEN
    ALTER TABLE clubs DROP CONSTRAINT IF EXISTS x;
    ALTER TABLE clubs ADD CONSTRAINT x FOREIGN KEY (a) REFERENCES users(id);
  END IF;
END $$;
SELECT 1;
`;
  const instructions = decouper(source);
  assert.strictEqual(instructions.length, 2);
  assert.ok(instructions[0].includes('END IF'), 'le bloc a été coupé en morceaux');
  assert.ok(instructions[0].trim().endsWith('END $$'));
});

test('une étiquette nommée se referme à l\'identique', () => {
  const source = "DO $corps$ BEGIN RAISE NOTICE 'a;b'; END $corps$; SELECT 2;";
  assert.strictEqual(decouper(source).length, 2);
});

test('UN POINT-VIRGULE DANS UNE CHAÎNE NE COUPE RIEN', () => {
  assert.strictEqual(decouper("SELECT 'a;b'; SELECT 2;").length, 2);
});

test("une apostrophe échappée ne ferme pas la chaîne", () => {
  // `'l''été; encore'` est UNE chaîne. Mal lue, elle refermerait la chaîne au milieu et le
  // point-virgule suivant couperait l'instruction en deux.
  assert.strictEqual(decouper("SELECT 'l''été; encore'; SELECT 2;").length, 2);
});

test('UN POINT-VIRGULE DANS UN COMMENTAIRE NE COUPE RIEN', () => {
  assert.strictEqual(decouper('-- a; b\nSELECT 1;').length, 1);
  assert.strictEqual(decouper('/* a; b */ SELECT 1;').length, 1);
});

test('un commentaire reste attaché à son instruction', () => {
  // Il dit souvent POURQUOI elle existe, et c'est ce qu'on veut lire dans un journal de migration.
  const instructions = decouper('-- pourquoi\nSELECT 1;');
  assert.ok(instructions[0].includes('pourquoi'));
});

test("un bloc de commentaires seul n'est pas une instruction", () => {
  assert.deepStrictEqual(decouper('-- rien que du commentaire\n'), []);
  assert.deepStrictEqual(decouper('SELECT 1;\n-- une note finale\n').length, 1);
});

test('un $ qui n\'est pas une étiquette ne mange pas la suite', () => {
  // `$1` est un paramètre, pas une ouverture de bloc. Le prendre pour une étiquette avalerait
  // tout le fichier jusqu'au `$` suivant.
  assert.strictEqual(decouper('SELECT $1; SELECT $2;').length, 2);
});

test('un identifiant entre guillemets doubles est traversé', () => {
  assert.strictEqual(decouper('SELECT "a;b" FROM t; SELECT 2;').length, 2);
});

test('estVide reconnaît le blanc et les commentaires', () => {
  assert.strictEqual(estVide('   \n  '), true);
  assert.strictEqual(estVide('-- note'), true);
  assert.strictEqual(estVide('/* note */'), true);
  assert.strictEqual(estVide('SELECT 1'), false);
});

// --- Le vrai fichier ----------------------------------------------------------------------

test('LE SCHÉMA DU DÉPÔT SE DÉCOUPE EN INSTRUCTIONS ENTIÈRES', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'db/schema.sql'), 'utf8');
  const instructions = decouper(source);

  assert.ok(instructions.length > 60, `seulement ${instructions.length} instructions`);

  // Aucune ne doit porter un bloc ouvert : c'est la signature exacte d'un découpage raté.
  for (const instruction of instructions) {
    const dollars = (instruction.match(/\$\$/g) || []).length;
    assert.strictEqual(dollars % 2, 0,
      `bloc $$ non refermé dans :\n${instruction.slice(0, 200)}`);
  }

  // Et chaque instruction doit commencer par un verbe SQL, commentaires retirés.
  const VERBES = /^(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|DO|COMMENT|GRANT|SELECT|SET)\b/i;
  for (const instruction of instructions) {
    const nu = instruction
      .replace(/\/\*[\s\S]*?\*\//g, ' ')
      .replace(/--[^\n]*/g, ' ')
      .trim();
    assert.ok(VERBES.test(nu), `ne commence pas par un verbe SQL :\n${nu.slice(0, 160)}`);
  }
});

test('les trois blocs DO du schéma sont entiers', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'db/schema.sql'), 'utf8');
  const blocs = decouper(source).filter((i) => i.includes('DO $$'));
  assert.strictEqual(blocs.length, 3);
  for (const bloc of blocs) {
    assert.ok(bloc.trim().endsWith('END $$'), `bloc tronqué :\n${bloc.slice(0, 160)}`);
  }
});
