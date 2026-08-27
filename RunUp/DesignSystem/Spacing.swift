import CoreGraphics

/// Spacing / shape tokens — see README § Spacing / Shape.
enum RUSpacing {
    static let pagePadding: CGFloat = 18

    static let radiusStandard: CGFloat = 18
    static let radiusCompact: CGFloat = 14
    static let radiusPill: CGFloat = 99
    /// A deliberately larger radius for a handful of always-dark "trophy" cards that keep their
    /// own fixed gradient in both themes (Club's level card) rather than routing through
    /// `.ruCard()`/`.ruHeroCard()`'s theme-aware fill — named here instead of a bare `20` so it
    /// reads as an intentional third size, not a stray one-off.
    static let radiusHero: CGFloat = 20

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

    /// 56 et non plus 64, et l'encoche du bas 12 au lieu de 18 : la barre occupait 82 pt en
    /// bas de chaque écran, pour cinq cibles de 44.
    static let tabBarHeight: CGFloat = 56
    static let tabBarBottomInset: CGFloat = 12
    static let tabBarSideInset: CGFloat = 17
}
