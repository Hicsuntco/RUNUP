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
    /// LE GESTE PRINCIPAL D'UNE FEUILLE, ÉPINGLÉ EN BAS.
    ///
    /// # CE QU'IL REMPLACE
    ///
    /// Sept feuilles gardaient leur bouton principal comme DERNIÈRE VUE de leur défilement. Elles
    /// ne touchent plus le bord depuis que `runUpSheetStyle` donne son encart à tout le monde,
    /// mais il faut toujours faire défiler pour atteindre le seul geste pour lequel la feuille
    /// est ouverte — « Démarrer », « Publier », « Enregistrer ». Sur une feuille longue, l'action
    /// est hors écran à l'ouverture.
    ///
    /// # POURQUOI UN MODIFICATEUR ET PAS SEPT COPIES
    ///
    /// Le filet, le fond, les trois marges : écrits sept fois, ils auraient divergé sept fois —
    /// c'est exactement ce que l'inventaire des encarts du bas vient de montrer, avec ses six
    /// valeurs pour une seule question. Ici, un seul endroit à régler.
    ///
    /// Le filet n'est pas décoratif : sans lui, le contenu qui passe sous la barre semble
    /// s'arrêter là. Avec lui, on voit qu'il continue dessous.
    ///
    /// La feuille qui l'emploie doit se déclarer : `runUpSheetStyle(gereSonBas: true)`, sans quoi
    /// elle reçoit un SECOND encart sous cette barre et la décolle du bord pour rien.
    func ruBarreDuBas<Contenu: View>(@ViewBuilder _ contenu: () -> Contenu) -> some View {
        safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                contenu()
                    .padding(.horizontal, RUSpacing.pagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
            }
            .background(RUColor.bg)
        }
    }

    func runUpSheetStyle(detents: Set<PresentationDetent> = [.medium, .large],
                         gereSonBas: Bool = false) -> some View {
        modifier(RunUpSheetModifier(detents: detents, gereSonBas: gereSonBas))
    }
}
