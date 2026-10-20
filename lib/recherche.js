// Replier un nom pour le chercher : accents, casse, traits d'union, ligatures.
//
// # POURQUOI UNE SEULE TABLE, ICI
//
// La recherche de « Mes amis » compare ce qui a été TAPÉ à ce qui est EN BASE. Les deux doivent
// être repliés de la même façon, sinon chercher « leo » ne trouve pas « Léo » — et c'est le cas
// le plus courant qui soit dans une app française.
//
// Le repli du texte tapé se fait en JavaScript, celui des colonnes en SQL (`translate`). Deux
// implémentations, donc deux occasions de diverger : une lettre ajoutée d'un côté et oubliée de
// l'autre fait silencieusement rater une recherche sur mille, celle qui porte précisément cette
// lettre. La table ci-dessous est donc la SEULE définition. Le JavaScript la parcourt, et le SQL
// reçoit ses deux colonnes comme paramètres.
//
// `tests/recherche.test.js` vérifie que les deux colonnes ont la même longueur — sans quoi
// `translate` ne supprimerait pas une lettre, il la SUPPRIMERAIT (une source sans cible est
// retirée du texte) — et que le repli JavaScript rend bien, lettre à lettre, ce que le SQL rendra.

// Les lettres qui perdent leur signe. Une entrée = un caractère, dans les deux colonnes.
const ACCENTS = {
  à: 'a', á: 'a', â: 'a', ã: 'a', ä: 'a', å: 'a',
  ç: 'c',
  è: 'e', é: 'e', ê: 'e', ë: 'e',
  ì: 'i', í: 'i', î: 'i', ï: 'i',
  ñ: 'n',
  ò: 'o', ó: 'o', ô: 'o', õ: 'o', ö: 'o', ø: 'o',
  ù: 'u', ú: 'u', û: 'u', ü: 'u',
  ý: 'y', ÿ: 'y',
};

// Les deux colonnes de `translate()`, dérivées de la table — jamais écrites à la main.
const ACCENTS_SOURCE = Object.keys(ACCENTS).join('');
const ACCENTS_CIBLE = Object.values(ACCENTS).join('');

// Les ligatures, qui ne tiennent pas dans `translate` : elles valent DEUX lettres, et `translate`
// remplace caractère par caractère. Traitées à part, des deux côtés.
const LIGATURES = [['œ', 'oe'], ['æ', 'ae']];

// Ce qui sépare deux mots dans un nom propre. « Jean-Pierre » et « Jean Pierre » sont le même
// nom, et personne ne devrait avoir à deviner lequel l'autre a tapé. L'apostrophe suit la même
// logique : « O'Connor » se cherche « o connor » aussi bien que « oconnor »… à ceci près qu'un
// espace est plus prévisible qu'une suppression, donc c'est un espace.
const SEPARATEURS = /[-'’._]+/g;

// Replie un texte : minuscules, ligatures, séparateurs, accents, espaces resserrés.
function normaliser(texte) {
  if (typeof texte !== 'string') return '';
  let sortie = texte.toLowerCase();
  for (const [ligature, remplacement] of LIGATURES) {
    sortie = sortie.split(ligature).join(remplacement);
  }
  sortie = sortie.replace(SEPARATEURS, ' ');
  sortie = Array.from(sortie).map((c) => ACCENTS[c] || c).join('');
  return sortie.replace(/\s+/g, ' ').trim();
}

// Rend sûr pour un `LIKE` : `%` et `_` y sont des jokers, et `_` est une lettre légale de pseudo.
// Sans ça, chercher « jean_ » listerait tous les « jean » suivis de n'importe quoi.
function echapperPourLike(texte) {
  return texte.replace(/[\\%_]/g, (c) => '\\' + c);
}

module.exports = { ACCENTS, ACCENTS_SOURCE, ACCENTS_CIBLE, LIGATURES, normaliser, echapperPourLike };
