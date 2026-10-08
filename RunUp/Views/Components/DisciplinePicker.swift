import SwiftUI

/// Le petit panneau qui s'ouvre au-dessus du bouton RUN pour choisir la discipline.
///
/// # POURQUOI UN PANNEAU PLUTÔT QU'UNE BASCULE
///
/// L'appui long faisait tourner la discipline directement sur le bouton : course → vélo → trail →
/// course. Ça marchait, et ça ne tient plus à trois. Il faut maintenir deux fois pour atteindre le
/// trail, à l'aveugle, sans savoir ce qui vient — un geste qu'on apprend par cœur au lieu de le
/// lire. Un panneau montre les trois choix d'un coup, dit lequel est actif, et un appui suffit.
///
/// # CE QUI N'EST PAS UN `Menu` NI UN `.popover`
///
/// `Menu` apporte son propre geste d'ouverture, qui se disputerait l'appui long avec celui du
/// bouton — c'est exactement le conflit `Button` + `.onLongPressGesture` qu'on vient de défaire.
/// `.popover` sur iPhone s'adapte en feuille modale sauf à lui passer
/// `.presentationCompactAdaptation(.popover)`, et il arrive avec son chrome système : une flèche,
/// un fond, des marges qui ne sont pas celles de l'app.
///
/// Une vue ordinaire posée dans la pile de `RootTabView`, comme `RunInProgressPill` juste à côté,
/// coûte moins et rend exactement ce que la maquette demande.
struct DisciplinePicker: View {
    var selection: Discipline
    var onSelect: (Discipline) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Discipline.allCases, id: \.self) { discipline in
                choix(discipline)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        .background(RUColor.card.opacity(RUColor.isLight ? 0.96 : 0.82), in: Capsule())
        .overlay(Capsule().stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        // La même ombre que la barre d'onglets : les deux flottent au même étage, à quatorze
        // points l'un de l'autre. Deux élévations différentes se verraient.
        .shadow(color: .black.opacity(RUColor.isLight ? 0.10 : 0.5), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choisir la discipline")
    }

    private func choix(_ discipline: Discipline) -> some View {
        let actif = discipline == selection
        return Button {
            Haptics.selection()
            onSelect(discipline)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: discipline.sfSymbol)
                    .font(.system(size: 17, weight: actif ? .semibold : .regular))
                Text(discipline.tabLabel)
                    .font(RUFont.sans(.micro, weight: .bold))
                    .tracking(1)
            }
            // `onRose` sur le choix actif, et donc le dégradé d'accent derrière : c'est le même
            // couple que le rond du bouton RUN, à quatorze points en dessous. Le panneau se lit
            // comme une extension de ce bouton, pas comme un composant venu d'ailleurs.
            .foregroundColor(actif ? RUColor.onRose : RUColor.text2)
            .frame(width: 64)
            .frame(minHeight: 44)
            .background {
                if actif {
                    Capsule().fill(LinearGradient(colors: [RUColor.rose2, RUColor.rose],
                                                  startPoint: .top, endPoint: .bottom))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        // Le choix ACTIF s'annonce par son nom — « Course » — et le trait `isSelected` dit qu'il
        // l'est déjà. Les autres s'annoncent par ce qu'ils FONT : « Passer au vélo ». Dire
        // « Passer à la course » sur la ligne déjà active serait une instruction sans effet.
        .accessibilityLabel(actif ? discipline.title : discipline.switchToLabel)
        // Deux appels, comme sur les onglets juste à côté : un ternaire qui rend un jeu de traits
        // d'un côté et un seul de l'autre est une inférence dont on n'a pas besoin.
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }
}
