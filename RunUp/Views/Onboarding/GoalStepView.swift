import SwiftUI

struct GoalStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ObTitle(eyebrow: "Étape 2 · \(vm.name.isEmpty ? "toi" : vm.name)", title: "POURQUOI TU COURS ?", subtitle: "C'est la base de tout ton programme.")
            VStack(spacing: 8) {
                ForEach(GoalType.allCases) { goal in
                    SelectableCard(
                        selected: vm.goal == goal,
                        emoji: goal.emoji,
                        title: goal.title,
                        subtitle: goal.subtitle
                    ) {
                        vm.goal = goal
                    }
                }
            }
            .padding(.top, 20)
            Spacer()
            ObNext(disabled: !vm.canProceed(fromStep: 2), action: onNext)
        }
    }
}

/// Selectable card row used for goal/level/new-goal pickers — mirrors the goal-card style
/// repeated across onboarding.jsx and screensD.jsx.
struct SelectableCard: View {
    var selected: Bool
    var emoji: String?
    var title: String
    var subtitle: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                if let emoji {
                    Text(emoji).font(.system(size: 24))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RUFont.sans(15, weight: .semibold)).foregroundColor(.white)
                    if let subtitle {
                        Text(subtitle).font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).lineSpacing(2)
                    }
                }
                Spacer()
                Circle()
                    .strokeBorder(selected ? RUColor.rose : Color.white.opacity(0.2), lineWidth: 2)
                    .background(Circle().fill(selected ? RUColor.rose : .clear))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Group { if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white) } }
                    )
            }
            .padding(15)
            .background(selected ? RUColor.rose.opacity(0.12) : RUColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? RUColor.rose.opacity(0.4) : RUColor.line, lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
    }
}
