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
                        .colorScheme(RUColor.colorScheme)
                        .padding(13)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

                        HStack {
                            Text("Durée moyenne du cycle").font(RUFont.sans(13)).foregroundColor(RUColor.textPrimary)
                            Spacer()
                            // A native `Stepper`'s +/- segments render at a fixed ~29pt tall
                            // regardless of surrounding padding — no way to grow that from the
                            // outside, so this is two custom 44×44 buttons instead.
                            HStack(spacing: 4) {
                                Button(action: { vm.averageCycleLengthDays = max(21, vm.averageCycleLengthDays - 1) }) {
                                    Image(systemName: "minus").font(.system(size: 12, weight: .bold))
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .disabled(vm.averageCycleLengthDays <= 21)

                                Text("\(vm.averageCycleLengthDays) jours")
                                    .font(RUFont.sans(13, weight: .semibold))
                                    .frame(minWidth: 56)

                                Button(action: { vm.averageCycleLengthDays = min(35, vm.averageCycleLengthDays + 1) }) {
                                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .disabled(vm.averageCycleLengthDays >= 35)
                            }
                            .foregroundColor(RUColor.rose)
                        }
                        .padding(13)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    }
                    .padding(.top, 4)
                    .id("cycleFields")
                }
            }
        }
    }
}
