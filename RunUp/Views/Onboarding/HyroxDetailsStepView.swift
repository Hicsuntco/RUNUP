import SwiftUI

/// Step 3 for the "HYROX" goal: division → target finish time → event date. Mirrors
/// `RaceDetailsStepView`'s shape, but HYROX has a fixed race format (8 × 1 km + 8 functional
/// stations) instead of a distance to pick — the real choice is Open vs Pro and a target time.
struct HyroxDetailsStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ScrollView {
                ObTitle(eyebrow: "Étape 3 · ton HYROX", title: "QUEL HYROX ?", subtitle: "8 × 1 km de course, 8 stations fonctionnelles — le format ne change pas, ta préparation si.")

                EyebrowLabel(text: "Division", color: RUColor.text3)
                    .padding(.top, 20).padding(.bottom, 10)
                VStack(spacing: 8) {
                    ForEach(HyroxDivision.allCases) { d in
                        SelectableCard(selected: vm.hyroxDivision == d, emoji: nil, title: d.title, subtitle: d.subtitle) {
                            vm.hyroxDivision = d
                        }
                    }
                }

                EyebrowLabel(text: "Ton objectif chrono", color: RUColor.text3)
                    .padding(.top, 22).padding(.bottom, 10)
                ChipFlowLayout {
                    ForEach(["Sous 1h15", "Sous 1h30", "Sous 1h45"], id: \.self) { t in
                        SelectableChip(label: t, selected: vm.chrono == t && !vm.isCustomChrono) {
                            vm.chrono = t; vm.isCustomChrono = false
                        }
                    }
                    SelectableChip(label: "Juste finir 😅", selected: vm.chrono == "finir" && !vm.isCustomChrono) {
                        vm.chrono = "finir"; vm.isCustomChrono = false
                    }
                    SelectableChip(label: "Mon propre temps", selected: vm.isCustomChrono) {
                        vm.isCustomChrono = true; vm.chrono = ""
                    }
                }

                if vm.isCustomChrono {
                    ObTextField(placeholder: "Ex. 1:22:00", text: Binding(get: { vm.chrono ?? "" }, set: { vm.chrono = $0 }))
                        .padding(.top, 10)
                }

                EyebrowLabel(text: "Date de l'épreuve", color: RUColor.text3)
                    .padding(.top, 22).padding(.bottom, 10)
                DatePicker(
                    "",
                    selection: Binding(get: { vm.raceDate ?? Calendar.current.date(byAdding: .day, value: 60, to: .now)! }, set: { vm.raceDate = $0 }),
                    in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .padding(13)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))

                if let days = vm.daysUntilRace {
                    Text("J-\(days)").font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.rose2).padding(.top, 10)
                }

                WellbeingFieldsView(vm: vm)
            }
            ObNext(disabled: !vm.canProceed(fromStep: 3), action: onNext)
        }
    }
}
