import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ObCorps {
                VStack(alignment: .leading, spacing: 0) {
                    ObTitle(eyebrow: "Pour commencer", title: "C'EST QUOI\nTON PRÉNOM ?", subtitle: "Ton coach va s'adresser à toi — autant se présenter.")
                    ObTextField(placeholder: "Prénom", text: $vm.name)
                        .padding(.top, 22)
                }
            }
            ObNext(disabled: !vm.peutContinuer, action: onNext)
        }
    }
}
