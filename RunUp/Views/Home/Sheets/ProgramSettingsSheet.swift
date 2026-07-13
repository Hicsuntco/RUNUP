import SwiftUI

/// Edit running days + free-text goal. Mirrors `ProgramSettingsSheet` in screensC.jsx.
struct ProgramSettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var days: Set<Int> = []
    @State private var goal: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Modifier mon programme").displayStyle(22).foregroundColor(.white).padding(.top, 8)

                EyebrowLabel(text: "Jours de course", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
                HStack(spacing: 7) {
                    ForEach(0..<7) { i in
                        let on = days.contains(i)
                        Button(action: { if on { days.remove(i) } else { days.insert(i) } }) {
                            Text(DayStatus.letters[i])
                                .displayStyle(15)
                                .foregroundColor(on ? .white : RUColor.text2)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

                EyebrowLabel(text: "Objectif", color: RUColor.text3).padding(.top, 22).padding(.bottom, 10)
                ObTextField(placeholder: "Objectif", text: $goal)

                Text("Le coach recalcule tes prochaines séances dès l'enregistrement.")
                    .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).lineSpacing(3)
                    .padding(.top, 14)

                Button("ENREGISTRER") {
                    appState.profile.runningDays = Array(days)
                    appState.profile.goalDisplay = goal
                    appState.toast("Programme mis à jour")
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: days.count < 2))
                .disabled(days.count < 2)
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
