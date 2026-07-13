import SwiftUI

/// Bottom sheet reached by tapping the home hero card. Mirrors `SessionDetailSheet` in screensC.jsx.
struct SessionDetailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var moved = false

    private var session: WorkoutSession { appState.profile.todaySession }

    private var steps: [(String, String, Color)] {
        let reps = session.title.firstNumber ?? 6
        return [
            ("Échauffement", "15′ · Z2 · footing relâché", RUColor.cyan),
            ("\(reps) × 800 m", "\(session.pace) /km · \(session.zone) · récup 400 m entre chaque", RUColor.rose),
            ("Retour au calme", "10′ · Z1 · marche + étirements", RUColor.lime)
        ]
    }

    private var isRestDay: Bool { session.durationMinutes == 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        EyebrowLabel(text: isRestDay ? "Aujourd'hui" : "Séance clé", color: RUColor.rose)
                        Text(session.title).displayStyle(26).foregroundColor(.white)
                    }
                    Spacer()
                    if let adj = session.adjustment {
                        StatChip(text: adj, color: RUColor.rose2)
                    }
                }
                .padding(.top, 8)

                if isRestDay {
                    Text(session.subtitle)
                        .font(RUFont.sans(13)).foregroundColor(RUColor.text2).lineSpacing(3)
                        .padding(.top, 16)
                } else {
                    HStack(spacing: 16) {
                        MetricColumn(value: "\(session.durationMinutes)′", label: "Durée")
                        MetricColumn(value: session.pace, label: "Allure cible")
                        MetricColumn(value: session.zone, label: "Zone", valueColor: RUColor.rose2)
                    }
                    .padding(.top, 16)

                    EyebrowLabel(text: "Structure de la séance", color: RUColor.text3).padding(.top, 22).padding(.bottom, 10)

                    VStack(spacing: 6) {
                        ForEach(steps.indices, id: \.self) { i in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 2).fill(steps[i].2).frame(width: 3, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(steps[i].0).font(RUFont.sans(13, weight: .semibold)).foregroundColor(.white)
                                    Text(steps[i].1).font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                    }

                    if let adj = session.adjustment {
                        Text("💡 Le coach a ajusté cette semaine à \"\(adj)\" d'après ta forme la semaine dernière.")
                            .font(RUFont.sans(12))
                            .foregroundColor(RUColor.text2)
                            .lineSpacing(3)
                            .padding(13)
                            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                            .padding(.top, 16)
                    }

                    if moved {
                        Text("Séance déplacée à demain ✓")
                            .font(RUFont.sans(13, weight: .semibold))
                            .foregroundColor(RUColor.lime)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(RUColor.lime.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.lime.opacity(0.25), lineWidth: RUSpacing.hairline))
                            .padding(.top, 16)
                    } else {
                        HStack(spacing: 8) {
                            Button("Déplacer à demain") {
                                moved = true
                                appState.toast("Séance déplacée à demain")
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button(action: {
                                dismiss()
                                appState.startRun()
                            }) {
                                HStack { Image(systemName: "play.fill"); Text("DÉMARRER") }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }
}

private extension String {
    var firstNumber: Int? {
        guard let range = range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return Int(self[range])
    }
}
