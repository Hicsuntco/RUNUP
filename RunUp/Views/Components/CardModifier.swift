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
            // Deux couches serrées plutôt qu'une grande ombre diffuse — report direct de la
            // maquette (`0 1px 2px rgba(0,0,0,.04), 0 3px 8px -5px rgba(0,0,0,.08)`, l'ombre
            // ajoutée en v27 à ses 15 composants-cartes). Le flou CSS vaut environ deux fois le
            // `radius` SwiftUI, d'où 2px → 1 et 8px → 4 ; le `spread: -5px` de la seconde couche
            // n'a pas d'équivalent SwiftUI, mais il rétracte l'ombre de 5px avant de la flouter de
            // 8px, ce qui ne laisse dépasser qu'un liseré sous le bord bas : un `radius` réduit
            // reproduit ce « rentré » de près.
            //
            // L'ancienne valeur (radius 16, y 5, noir à 16%) était un tout autre objet : un halo
            // large et net, ~4× plus encré que la maquette. C'est ce qui creusait le plus l'écart
            // visuel — la maquette pose des cartes de papier posées à plat, pas des cartes qui
            // flottent.
            //
            // Mode sombre — vérifié dans la maquette avant de trancher : son bloc `.theme-dark` ne
            // redéfinit QUE des tokens de couleur (plus deux glows d'accent sur la tab bar et le
            // point « aujourd'hui ») et ne retire jamais cette ombre. Mais elle est en noir pur à
            // 4%/8%, posée sur un `--ru-bg` de #0E0E14 : à ces valeurs elle ne rend strictement
            // rien sur un fond quasi noir. Autrement dit la maquette DÉCLARE l'ombre dans les deux
            // thèmes mais n'en AFFICHE qu'en clair — ce que le 0 explicite ci-dessous produit
            // déjà. Le choix existant est donc conservé : il donne le même rendu, en évitant de
            // composer une passe d'ombre inutile à chaque carte.
            // Seconde couche relevée (0,08 / rayon 4 → 0,10 / rayon 6, un point plus bas) en
            // même temps que le fond de page s'est assombri : les deux vont ensemble. L'ombre
            // reste rentrée sous le bord bas plutôt qu'étalée en halo — c'est ce qui distingue
            // une carte posée d'une carte qui flotte.
            .shadow(color: .black.opacity(RUColor.isLight ? 0.05 : 0), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(RUColor.isLight ? 0.10 : 0), radius: 6, x: 0, y: 4)
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
            // Exactement la même ombre que `ruCard()` — et surtout pas une ombre PLUS marquée.
            // L'ancienne (radius 18, y 6, 18%) faisait flotter les cartes teintées au-dessus des
            // cartes neutres ; la maquette fait l'inverse : ses cartes teintées (`.pr-banner`,
            // `.milestone-banner`, `.social-card`, `.insight-line`, `.coach-caption-card`) n'ont
            // aucune ombre du tout, et celles qui en ont (`.sesh.active`, `.challenge-card
            // .coach-tint`) héritent simplement de l'ombre neutre de leur famille. Une teinte se
            // distingue par sa couleur de fond et son contour teinté, jamais par plus d'élévation.
            // Seconde couche relevée (0,08 / rayon 4 → 0,10 / rayon 6, un point plus bas) en
            // même temps que le fond de page s'est assombri : les deux vont ensemble. L'ombre
            // reste rentrée sous le bord bas plutôt qu'étalée en halo — c'est ce qui distingue
            // une carte posée d'une carte qui flotte.
            .shadow(color: .black.opacity(RUColor.isLight ? 0.05 : 0), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(RUColor.isLight ? 0.10 : 0), radius: 6, x: 0, y: 4)
    }
}
