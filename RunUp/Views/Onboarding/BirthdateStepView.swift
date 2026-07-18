import SwiftUI

struct BirthdateStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ObTitle(
                eyebrow: "Étape 1 · \(vm.name.isEmpty ? "toi" : vm.name)",
                title: "TA DATE DE NAISSANCE ?",
                subtitle: "Ça aide ton coach à mieux te connaître."
            )
            VStack(alignment: .leading, spacing: 12) {
                DatePicker(
                    "",
                    selection: Binding(get: { vm.birthdate ?? defaultDate }, set: { vm.birthdate = $0 }),
                    in: Date(timeIntervalSince1970: -1_262_304_000)...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .padding(14)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))

                if let age = vm.age {
                    Text("\(age) ans").font(RUFont.sans(13)).foregroundColor(RUColor.text2)
                }
            }
            .padding(.top, 22)
            Spacer()
            ObNext(disabled: !vm.canProceed(fromStep: 1), action: onNext)
        }
    }

    private var defaultDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    }
}
