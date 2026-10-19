// Le nom d'affichage d'un compte : comment on le choisit à la création, et quand on a le droit
// de le remplacer ensuite.
//
// # POURQUOI CES DEUX RÈGLES VIVENT ENSEMBLE
//
// « Se connecter avec Apple » ne transmet `fullName` qu'à la TOUTE PREMIÈRE autorisation d'un
// identifiant Apple pour cette app. Une réinstallation, un second appareil, ou un compte Apple
// qui avait déjà ouvert RUNUP une fois n'envoient rien : le compte était alors créé sous
// `NOM_PAR_DEFAUT`, et plus rien ne pouvait le corriger.
//
// Ce n'était pas un détail d'affichage. La recherche de « Mes amis » interroge
// `name || ' ' || last_name` : taper le vrai prénom de quelqu'un ne le trouvait pas, et taper
// « Coureur » les trouvait tous à la fois, indiscernables.
//
// La création et la réparation doivent donc appliquer EXACTEMENT le même filtre — sinon un nom
// refusé à la création repasserait par la porte de la connexion. Les deux sont ici, côte à côte.
const { containsObjectionableContent } = require('./moderation');

// La seule valeur de `users.name` qu'une connexion ultérieure a le droit de remplacer. Un nom
// que quelqu'un a choisi, jamais.
//
// Recopié une fois côté app, dans `MoreSettingsView`, pour pré-remplir le champ « Prénom » de
// qui est rangé là — un simple confort, qui cesse silencieusement si cette valeur change.
const NOM_PAR_DEFAUT = 'Coureur';

// La longueur retenue en base. 60 est la même borne que `last_name` et que le prénom modifiable
// de `api/friends/updateProfile`.
const LONGUEUR_MAX = 60;

function nomPropre(recu) {
  const brut = typeof recu === 'string' ? recu.trim() : '';
  if (!brut || containsObjectionableContent(brut)) return null;
  return brut.slice(0, LONGUEUR_MAX);
}

// À LA CRÉATION : le nom reçu s'il est acceptable, le nom de repli sinon. Ne rend jamais vide —
// la colonne est `NOT NULL`, et un compte sans nom n'a rien à afficher dans un fil d'activité.
function nomALaCreation(recu) {
  return nomPropre(recu) || NOM_PAR_DEFAUT;
}

// À LA CONNEXION : le nom à écrire pour réparer un compte qui n'en a jamais reçu, ou `null`
// quand il n'y a rien à faire.
//
// La condition est volontairement étroite. Un client trafiqué ne gagne rien : il peut déjà
// changer son propre prénom par `api/friends/updateProfile`, et seulement le sien.
function nomDeReparation(nomActuel, recu) {
  if (nomActuel !== NOM_PAR_DEFAUT) return null;
  return nomPropre(recu);
}

module.exports = { NOM_PAR_DEFAUT, LONGUEUR_MAX, nomALaCreation, nomDeReparation };
