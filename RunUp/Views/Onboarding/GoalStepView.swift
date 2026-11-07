import SwiftUI

struct GoalStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        let who = vm.name.isEmpty ? String(localized: "toi") : vm.name
        return ObScreen {
            ScrollView {
                ObTitle(eyebrow: String(localized: "Étape 2 · \(who)"), title: "POURQUOI TU COURS ?", subtitle: "C'est la base de tout ton programme.")
                VStack(spacing: 8) {
                    ForEach(GoalType.allCases.filter(\.estProposable)) { goal in
                        SelectableCard(
                            selected: vm.goal == goal,
                            symbole: goal.symbole,
                            teinte: goal.tint,
                            title: goal.title,
                            subtitle: goal.subtitle
                        ) {
                            vm.goal = goal
                        }
                    }
                }
                .padding(.top, 18)
            }
            ObNext(disabled: !vm.peutContinuer, action: onNext)
        }
    }
}

/// Selectable card row used for goal/level/new-goal pickers — mirrors the goal-card style
/// repeated across onboarding.jsx and screensD.jsx.
struct SelectableCard: View {
    var selected: Bool
    /// Un nom de symbole SF, jamais un emoji — voir `GoalType.symbole`. `nil` pour les cartes qui
    /// n'ont rien à illustrer (le choix du niveau, par exemple).
    var symbole: String?
    /// La teinte du symbole. Par défaut l'accent : une carte sans objectif n'a pas de couleur
    /// propre, et c'est l'appelant qui la connaît quand elle existe.
    var teinte: Color = RUColor.rose2
    var title: String
    var subtitle: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                if let symbole {
                    Image(systemName: symbole)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(teinte)
                        // La même largeur pour les neuf : un drapeau et une balance n'ont pas la
                        // même empreinte, et sans cadre fixe les neuf titres ne s'alignent pas.
                        .frame(width: 26)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RUFont.sans(.emphasis, weight: .bold)).foregroundColor(RUColor.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(2)
                    }
                }
                Spacer()
                Circle()
                    .strokeBorder(selected ? RUColor.rose : RUColor.line, lineWidth: 2)
                    .background(Circle().fill(selected ? RUColor.rose : .clear))
                    .frame(width: 20, height: 20)
                    // Le rond passe de vide à plein : la coche par-dessus répétait la même chose
                    // dans dix points de côté, à l'endroit où elle est le moins lisible.
            }
            .padding(14)
            .background(selected ? RUColor.card2 : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous).stroke(selected ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
            .animation(.easeOut(duration: 0.15), value: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
