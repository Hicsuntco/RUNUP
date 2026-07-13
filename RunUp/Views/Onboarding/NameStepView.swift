import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                EyebrowLabel(text: "Pour commencer", color: RUColor.rose)
                Text("C'EST QUOI\nTON PRÉNOM ?")
                    .displayStyle(32)
                    .foregroundColor(.white)
                    .lineSpacing(-2)
                    .padding(.top, 8)
                Text("Ton coach va s'adresser à toi — autant se présenter.")
                    .font(RUFont.sans(13))
                    .foregroundColor(RUColor.text2)
                    .padding(.top, 12)
                ObTextField(placeholder: "Léa", text: $vm.name)
                    .padding(.top, 22)
                Spacer()
                Spacer()
            }
            ObNext(disabled: !vm.canProceed(fromStep: 0), action: onNext)
        }
    }
}
