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

    static let hairline: CGFloat = 0.5

    static let tabBarHeight: CGFloat = 64
    static let tabBarBottomInset: CGFloat = 18
    static let tabBarSideInset: CGFloat = 17
}
