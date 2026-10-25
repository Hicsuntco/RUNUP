// Ce qu'on accepte quand quelqu'un crée une course.
//
// Extrait du handler pour une raison précise : `website` finit en LIEN TAPABLE sur la page de la
// course. Un champ libre qu'on affiche est une chose ; un champ libre qu'on rend tapable en est
// une autre, et `javascript:` n'est pas une adresse de site. La règle vit donc ici, seule, avec
// ses tests — plutôt qu'au milieu de quarante lignes d'insertion.
const { normaliser } = require('./recherche');

// Les familles d'épreuves qu'une course peut porter — les mêmes que les objectifs de l'app.
const DISCIPLINES = ['run', 'trail', 'hyrox', 'triathlon', 'duathlon'];

const LONGUEUR_NOM = 120;
const LONGUEUR_VILLE = 80;
const LONGUEUR_SITE = 300;

// Seulement http(s). Tout le reste — `javascript:`, `data:`, `file:` — est refusé plutôt que
// nettoyé : une adresse qu'on ne reconnaît pas n'a aucune raison d'être proposée au doigt de
// quelqu'un.
const SITE = /^https?:\/\/[^\s<>"]+$/i;
const DATE_ISO = /^\d{4}-\d{2}-\d{2}$/;

// Les dates se comparent comme des chaînes : en ISO, l'ordre alphabétique EST l'ordre
// chronologique. Pas de fuseau, pas de `Date` locale, pas de course qui disparaît à minuit selon
// l'endroit d'où on la crée.
function aujourdhuiUTC() {
  return new Date().toISOString().slice(0, 10);
}

function texte(valeur, longueur) {
  return typeof valeur === 'string' && valeur.trim() ? valeur.trim().slice(0, longueur) : null;
}

// Rend `{ erreur }` ou `{ course }`. Ne touche à aucune base : c'est de la validation pure, et
// c'est ce qui la rend vérifiable sans serveur.
function nettoyerCourse(entree, aujourdhui) {
  const brut = entree || {};
  const jour = typeof aujourdhui === 'string' && DATE_ISO.test(aujourdhui) ? aujourdhui : aujourdhuiUTC();

  const name = texte(brut.name, LONGUEUR_NOM);
  if (!name) return { erreur: 'bad_request' };

  const nameKey = normaliser(name);
  // Un nom qui ne contient que de la ponctuation se replie en chaîne vide : il ne pourrait ni
  // se chercher, ni se dédoublonner.
  if (!nameKey) return { erreur: 'bad_request' };

  const raceDate = typeof brut.raceDate === 'string' ? brut.raceDate.slice(0, 10) : '';
  if (!DATE_ISO.test(raceDate)) return { erreur: 'bad_date' };
  // Une date que `Date` refuse — le 31 février, par exemple — passe la forme mais n'existe pas.
  const verif = new Date(raceDate + 'T00:00:00Z');
  if (Number.isNaN(verif.getTime()) || verif.toISOString().slice(0, 10) !== raceDate) {
    return { erreur: 'bad_date' };
  }
  // Et dans le futur. Une page de course passée n'a plus personne à réunir : la recherche ne la
  // rendrait pas, donc la créer ne ferait qu'ajouter une ligne que personne ne reverrait jamais.
  if (raceDate < jour) return { erreur: 'past_date' };

  const km = Number(brut.distanceKm);
  // 1000 km : au-delà, c'est une faute de frappe, pas une course. Le record du monde des 24 h
  // tourne autour de 300.
  const distanceKm = Number.isFinite(km) && km > 0 && km <= 1000 ? km : null;

  const d = brut.elevationGainM;
  const elevationGainM = Number.isInteger(d) && d >= 0 && d <= 30000 ? d : null;

  const discipline = DISCIPLINES.includes(brut.discipline) ? brut.discipline : 'run';

  const siteBrut = texte(brut.website, LONGUEUR_SITE);
  // Une adresse refusée n'est pas une erreur : la course se crée sans. Bloquer la création d'une
  // course pour un champ facultatif mal collé serait la punir pour un détail.
  const website = siteBrut && SITE.test(siteBrut) ? siteBrut : null;

  return {
    course: {
      name,
      nameKey,
      city: texte(brut.city, LONGUEUR_VILLE),
      raceDate,
      distanceKm,
      elevationGainM,
      discipline,
      website,
    },
  };
}

module.exports = { DISCIPLINES, nettoyerCourse, LONGUEUR_NOM, LONGUEUR_VILLE, LONGUEUR_SITE };
