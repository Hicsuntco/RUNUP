import SwiftUI

/// Edit running days + free-text goal. Mirrors `ProgramSettingsSheet` in screensC.jsx.
struct ProgramSettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var days: Set<Int> = []
    @State private var goal: String = ""

    /// Le minimum exigé par l'objectif en cours. Voir `GoalType.joursMinimumParSemaine`.
    private var minimumJours: Int { appState.profile.goalId.joursMinimumParSemaine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Modifier mon programme").displayStyle(22).foregroundColor(RUColor.textPrimary).padding(.top, 8)

                EyebrowLabel(text: "Jours de course", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
                // spacing 5, not 7 — same fix as onboarding's RunningDaysStepView: on the
                // smallest currently-supported iPhone (375pt), 7 gaps of 7pt each pushed every
                // square under the 44pt tap-target minimum.
                HStack(spacing: 5) {
                    ForEach(0..<7) { i in
                        let on = days.contains(i)
                        Button(action: { if on { days.remove(i) } else { days.insert(i) } }) {
                            Text(DayStatus.letters[i])
                                .displayStyle(15)
                                .foregroundColor(on ? .white : RUColor.text2)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .buttonStyle(PressableStyle())
                        // Visually identical to onboarding's RunningDaysStepView day picker, which
                        // already has this — VoiceOver was otherwise reading bare single-letter
                        // abbreviations ("L", "M", "M"...) with no full day name or selected state.
                        .accessibilityLabel(DayStatus.fullNames[i])
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }

                EyebrowLabel(text: "Objectif", color: RUColor.text3).padding(.top, 22).padding(.bottom, 10)
                ObTextField(placeholder: "Objectif", text: $goal)

                Text("Le coach recalcule tes prochaines séances dès l'enregistrement.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
                    .padding(.top, 14)

                Button("ENREGISTRER") {
                    appState.profile.runningDays = Array(days)
                    appState.profile.goalDisplay = goal
                    // Makes the copy above true — regenerate this week around the new days now,
                    // instead of silently waiting for the next week boundary.
                    AdaptivePlanEngine.applyProgramSettingsChange(appState.profile)
                    appState.publishWidgetSnapshot()
                    appState.toast(String(localized: "Programme mis à jour"))
                    dismiss()
                }
                // Le minimum vient de l'objectif EN COURS : réduire un plan de triathlon à deux
                // jours par cet écran-là aurait contourné la règle posée à l'inscription, et
                // produit une semaine à laquelle il manque une discipline.
                .buttonStyle(PrimaryButtonStyle(isDisabled: days.count < minimumJours))
                .disabled(days.count < minimumJours)
                .padding(.top, 18)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 26)
        }
        .onAppear {
            days = Set(appState.profile.runningDays)
            goal = appState.profile.goalDisplay
        }
    }
}
