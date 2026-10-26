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
// Le plafond dur, VÉRIFIÉ AVANT de parcourir la liste. `.every()` inspectait le tableau ENTIER
// avant la troncature : un client trafiqué postant deux cent mille paires faisait valider deux cent
// mille paires par requête, sous la limite de corps de la plateforme et sans qu'aucun contrôle de
// taille ne précède. La publication d'itinéraire, dans le même flux, refuse au-delà de sa borne —
// c'est cette asymétrie qui a mis la puce à l'oreille.
const MAX_FEED_ROUTE_INPUT = MAX_FEED_ROUTE_POINTS * 20;

// LES INDICES GARDÉS, ÉCRITS UNE SEULE FOIS.
//
// Le tracé et ses altitudes doivent être échantillonnés EXACTEMENT de la même façon : le
// troisième point gardé et la troisième altitude gardée décrivent le même pas de course. Deux
// boucles écrites séparément se seraient ressemblées, puis auraient divergé au premier
// changement de plafond — et le profil de dénivelé aurait désigné les mauvais kilomètres, sans
// que rien ne plante.
//
// Rend `null` quand il n'y a rien à échantillonner : tout est gardé.
function indicesGardes(longueur) {
  if (longueur <= MAX_FEED_ROUTE_POINTS) return null;
  const pas = longueur / MAX_FEED_ROUTE_POINTS;
  const out = [];
  for (let i = 0; i < MAX_FEED_ROUTE_POINTS; i += 1) out.push(Math.floor(i * pas));
  // Le dernier point réel, pour que la boucle se referme là où la course s'est arrêtée.
  out[out.length - 1] = longueur - 1;
  return out;
}

function sanitizeRoutePreview(value) {
  if (!Array.isArray(value) || value.length < 2) return null;
  if (value.length > MAX_FEED_ROUTE_INPUT) return null;
  if (!value.every(isLatLngPair)) return null;
  // ÉCHANTILLONNÉ, PAS TRONQUÉ PAR LA TÊTE. `slice(0, 120)` gardait les cent vingt PREMIERS
  // points : la carte du fil montrait le début du parcours et s'arrêtait net, une ligne ouverte
  // qui prétend être la sortie. C'est exactement ce que le client refuse de faire de son côté —
  // « mieux vaut une carte sans dessin qu'un dessin faux ». Un pas régulier garde la forme
  // entière, du départ à l'arrivée.
  const indices = indicesGardes(value.length);
  return indices ? indices.map((i) => value[i]) : value;
}

// LES ALTITUDES DU TRACÉ, à côté de lui et dans le même ordre.
//
// Validées contre la longueur du tracé D'ENTRÉE — celui que l'appareil a envoyé, avant
// échantillonnage — puis échantillonnées avec les mêmes indices. Une liste d'une autre longueur
// est refusée en entier plutôt que recalée : on ne peut pas deviner lequel des deux a raison, et
// un profil décalé d'un cran est un profil faux.
//
// `null` est une valeur admise à l'intérieur : une altitude GPS n'est gardée que quand sa
// précision verticale était digne de foi, et l'appareil envoie le trou plutôt que de le boucher.
// Les bornes vont du point le plus bas habité au-dessus duquel personne ne court (-500 m) au
// sommet de l'Everest arrondi (9000 m).
function sanitizeAltitudes(value, longueurDuTrace) {
  if (!Array.isArray(value) || !Number.isInteger(longueurDuTrace)) return null;
  if (value.length !== longueurDuTrace) return null;
  const valide = value.every((a) => a === null || (Number.isFinite(a) && a >= -500 && a <= 9000));
  if (!valide) return null;
  // Tout nul ne vaut pas un profil : la colonne reste vide plutôt que de porter une liste de
  // trous que l'app devrait apprendre à ne pas dessiner.
  if (value.every((a) => a === null)) return null;
  const indices = indicesGardes(value.length);
  return indices ? indices.map((i) => value[i]) : value;
}

// Un kilomètre ne se court pas en moins d'une minute ni en plus de 99 minutes 59, et une sortie
// ne fait pas deux cents kilomètres. La forme « m:ss » est la même que celle de l'allure moyenne,
// pour la même raison : ces temps sont rendus tels quels dans l'écran de quelqu'un d'autre.
const MAX_SPLITS = 200;
const FORME_SPLIT = /^\d{1,2}:[0-5]\d$/;

function sanitizeSplits(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_SPLITS) return null;
  if (!value.every((s) => typeof s === 'string' && FORME_SPLIT.test(s))) return null;
  return value;
}

// La fréquence cardiaque moyenne et les calories. Bornes physiologiques : en dessous de 30 bpm
// personne ne court, au-dessus de 250 la montre s'est trompée. Zéro n'est JAMAIS enregistré — la
// règle de toute cette table : une absence de mesure n'est pas une mesure nulle.
function sanitizeEntierBorne(value, min, max) {
  if (!Number.isFinite(value)) return null;
  const arrondi = Math.round(value);
  if (arrondi < min || arrondi > max) return null;
  return arrondi;
}

module.exports = {
  MAX_TITLE, MAX_NOTE, MAX_FEED_ROUTE_POINTS, MAX_FEED_ROUTE_INPUT, MAX_SPLITS, REJECTED,
  isLatLngPair, sanitizeOwnText, sanitizeRoutePreview,
  sanitizeAltitudes, sanitizeSplits, sanitizeEntierBorne,
};
