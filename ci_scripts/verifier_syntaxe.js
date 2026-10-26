#!/usr/bin/env node
// CHAQUE FICHIER DU SERVEUR SE PARSE, ET RIEN NE LE VÉRIFIAIT.
//
// `npm test` ne charge que `tests/*.test.js` et ce qu'ils demandent — donc `lib/`, jamais `api/`.
// Les points d'entrée demandent `@vercel/blob` et `jose`, que les tests ne chargent pas : une
// faute de syntaxe dans `api/` passait donc toute la CI et n'échouait qu'au déploiement, après
// le `git push`, dans une interface qu'il faut penser à aller regarder.
//
// LA FAUTE QUI A MOTIVÉ CE SCRIPT est instructive : un ACCENT GRAVE dans un commentaire SQL,
// à l'intérieur d'une requête délimitée par des accents graves. Le premier refermait le gabarit
// JavaScript au milieu de la requête, et la suite devenait du code. Rien ne se voit à la
// lecture — le commentaire a l'air d'un commentaire.
//
// `node --check` fait exactement ce qu'il faut : il parse sans exécuter, donc sans avoir besoin
// d'une seule dépendance installée ni d'une variable d'environnement.
const { execFileSync } = require('node:child_process');
const { readdirSync, statSync } = require('node:fs');
const { join } = require('node:path');

const racine = join(__dirname, '..');
const dossiers = ['api', 'lib', 'db', 'ci_scripts'];

function fichiersJS(chemin) {
  const out = [];
  for (const entree of readdirSync(chemin)) {
    const complet = join(chemin, entree);
    if (statSync(complet).isDirectory()) out.push(...fichiersJS(complet));
    else if (entree.endsWith('.js')) out.push(complet);
  }
  return out;
}

const fautes = [];
let vus = 0;
for (const dossier of dossiers) {
  let fichiers;
  try {
    fichiers = fichiersJS(join(racine, dossier));
  } catch {
    continue; // dossier absent : rien à vérifier, pas une faute
  }
  for (const fichier of fichiers) {
    vus += 1;
    try {
      execFileSync(process.execPath, ['--check', fichier], { stdio: 'pipe' });
    } catch (erreur) {
      fautes.push([fichier.slice(racine.length + 1), String(erreur.stderr || erreur.message).trim()]);
    }
  }
}

if (fautes.length > 0) {
  console.error('Des fichiers du serveur ne se parsent pas :\n');
  for (const [fichier, message] of fautes) {
    console.error(`  ${fichier}\n${message}\n`);
  }
  console.error('Ils seraient passés jusqu’au déploiement : `npm test` ne charge que les tests');
  console.error('et ce qu’ils demandent, donc jamais les points d’entrée de `api/`.');
  process.exit(1);
}

console.log(`Syntaxe : ${vus} fichiers du serveur se parsent.`);
