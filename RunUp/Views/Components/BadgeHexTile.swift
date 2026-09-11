import SwiftUI

/// L'hexagone d'un badge — surface, contour, emoji, état débloqué.
///
/// Il existait en TROIS COPIES identiques au caractère près : deux dans le Club, une dans le
/// Profil. C'est l'audit qui les a comptées, en constatant qu'un même défaut — une couleur
/// d'accent noyée à 22 % dans la surface, donc du brun pour l'ambre et de l'olive pour le lime —
/// devait être corrigé trois fois. Il l'a été, mais laisser trois copies revient à parier que la
/// prochaine correction les trouvera toutes.
///
/// LA COULEUR EST AU CONTOUR, ENTIÈRE. C'est la règle du dépôt : un accent ne se dilue pas. La
/// surface est neutre pour tout le monde, et « débloqué » se lit à trois signes qui ne dépendent
/// d'aucune teinte — le contour vif, l'opacité pleine, l'emoji net.
struct BadgeHexTile: View {
    let emoji: String
    let earned: Bool
    let color: Color
    /// Le côté, quand l'appelant en impose un. Sinon la tuile prend la place qu'on lui donne et
    /// reste carrée — c'est ce dont une grille a besoin pour aligner ses colonnes.
    var side: CGFloat? = nil
    var emojiSize: CGFloat = 26
    /// Un badge verrouillé s'efface, sans disparaître : on doit pouvoir lire ce qui reste à faire.
    var lockedOpacity: Double = 0.35

    var body: some View {
        HexagonBadgeShape()
            .fill(RUColor.card2)
            .overlay(HexagonBadgeShape().stroke(earned ? color : RUColor.line,
                                                lineWidth: RUSpacing.hairline))
            .modifier(TailleHexagone(side: side))
            .overlay(Text(emoji).font(.system(size: emojiSize)))
            .opacity(earned ? 1 : lockedOpacity)
    }
}

/// `frame` fixe ou rapport carré, selon que l'appelant impose un côté. Écrit en modificateur
/// plutôt qu'en `if` dans le corps : un `if` produirait deux vues d'identité différente, et
/// l'animation d'apparition d'une grille sauterait au premier changement d'état.
private struct TailleHexagone: ViewModifier {
    let side: CGFloat?

    func body(content: Content) -> some View {
        if let side {
            content.frame(width: side, height: side)
        } else {
            content.aspectRatio(1, contentMode: .fit)
        }
    }
}
