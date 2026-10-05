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
                    .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline)
            )
            // ── PLUS D'OMBRE PORTÉE ──────────────────────────────────────────────────────────
            //
            // Elle n'existait qu'en clair : les deux couches sont à opacité ZÉRO en sombre, où
            // c'est l'écart de luminosité qui sépare. Une app dont la moitié des thèmes se passe
            // d'ombre n'a pas besoin d'ombre — elle a besoin de ce que l'ombre remplaçait.
            //
            // Sur du papier, une ombre portée empile du gris sur un fond déjà gris. Ce qui sépare
            // une feuille blanche d'une table, ce n'est pas le flou sous ses bords, c'est son
            // BORD. `cardBorder` le dessine, et il monte de 5 à 10 % en même temps que l'ombre
            // part — les deux changements n'ont de sens qu'ensemble.
            //
            // Au passage : deux passes de composition en moins par carte, sur des écrans qui en
            // affichent cinq.
    }
}

extension View {
    func ruCard(radius: CGFloat = RUSpacing.radiusStandard, fill: Color = RUColor.card) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }

    /// Applies the subtle rose-tinted gradient background used on "hero" cards
    /// (forme du jour, coach nudge, program summary...).
    func ruHeroCard(radius: CGFloat = RUSpacing.radiusStandard, borderOpacity _: Double = 0.2) -> some View {
        self
            .background(RUColor.heroGradient, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            // LE CONTOUR TOMBE. C'était un accent dilué — 20 %, et jusqu'à 28 % chez certains
            // appelants — posé dans le système de design lui-même, donc répété sur les onze
            // cartes héros. La carte se distingue déjà par son dégradé ; en thème sombre,
            // `cardBorder` vaut d'ailleurs `.clear` pour exactement cette raison.
            //
            // `borderOpacity` reste au paramètre pour ne pas casser les appelants qui le passent,
            // et il est désormais sans effet : le supprimer partout est un autre commit.
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline)
            )
            // ── PLUS D'OMBRE PORTÉE ──────────────────────────────────────────────────────────
            //
            // Elle n'existait qu'en clair : les deux couches sont à opacité ZÉRO en sombre, où
            // c'est l'écart de luminosité qui sépare. Une app dont la moitié des thèmes se passe
            // d'ombre n'a pas besoin d'ombre — elle a besoin de ce que l'ombre remplaçait.
            //
            // Sur du papier, une ombre portée empile du gris sur un fond déjà gris. Ce qui sépare
            // une feuille blanche d'une table, ce n'est pas le flou sous ses bords, c'est son
            // BORD. `cardBorder` le dessine, et il monte de 5 à 10 % en même temps que l'ombre
            // part — les deux changements n'ont de sens qu'ensemble.
            //
            // Au passage : deux passes de composition en moins par carte, sur des écrans qui en
            // affichent cinq.
    }
}
