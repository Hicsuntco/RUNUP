import SwiftUI

/// Standard card surface: barely-there white fill, hairline border, generous radius. Class `.card`.
struct CardBackground: ViewModifier {
    var radius: CGFloat = RUSpacing.radiusStandard
    var fill: Color = RUColor.card

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(RUColor.line, lineWidth: RUSpacing.hairline)
            )
            // Dark mode gets its definition for free from `fill`/`line`'s contrast against the
            // near-black page background — a shadow there just looks like a muddy smear. Light
            // mode has the opposite problem: a ~3%-opacity fill on a white page is nearly
            // invisible without something to actually lift the card off the page, so it gets a
            // real (but soft) elevation shadow instead.
            .shadow(color: .black.opacity(RUColor.isLight ? 0.11 : 0), radius: 14, x: 0, y: 4)
    }
}

extension View {
    func ruCard(radius: CGFloat = RUSpacing.radiusStandard, fill: Color = RUColor.card) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }

    /// Applies the subtle rose-tinted gradient background used on "hero" cards
    /// (forme du jour, coach nudge, program summary...).
    func ruHeroCard(radius: CGFloat = RUSpacing.radiusStandard, borderOpacity: Double = 0.2) -> some View {
        self
            .background(RUColor.heroGradient, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(RUColor.rose.opacity(borderOpacity), lineWidth: RUSpacing.hairline)
            )
            .shadow(color: .black.opacity(RUColor.isLight ? 0.13 : 0), radius: 16, x: 0, y: 5)
    }
}
