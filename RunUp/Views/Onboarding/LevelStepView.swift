import SwiftUI

struct LevelStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            Spacer()
            ObTitle(eyebrow: "Étape 5 · ton niveau", title: "OÙ TU EN ES ?")
            VStack(spacing: 8) {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    SelectableCard(selected: vm.level == level, emoji: nil, title: level.title, subtitle: level.subtitle) {
                        vm.level = level
                    }
                }
            }
            .padding(.top, 20)
            Spacer()
            ObNext(label: "SUIVANT", action: onNext)
        }
    }
}
