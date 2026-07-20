import SwiftUI

/// Shared "injury to watch" (+ cycle-tracking opt-in, only offered when `sex == "female"`) block —
/// appended after each step-3 branch's own goal-specific fields (`DeepDiveStepView`,
/// `RaceDetailsStepView`) so it's asked regardless of goal. Injury used to only ever be collected
/// for the "restart" goal, which meant a runner training for a race or just staying fit could
/// never flag a sensitive knee/ankle/back for `AdaptivePlanEngine` to actually train around.
struct WellbeingFieldsView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Une douleur ou blessure à surveiller ?", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach([("none", "Aucune"), ("knee", "Genou"), ("ankle", "Cheville"), ("back", "Dos"), ("other", "Autre")], id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.injuryArea == id) { vm.injuryArea = id }
                }
            }

            if vm.sex == "female" {
                EyebrowLabel(text: "Adapter le programme à ton cycle ?", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
                ChipFlowLayout {
                    SelectableChip(label: "Oui", selected: vm.cycleTrackingEnabled) { vm.cycleTrackingEnabled = true }
                    SelectableChip(label: "Non merci", selected: !vm.cycleTrackingEnabled) { vm.cycleTrackingEnabled = false }
                }

                if vm.cycleTrackingEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "Date des dernières règles", color: RUColor.text3).padding(.top, 14)
                        DatePicker(
                            "",
                            selection: Binding(get: { vm.lastPeriodStartDate ?? .now }, set: { vm.lastPeriodStartDate = $0 }),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(13)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))

                        HStack {
                            Text("Durée moyenne du cycle").font(RUFont.sans(13)).foregroundColor(RUColor.textPrimary)
                            Spacer()
                            Stepper("\(vm.averageCycleLengthDays) jours", value: $vm.averageCycleLengthDays, in: 21...35)
                                .fixedSize()
                                .tint(RUColor.rose)
                                .foregroundColor(RUColor.textPrimary)
                        }
                        .padding(13)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}
