import Foundation

/// Le niveau de quelqu'un dans le Club, à partir de son XP.
///
/// # POURQUOI C'EST UN TYPE ET PLUS UNE PROPRIÉTÉ DE VUE
///
/// Ce calcul vivait dans `ClubView`, au milieu de 1 425 lignes, sous la forme d'une propriété
/// privée rendant un tuple. Il n'était donc vérifiable qu'en ouvrant l'écran du Club avec un
/// compte au bon nombre de points — c'est-à-dire jamais.
///
/// Et il porte des décisions qui méritent d'être lues : un palier de 250 points, sept titres, et
/// ce qui se passe quand on dépasse le dernier.
///
/// # LE PALIER EST UNE DÉCISION DE PRODUIT, PAS UNE CONSTANTE TECHNIQUE
///
/// 250 points par niveau. Rien ne le justifie par le calcul : c'est le rythme auquel on veut que
/// quelqu'un franchisse un palier. Il est nommé ici pour qu'on puisse le discuter, plutôt que
/// d'être un `250` au milieu d'une vue.
///
/// # AU-DELÀ DU DERNIER TITRE, ON NE S'ARRÊTE PAS DE MONTER
///
/// Les titres s'épuisent à sept ; les niveaux, non. Quelqu'un au niveau 12 reste « Élite locale »
/// et continue de voir son numéro grandir. C'était déjà le comportement — le `min(max(…))` de la
/// vue — mais il n'était écrit nulle part, et c'est exactement le genre de bord qu'un remaniement
/// transforme en plantage ou en « Premiers pas » retrouvé au niveau 12.
enum NiveauDuClub {
    /// Les points qu'il faut pour franchir un palier.
    static let xpParNiveau = 250

    /// Les titres, du premier au dernier. Le dernier vaut pour tous les niveaux au-delà.
    static var titres: [String] {
        // `String(localized:)` et pas des littéraux : ils sont composés dans une interpolation
        // — « Niveau 17 · Élite locale » — et n'atteindraient donc jamais le catalogue seuls.
        [
            String(localized: "Premiers pas"),
            String(localized: "Foulée légère"),
            String(localized: "Rythme trouvé"),
            String(localized: "Foulée d'or"),
            String(localized: "Vitesse de croisière"),
            String(localized: "Endurance de fer"),
            String(localized: "Élite locale"),
        ]
    }

    struct Palier: Equatable {
        let niveau: Int
        let titre: String
        /// Les points gagnés DANS le niveau courant, de 0 à `xpParNiveau - 1`.
        let xpDansLeNiveau: Int
        /// Les points qu'il faut pour en sortir. Constant, exposé pour la jauge.
        let xpParNiveau: Int
    }

    /// Le palier de quelqu'un, à partir de son XP total.
    ///
    /// Un XP négatif n'existe pas côté serveur, mais il arriverait ici sans rien casser si une
    /// colonne devenait nulle ou signée : il rend le niveau 1, parce qu'il n'y a pas de niveau 0
    /// et qu'une jauge négative ne se dessine pas.
    static func palier(xp: Int) -> Palier {
        let points = max(0, xp)
        let niveau = points / xpParNiveau + 1
        let titre = titres[min(max(niveau - 1, 0), titres.count - 1)]
        return Palier(niveau: niveau, titre: titre,
                      xpDansLeNiveau: points % xpParNiveau, xpParNiveau: xpParNiveau)
    }
}
