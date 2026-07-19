import SwiftUI

/// Bottom sheet reached by tapping the home hero card. Mirrors `SessionDetailSheet` in screensC.jsx.
struct SessionDetailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var moved = false

    private var session: WorkoutSession { appState.profile.todaySession }

    /// The real archetype titles from `AdaptivePlanEngine` fall into 3 shapes — a footing/sortie
    /// longue IS an easy continuous effort throughout (no separate warmup/cooldown block at a
    /// different pace makes sense there), a tempo run is one sustained threshold effort, and only
    /// a "Fractionné"/"Rappel d'allure" session is actually structured as reps + recovery. Every
    /// session used to show the same "warmup + N×800m + cooldown" regardless of which of these it
    /// actually was.
    private var steps: [(String, String, Color)] {
        let title = session.title.lowercased()
        let warmup = ("Échauffement", "10-15′ · Z2 · footing relâché", RUColor.cyan)
        let cooldown = ("Retour au calme", "5-10′ · Z1 · marche + étirements", RUColor.lime)

        // HYROX sessions are structurally different from a running-only week — a "compromised
        // running" block or a functional circuit isn't a warmup/interval/cooldown shape at all,
        // so this branches before the running-only logic below ever gets a chance to mislabel it
        // as a generic "Course continue".
        if appState.profile.goalId == .hyrox {
            return hyroxSteps(title: title, warmup: warmup, cooldown: cooldown)
        }

        if session.isIntervalSession {
            return [
                warmup,
                (intervalDescription, "\(session.pace) /km · \(session.zone) · récupération entre chaque", RUColor.rose),
                cooldown
            ]
        }
        if title.contains("tempo") {
            return [
                warmup,
                ("Bloc tempo", "\(max(10, session.durationMinutes - 20))′ · \(session.pace) /km · \(session.zone) · effort soutenu et continu", RUColor.rose),
                cooldown
            ]
        }
        // Footing / sortie longue / sortie courte / découverte / récup — the whole run is the
        // target effort, not a warmup building up to something else.
        return [("Course continue", "\(session.durationMinutes)′ · \(session.pace) /km · \(session.zone)", RUColor.rose)]
    }

    /// HYROX-specific breakdown — "Course compromise" alternates running with functional work
    /// (real structure, no fixed kg since this app has no verified current-season loads to state
    /// as fact — see `HyroxDivision`), "Fonctionnel"/"technique" sessions are one circuit block,
    /// and a full "Simulation" mirrors the actual 8×1km + 8-station race shape.
    private func hyroxSteps(title: String, warmup: (String, String, Color), cooldown: (String, String, Color)) -> [(String, String, Color)] {
        if title.contains("compromise") {
            return [
                warmup,
                ("\(intervalDescription) + fonctionnel", "\(session.pace) /km entre les blocs · \(session.zone) · enchaîne course et mouvement, sans repos complet", RUColor.rose),
                cooldown
            ]
        }
        if title.contains("simulation") {
            return [
                warmup,
                ("8 × 1 km + 8 stations", "format complet HYROX · \(session.zone) · gère l'effort sur l'ensemble, pas juste la course", RUColor.rose),
                cooldown
            ]
        }
        if title.contains("tempo") {
            return [
                warmup,
                ("Tempo + sled", "\(max(10, session.durationMinutes - 20))′ · \(session.pace) /km · \(session.zone) · allure seuil entrecoupée de sled push/pull", RUColor.rose),
                cooldown
            ]
        }
        // "Fonctionnel HYROX" / "Rappel technique stations" — a standalone circuit, no running
        // warmup/cooldown shape fits (the circuit itself includes the movement prep).
        return [("Circuit fonctionnel", "\(session.durationMinutes)′ · \(session.zone) · stations enchaînées, technique avant charge", RUColor.rose)]
    }

    /// Pulls the exact "N × distance" straight from the archetype's own title (e.g. "5 × 500 m",
    /// "6 × 800 m", "3 × 1 km") instead of assuming every interval session is 800m repeats.
    private var intervalDescription: String {
        if let range = session.title.range(of: #"\d+\s*×\s*\d+\s?(m|km)"#, options: .regularExpression) {
            return String(session.title[range])
        }
        return "Fractionné"
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
