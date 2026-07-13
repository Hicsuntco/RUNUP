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
    }
}
