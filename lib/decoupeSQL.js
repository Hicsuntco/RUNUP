// Découper un fichier SQL en instructions, sans se faire avoir par ce qui contient des
// points-virgules.
//
// # POURQUOI CE FICHIER EXISTE
//
// `db/schema.sql` doit pouvoir être appliqué par une machine, et le pilote Neon n'envoie qu'UNE
// instruction par requête (il parle en HTTP, pas en session Postgres). Il faut donc découper. Un
// `split(';')` naïf marche sur quatre-vingts lignes du fichier et casse sur trois :
//
//     DO $$ BEGIN
//       IF NOT EXISTS (...) THEN
//         ALTER TABLE clubs DROP CONSTRAINT IF EXISTS clubs_created_by_fkey;   ← ici
//       END IF;
//     END $$;
//
// Le point-virgule marqué est à l'INTÉRIEUR d'un bloc entre guillemets-dollar. Un découpage naïf
// en ferait trois morceaux dont aucun n'est du SQL valide, et l'erreur remontée — « unterminated
// dollar-quoted string » — ne désignerait pas le vrai coupable.
//
// Trois choses portent des points-virgules sans les terminer : les guillemets-dollar (`$$`,
// `$tag$`), les chaînes simples (`'...'`, où `''` échappe une apostrophe), et les commentaires
// (`--` jusqu'à la fin de ligne, `/* ... */`). Ce découpeur les connaît tous les trois.
//
// Les commentaires sont GARDÉS dans l'instruction qu'ils précèdent : ils expliquent souvent
// pourquoi elle existe, et c'est ce qu'on veut lire dans un journal de migration.

function decouper(source) {
  const instructions = [];
  let courante = '';
  let i = 0;
  const n = source.length;

  while (i < n) {
    const c = source[i];

    // Commentaire de ligne : tout jusqu'au saut, point-virgule compris.
    if (c === '-' && source[i + 1] === '-') {
      while (i < n && source[i] !== '\n') { courante += source[i]; i += 1; }
      continue;
    }

    // Commentaire de bloc.
    if (c === '/' && source[i + 1] === '*') {
      courante += '/*'; i += 2;
      while (i < n && !(source[i] === '*' && source[i + 1] === '/')) { courante += source[i]; i += 1; }
      if (i < n) { courante += '*/'; i += 2; }
      continue;
    }

    // Chaîne simple. `''` à l'intérieur est une apostrophe échappée, pas une fin de chaîne.
    if (c === "'") {
      courante += c; i += 1;
      while (i < n) {
        if (source[i] === "'" && source[i + 1] === "'") { courante += "''"; i += 2; continue; }
        if (source[i] === "'") { courante += "'"; i += 1; break; }
        courante += source[i]; i += 1;
      }
      continue;
    }

    // Guillemets-dollar : `$$`, `$BEGIN$`, `$tag$`. L'étiquette doit se refermer à l'identique.
    if (c === '$') {
      const fin = source.indexOf('$', i + 1);
      const etiquette = fin === -1 ? null : source.slice(i, fin + 1);
      // Une étiquette ne contient que des lettres, des chiffres et des soulignés — sinon ce `$`
      // est autre chose (un `$1` de paramètre, par exemple) et ne ferme rien.
      if (etiquette && /^\$[A-Za-z0-9_]*\$$/.test(etiquette)) {
        const cloture = source.indexOf(etiquette, fin + 1);
        if (cloture !== -1) {
          courante += source.slice(i, cloture + etiquette.length);
          i = cloture + etiquette.length;
          continue;
        }
      }
      courante += c; i += 1;
      continue;
    }

    // Identifiant entre guillemets doubles : "ma table;bizarre".
    if (c === '"') {
      courante += c; i += 1;
      while (i < n) {
        courante += source[i];
        if (source[i] === '"') { i += 1; break; }
        i += 1;
      }
      continue;
    }

    if (c === ';') {
      instructions.push(courante);
      courante = '';
      i += 1;
      continue;
    }

    courante += c;
    i += 1;
  }

  instructions.push(courante);

  // Une instruction qui ne contient que des commentaires et du blanc n'en est pas une : c'est le
  // cas du bloc de commentaires en tête du fichier, et de celui qui suit le dernier
  // point-virgule.
  return instructions.filter((brute) => !estVide(brute));
}

function estVide(instruction) {
  const sansCommentaires = instruction
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/--[^\n]*/g, ' ');
  return sansCommentaires.trim() === '';
}

module.exports = { decouper, estVide };
