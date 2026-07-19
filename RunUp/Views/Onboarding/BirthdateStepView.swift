import SwiftUI

struct BirthdateStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            Spacer()
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

            VStack(alignment: .leading, spacing: 0) {
                // Only ever used to decide whether to offer cycle-tracking further along —
                // adapting the plan around it, never gating any feature behind it.
                EyebrowLabel(text: "Tu es", color: RUColor.text3).padding(.top, 24).padding(.bottom, 10)
                ChipFlowLayout {
                    ForEach([("female", "Femme"), ("male", "Homme"), ("unspecified", "Je préfère ne pas dire")], id: \.0) { id, label in
                        SelectableChip(label: label, selected: vm.sex == id) { vm.sex = id }
                    }
                }
            }
            Spacer()
            ObNext(disabled: !vm.canProceed(fromStep: 1), action: onNext)
        }
    }

    private var defaultDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    }
}
