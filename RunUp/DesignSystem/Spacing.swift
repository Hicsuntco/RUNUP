import CoreGraphics

/// Spacing / shape tokens — see README § Spacing / Shape.
enum RUSpacing {
    static let pagePadding: CGFloat = 18

    // ── La grille d'espacement ────────────────────────────────────────────────────────────────
    //
    // Il y avait DIX-NEUF écarts verticaux distincts, continus de 0 à 22 sans un seul trou, et
    // trente-trois valeurs de marge. Le défaut ne tenait pas au nombre mais à ce que les voisines
    // disaient : 8 était employé 100 fois et 9 huit fois ; 10 cent trente-trois fois et 11 deux
    // fois ; 12 quatre-vingt-treize fois et 13 deux fois. Une valeur à un point d'une valeur
    // dominante n'est pas une décision — c'est un écran réglé à l'œil, séparément, puis recopié.
    // Et c'est précisément ce qui fait qu'une app a l'air cousue main au mauvais sens : rien ne
    // s'aligne d'un bloc à l'autre, sans qu'on puisse dire où.
    //
    // La grille ci-dessous est un pas de 2 jusqu'à 14, puis 18 — la marge de page, pour qu'un
    // écart de section fasse écho au bord de l'écran — puis 24.
    //
    // 409 appels ont rejoint leur voisine, chacun d'au plus 2 points : les impairs (1, 3, 5, 7, 9,
    // 11, 13, 15) et les trois valeurs hautes qui faisaient quatre jetons pour un seul rôle
    // (16, 20, 22 → 18 ou 24). Les 2 points sont le plafond du déplacement, pas une moyenne : au
    // dessus de 14, deux points ne se voient pas, et c'est bien pour ça que quatre valeurs y
    // cohabitaient sans que personne tranche.
    //
    // CE QUI RESTE HORS GRILLE, ET POURQUOI : tout ce qui dépasse 24. Ce ne sont plus des écarts
    // de rythme mais des hauteurs réservées — les 130 points qu'un défilement garde sous la barre
    // d'onglets, les encarts de feuille. Les régler sur une grille de rythme n'aurait aucun sens :
    // ils répondent à la taille d'un objet, pas à celle d'un blanc.
    //
    // `ci_scripts/check_grille.py` LIT LE TABLEAU CI-DESSOUS. C'est sa seule raison d'exister en
    // tant que valeur Swift : elle n'est appelée par aucune vue, elle est la déclaration que le
    // garde-fou compare au code. Ajouter une valeur ici la rend légale partout — donc c'est ici,
    // et pas dans le script, qu'on assume de rouvrir la grille.
    static let grille: [CGFloat] = [0, 2, 4, 6, 8, 10, 12, 14, 18, 24]

    // ── Rayons ────────────────────────────────────────────────────────────────────────────────
    //
    // Il y avait quatre jetons et CENT TRENTE-CINQ nombres écrits à la main, sur dix valeurs
    // distinctes. Treize appels seulement passaient par un jeton.
    //
    // Les valeurs ci-dessous sont exactement celles déjà employées, une par famille de forme :
    // remplacer un littéral par son jeton ne déplace donc aucun pixel. Réduire ensuite dix
    // valeurs à cinq est une décision de design visible, séparée de ce rangement — la même
    // distinction que pour l'échelle typographique, et pour la même raison : on ne modifie pas
    // en douce une app qui vient d'être validée sous prétexte de la ranger.
    //
    // Ce que le rangement apporte : la forme des cartes se règle ici, pas dans 135 fichiers.
    //
    // ── Et c'est ce qui a permis de les relever d'un cran ────────────────────────────────────
    // 14 → 18 pour la carte courante, 18 → 22 pour celle de premier plan, et le reste à
    // l'avenant. Les quatre références apportées ont toutes des angles nettement plus doux que
    // ce que l'app avait ; à 14 pt sur un écran de 393, une carte lit « boîte », à 18 elle lit
    // « surface ». C'est le changement le moins risqué du lot — un rayon ne déplace aucun
    // contenu, il ne fait que retailler le coin — et l'un des plus visibles.
    //
    // Sans le rangement d'abord, c'était 135 nombres à retrouver un par un.
    //
    // ── Et relevés d'un cran de plus ─────────────────────────────────────────────────────────
    // 18 → 22, 22 → 26, 20 → 24, 14 → 16. Même raisonnement qu'au tour précédent, poussé d'un
    // cran : à 18 pt une carte lisait « surface », à 22 elle lit « objet posé ». C'est le geste
    // le moins risqué d'une refonte visuelle — un rayon ne déplace aucun contenu, il ne fait que
    // retailler le coin — et il se voit sur les trente écrans à la fois.
    //
    // Les petites formes ne bougent PAS : une pastille de 10 pt arrondie à 14 devient une gélule,
    // et une jauge de 2 pt n'a pas de coin à adoucir. L'adoucissement vaut pour ce qui a la
    // surface de le porter.

    /// 2 — jauges et barres de progression fines.
    static let radiusBar: CGFloat = 2
    /// 6 — petites jauges, curseurs.
    static let radiusMicro: CGFloat = 6
    /// 10 — pastilles d'icône, tuiles de jour.
    static let radiusTile: CGFloat = 10
    /// 12 — vignettes, pastilles d'icône plus grandes.
    static let radiusChip: CGFloat = 12
    /// 16 — sous-surfaces dans une carte, champs de saisie.
    static let radiusInner: CGFloat = 16
    /// 22 — la carte courante. La valeur la plus employée de l'app, et de loin.
    static let radiusCompact: CGFloat = 22
    /// 24 — cartes qui portent un contenu large (grilles, feuilles).
    static let radiusLarge: CGFloat = 24
    /// 26 — la carte de premier plan.
    static let radiusStandard: CGFloat = 26
    static let radiusPill: CGFloat = 99
    /// A deliberately larger radius for a handful of always-dark "trophy" cards that keep their
    /// own fixed gradient in both themes (Club's level card) rather than routing through
    /// `.ruCard()`/`.ruHeroCard()`'s theme-aware fill — named here instead of a bare `20` so it
    /// reads as an intentional third size, not a stray one-off.
    static let radiusHero: CGFloat = 24

    /// Padding intérieur d'une carte standard. La maquette ne l'uniformise pas — ses cartes vont de
    /// 7px (`.activity-tile`, une tuile de grille) à 14px (`.session-card`, la carte héro) — mais
    /// le gros du fichier (`.feed-card`, `.link-card`, `.chartcard`, `.suggest-card`,
    /// `.stat-quicklink`) se regroupe autour de 10–12px. À l'échelle de la maquette (le gabarit
    /// téléphone fait 268px de large pour ~393pt réels, soit ×1,25–1,3), cela donne ~13–15pt : 14
    /// tombe au milieu et reste dans le rythme pair du reste des tokens. Les cartes plus denses
    /// (lignes d'historique, tuiles de grille) descendent légitimement en dessous — ce token est le
    /// défaut à prendre quand rien ne justifie autre chose, pas une valeur imposée.
    static let cardPadding: CGFloat = 14

    /// Épaisseur de TOUS les contours et séparateurs de l'app (voir `RUColor.line`).
    ///
    /// Valeur précédente : 0,5 — l'idiome « hairline » iOS. La maquette, elle, trace `1px solid
    /// var(--ru-line)` partout, sans exception : contours de cartes, de pastilles, de boutons, ET
    /// séparateurs de listes (`.feed-row`, `.lb-row`, `.mcard + .mcard`…). Proportionnellement
    /// c'est encore plus large que 1pt — 1px sur un gabarit de 268px de large qui représente ~393pt
    /// vaut ~1,47pt — donc 1 est déjà le report conservateur, pas une surenchère.
    ///
    /// Ce n'est pas un détail cosmétique isolé : en mode clair, `card` (#F0F0F6) se détache à peine
    /// de `bg` (#FFFFFF), et c'est le contour qui dessine réellement la carte. Comme l'ombre passe
    /// en même temps de `radius 16 / 16%` à l'ombre serrée de la maquette (voir `CardModifier`),
    /// garder un trait de 0,5pt aurait fait disparaître les cartes claires au lieu de les
    /// rapprocher de la maquette : les deux valeurs se tiennent, et la maquette obtient sa
    /// définition du contour, pas de l'élévation.
    static let hairline: CGFloat = 1

    /// CE QUE CHAQUE FEUILLE RÉSERVE EN BAS, ET POURQUOI ELLE NE LE DÉCIDE PLUS ELLE-MÊME.
    ///
    /// Les vingt-cinq feuilles de l'app avaient chacune inventé sa valeur : 44 dans le détail
    /// d'une séance, 40 dans les réglages et la connexion, 28 dans les quatre feuilles de jour
    /// de course, 26 dans les réglages du programme, 24 dans le bilan, 2 dans le changement de
    /// compte — et RIEN du tout dans dix autres. Ce n'est pas une variété de styles, c'est une
    /// question à laquelle personne n'a répondu deux fois pareil.
    ///
    /// Et la plus répandue des réponses était fausse : le bilan avait 24, et son bouton touchait
    /// quand même le bas de l'écran. Une feuille présentée en grand descend sous l'indicateur
    /// d'accueil, qui mesure 34 points à lui seul.
    ///
    /// 44 = les 34 de l'indicateur, plus dix points d'air. En dessous, le dernier élément se lit
    /// comme coupé par le bord plutôt que posé avant lui.
    static let sheetBottomInset: CGFloat = 44

    /// 56 et non plus 64, et l'encoche du bas 12 au lieu de 18 : la barre occupait 82 pt en
    /// bas de chaque écran, pour cinq cibles de 44.
    static let tabBarHeight: CGFloat = 56
    static let tabBarBottomInset: CGFloat = 12
    static let tabBarSideInset: CGFloat = 17
}
