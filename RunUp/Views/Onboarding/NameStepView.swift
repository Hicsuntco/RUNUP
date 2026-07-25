import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                ObTitle(eyebrow: "Pour commencer", title: "C'EST QUOI\nTON PRÉNOM ?", subtitle: "Ton coach va s'adresser à toi — autant se présenter.")
                ObTextField(placeholder: "Prénom", text: $vm.name)
                    .padding(.top, 22)
                Spacer()
            }
            ObNext(disabled: !vm.canProceed(fromStep: 0), action: onNext)
        }
    }
}
