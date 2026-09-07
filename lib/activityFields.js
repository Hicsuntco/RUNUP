// Les champs d'une activité que l'autrice possède : son titre, sa note, et le tracé de sa sortie.
//
// Dans `lib/` plutôt que dans le point d'entrée qui les utilise, pour la même raison que
// `moderation.js` : ce sont des règles, et une règle qu'on ne peut pas tester est une règle qu'on
// espère. Celles-ci gardent la seule porte par laquelle du texte écrit par quelqu'un entre dans le
// fil de tout un club, et la seule par laquelle une position GPS entre en base.
const { containsObjectionableContent } = require('./moderation');

// Deux tailles, choisies sur ce qu'une carte de fil peut porter : un titre tient sur une ligne,
// une note sur un paragraphe qu'on lit sans le déplier.
const MAX_TITLE = 80;
const MAX_NOTE = 500;

// Une centaine de points suffit à reconnaître un parcours dans une carte de fil. Le plafond borne
// ce qu'on stocke et ce qu'on renvoie cinquante fois par chargement de fil — ce n'est pas un
// jugement sur la qualité du tracé.
const MAX_FEED_ROUTE_POINTS = 120;

// Distinguer « rien fourni » de « fourni mais refusé ».
//
// Sans ce marqueur, les deux se confondraient en `null` : un titre injurieux serait enregistré
// comme un titre absent, et la modération échouerait EN SILENCE — la pire façon d'échouer pour une
// modération, puisque personne n'apprend qu'elle a échoué.
const REJECTED = Symbol('rejected');

function isLatLngPair(p) {
  return Array.isArray(p) && p.length === 2
    && Number.isFinite(p[0]) && Number.isFinite(p[1])
    && p[0] >= -90 && p[0] <= 90 && p[1] >= -180 && p[1] <= 180;
}

// Le texte que l'autrice possède. Modéré comme les noms de clubs et les commentaires, pour la même
// raison : il atterrit dans le fil de tout le club, et sur des écrans de verrouillage via les
// notifications.
//
// Le rognage a lieu AVANT le filtre, pas après : filtrer puis couper laisserait passer un texte
// dont la coupe recrée un mot que le filtre venait d'écarter.
function sanitizeOwnText(value, max) {
  if (typeof value !== 'string') return null;
  const clean = value.trim().slice(0, max);
  if (!clean) return null;
  if (containsObjectionableContent(clean)) return REJECTED;
  return clean;
}

// Le tracé arrive DÉJÀ rogné de ses extrémités par l'appareil, et le serveur ne peut pas le
// vérifier : il ne voit jamais la course d'origine, seulement ce qu'on lui en montre. Il vérifie
// donc ce qu'il peut — que c'est bien une liste de coordonnées plausibles, et qu'elle est bornée.
//
// Le refus est SILENCIEUX (`null`, pas une erreur), contrairement à celui du texte : un tracé
// malformé est un défaut d'affichage, pas une raison de perdre la course qui le portait. Un texte
// injurieux, lui, doit faire échouer la requête entière.
function sanitizeRoutePreview(value) {
  if (!Array.isArray(value) || value.length < 2 || !value.every(isLatLngPair)) return null;
  return value.slice(0, MAX_FEED_ROUTE_POINTS);
}

module.exports = {
  MAX_TITLE, MAX_NOTE, MAX_FEED_ROUTE_POINTS, REJECTED,
  isLatLngPair, sanitizeOwnText, sanitizeRoutePreview,
};
