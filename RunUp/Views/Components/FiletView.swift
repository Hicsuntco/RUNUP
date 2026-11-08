import SwiftUI

/// LE FILET QUI SÉPARE DEUX LIGNES, ÉCRIT UNE FOIS.
///
/// Il l'était deux fois, et les deux ne dessinaient pas la même chose.
///
/// Trente endroits écrivaient `Divider().background(RUColor.line)`. Ce n'est pas un filet de
/// la maquette : le `Divider` de SwiftUI a SA PROPRE épaisseur — un pixel de l'écran, soit un
/// tiers de point sur un appareil ×3 — et sa propre couleur, un gris système. `.background`
/// ne le recolore pas, elle peint DERRIÈRE lui. Le résultat est un trait trois fois plus fin
/// que celui du système de dessin, dans une couleur qui n'est pas tout à fait `line`.
///
/// Douze autres écrivaient `Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)`,
/// qui est le bon filet — et qui tient sur une ligne qu'on ne relit pas, donc qu'on recopie.
///
/// `RUSpacing.hairline` vaut 1 point et non 0,5 : c'est un choix documenté dans `Spacing.swift`
/// — la maquette trace `1px solid var(--ru-line)` partout, sans exception. Un filet qui vaut
/// un tiers de point contredit ce choix sans jamais le dire.
///
/// L'orientation n'est pas devinée. Le `Divider` de SwiftUI, lui, la devine : vertical dans un
/// `HStack`, horizontal ailleurs. C'est commode et c'est un piège — déplacer un bloc d'une pile
/// à l'autre fait pivoter le trait sans que rien ne change dans le code. Ici on la nomme, et
/// `.horizontal` est la valeur par défaut parce que c'est le cas des quarante usages sur
/// quarante-deux.
struct RUFilet: View {
    enum Sens {
        /// Un trait qui sépare deux LIGNES : il prend la largeur offerte, il fait un point de haut.
        case horizontal
        /// Un trait qui sépare deux COLONNES : il prend la hauteur offerte, il fait un point de large.
        case vertical
    }

    private let sens: Sens

    init(_ sens: Sens = .horizontal) {
        self.sens = sens
    }

    var body: some View {
        Rectangle()
            .fill(RUColor.line)
            // Une seule dimension est fixée ; l'autre reste `nil`, donc la vue prend ce que la
            // pile lui offre. Fixer les deux donnerait un trait d'un point sur un point.
            .frame(width: sens == .vertical ? RUSpacing.hairline : nil,
                   height: sens == .horizontal ? RUSpacing.hairline : nil)
            // UN FILET N'EST PAS UNE INFORMATION. VoiceOver annonçait trente « séparateur » sur
            // l'écran des réglages — un par ligne — entre deux libellés qui, eux, disent quelque
            // chose. Le `Divider` de SwiftUI est annoncé ; un `Rectangle` ne l'est pas, et les
            // douze endroits qui l'employaient étaient donc déjà muets. Le dire ici rend les
            // quarante-deux pareils, dans le bon sens.
            .accessibilityHidden(true)
    }
}
