// CE QU'ON VOIT QUAND ON N'A RIEN À TAPER.
//
// Le code d'invitation à six lettres a été retiré avec cette raison, écrite dans `db/schema.sql` :
// « un code suppose qu'on l'ait reçu de quelqu'un, donc qu'on sache déjà que le club existe —
// c'est-à-dire tout ce qu'une recherche rend inutile ».
//
// Sauf que la recherche exige deux caractères du NOM. Elle suppose donc elle aussi qu'on sache
// déjà que le club existe. Quelqu'un qui ouvre « Rejoindre un club » sans connaître un seul nom
// voyait un champ vide et rien d'autre — la même porte fermée, deux crans plus loin.
//
// Ce module met en forme les lignes suggérées. La requête vit dans `api/clubs/[action].js` ; ce
// qui se calcule sans base de données vit ici, pour être éprouvé sans elle.

/// Quatorze jours, et pas sept : un club qui se parle une fois par quinzaine est vivant. Sept
/// jours ferait disparaître la mention pendant les vacances scolaires, c'est-à-dire au moment où
/// quelqu'un cherche justement avec qui courir.
const FRAICHEUR_JOURS = 14;

/// Cinq lignes, pas un annuaire complet. Une liste qu'on fait défiler demande de choisir ; cinq
/// lignes demandent d'en essayer une.
const MAX_SUGGESTIONS = 5;

/// La forme EXACTE d'un résultat de recherche, plus les deux raisons.
///
/// L'app réutilise la même ligne pour les deux listes : une suggestion doit ressembler à ce qu'on
/// aurait trouvé en cherchant, sinon ce n'est plus la même porte. Les deux booléens servent à
/// afficher POURQUOI cette ligne est là — « une liste de noms sans explication ressemble à un
/// annuaire, et on ne suit pas un annuaire » (`ClubService`, à propos des suggestions de
/// personnes ; c'est le même problème).
///
/// `maintenant` est un paramètre et non `Date.now()` pris au vol : la fraîcheur d'un message est
/// la seule chose ici qui dépende de l'heure, et un test qui ne peut pas la fixer ne l'éprouve
/// pas vraiment.
function ligneSuggeree(row, maintenant = Date.now()) {
  const brut = row.dernier_message;
  const dernier = brut ? new Date(brut).getTime() : NaN;
  // `Number.isFinite` plutôt que `!= null` : une date illisible rend NaN, et NaN comparé à quoi
  // que ce soit rend `false` — donc « actif » serait faux par accident plutôt que par décision.
  const actifRecemment = Number.isFinite(dernier)
    && maintenant - dernier <= FRAICHEUR_JOURS * 24 * 60 * 60 * 1000
    && dernier <= maintenant;
  return {
    id: row.id,
    name: row.name,
    city: row.city || null,
    memberCount: row.member_count,
    seancePrevue: Boolean(row.seance_prevue),
    actifRecemment,
  };
}

module.exports = { FRAICHEUR_JOURS, MAX_SUGGESTIONS, ligneSuggeree };
