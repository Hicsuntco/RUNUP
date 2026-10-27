import SwiftUI

/// Consistent styling for the app's bottom sheets (session detail, program settings,
/// notifications, debrief): dark backdrop, drag handle, dark sheet background.
/// Uses native `.sheet` + `.presentationDetents` rather than a hand-rolled overlay —
/// this gives free drag-to-dismiss, backdrop-tap-to-dismiss and safe-area handling.
struct RunUpSheetModifier: ViewModifier {
    var detents: Set<PresentationDetent> = [.medium, .large]
    /// CETTE FEUILLE POSE ELLE-MÊME QUELQUE CHOSE EN BAS, et gère donc son propre encart.
    ///
    /// Trois le font : le bilan et le paywall épinglent leur bouton principal par un
    /// `safeAreaInset`, la feuille de commentaires garde son champ d'écriture collé en bas. Pour
    /// celles-là, l'encart ci-dessous serait un second encart posé SOUS le premier — il
    /// décollerait leur barre du bord pour rien, et la feuille de commentaires finirait avec son
    /// champ de saisie flottant à quarante-quatre points du vide.
    var gereSonBas: Bool = false

    func body(content: Content) -> some View {
        // L'ENCART EN BAS, POSÉ UNE FOIS POUR TOUTES PLUTÔT QUE VINGT-CINQ FOIS À LA MAIN.
        //
        // Voir `RUSpacing.sheetBottomInset` pour ce que valait cette valeur avant : six nombres
        // différents, et dix feuilles sans rien. Ici, elle est la même partout et il n'y a plus
        // qu'un endroit où la changer.
        //
        // `safeAreaInset` et non un `padding` : il s'applique à la vue entière, quelle que soit
        // la façon dont chaque feuille s'est construite — pile, défilement, `NavigationStack` —
        // là où un padding devrait être posé à la main au bon niveau dans chacune.
        Group {
            if gereSonBas {
                content
            } else {
                content.safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: RUSpacing.sheetBottomInset)
                }
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(RUColor.bg)
        .presentationCornerRadius(26)
    }
}

extension View {
    func runUpSheetStyle(detents: Set<PresentationDetent> = [.medium, .large],
                         gereSonBas: Bool = false) -> some View {
        modifier(RunUpSheetModifier(detents: detents, gereSonBas: gereSonBas))
    }
}
