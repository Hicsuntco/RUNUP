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
                ForEach(OnboardingChoices.blessures, id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.injuryArea == id) { vm.injuryArea = id }
                }
            }

            // « DEPUIS QUAND » NE SE DEMANDE QU'À QUI A COCHÉ UNE ZONE.
            //
            // Et elle décide de beaucoup : sans elle, une entorse d'il y a trois ans
            // raccourcissait de 30 % toute séance de vitesse, chaque semaine, indéfiniment.
            // Voir `AncienneteBlessure`.
            if let zone = vm.injuryArea, zone != OnboardingChoices.aucuneBlessure {
                EyebrowLabel(text: "C'était quand ?", color: RUColor.text3)
                    .padding(.top, 20).padding(.bottom, 10)
                ChipFlowLayout {
                    ForEach(AncienneteBlessure.allCases) { choix in
                        SelectableChip(label: choix.title, selected: vm.injuryWhen == choix) {
                            vm.injuryWhen = choix
                        }
                    }
                }
            }

            // LE TERRAIN. Le plan prescrivait « Côtes longues » sans jamais demander s'il y
            // avait une côte à moins de vingt kilomètres.
            EyebrowLabel(text: "Où tu cours, en vrai", color: RUColor.text3)
                .padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(Terrain.allCases) { terrain in
                    SelectableChip(label: terrain.title, selected: vm.terrains.contains(terrain)) {
                        if vm.terrains.contains(terrain) { vm.terrains.remove(terrain) }
                        else { vm.terrains.insert(terrain) }
                    }
                }
            }

            // LES AUTRES SPORTS. Trois séances de renfo par semaine ne laissent pas les mêmes
            // jambes, et le plan posait ses deux séances de qualité dans tous les cas.
            EyebrowLabel(text: "Tu fais autre chose à côté ?", color: RUColor.text3)
                .padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(AutreSport.allCases) { sport in
                    SelectableChip(label: sport.title, selected: vm.autresSports.contains(sport)) {
                        if vm.autresSports.contains(sport) { vm.autresSports.remove(sport) }
                        else { vm.autresSports.insert(sport) }
                    }
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
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

                        HStack {
                            Text("Durée moyenne du cycle").font(RUFont.sans(.label)).foregroundColor(RUColor.textPrimary)
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
                                .accessibilityLabel("Un jour de moins")

                                Text("\(vm.averageCycleLengthDays) jours")
                                    .font(RUFont.sans(.label, weight: .semibold))
                                    .frame(minWidth: 56)

                                Button(action: { vm.averageCycleLengthDays = min(35, vm.averageCycleLengthDays + 1) }) {
                                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .disabled(vm.averageCycleLengthDays >= 35)
                                .accessibilityLabel("Un jour de plus")
                            }
                            .foregroundColor(RUColor.rose)
                        }
                        .padding(13)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    }
                    .padding(.top, 4)
                    .id("cycleFields")
                }
            }
        }
    }
}
