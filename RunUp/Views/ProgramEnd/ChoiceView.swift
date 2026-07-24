import SwiftUI
import SwiftData

/// Post-recovery choice: new goal or free-run mode. Mirrors `ChoiceView` in screensD.jsx.
struct ChoiceView: View {
    @Environment(AppState.self) private var appState
    @Query private var runs: [RunRecord]
    @State private var showNewGoal = false

    private var profile: UserProfile { appState.profile }

    private var totalKm: Int {
        Int(profile.runValue + runs.reduce(0) { $0 + $1.distanceKm })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HeaderView(eyebrow: "Récupération terminée", title: "Et maintenant ?") { EmptyView() }

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Bilan de ton programme")
                    HStack(spacing: 20) {
                        MetricColumn(value: "\(totalKm)", label: "km parcourus")
                        MetricColumn(value: "\(profile.weekNumber)", label: "semaine\(profile.weekNumber > 1 ? "s" : "")")
                        MetricColumn(value: "\(profile.streak)", label: "jour\(profile.streak > 1 ? "s" : "") de série", valueColor: RUColor.rose2)
                    }
                }
                .padding(16)
                .ruCard()

                Button(action: { showNewGoal = true }) {
                    HStack(spacing: 14) {
                        Text("🎯").font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Se fixer un nouvel objectif").displayStyle(17).foregroundColor(RUColor.textPrimary)
                            Text("Une nouvelle course, progresser encore, perdre du poids…")
                                .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).lineSpacing(2)
                        }
                        Spacer(minLength: 0)
                        Text("→").foregroundColor(RUColor.rose2)
                    }
                    .padding(18)
                }
                .buttonStyle(PressableStyle())
                .ruHeroCard(radius: 20, borderOpacity: 0.28)

                Button(action: {
                    AdaptivePlanEngine.chooseFreeRun(profile)
                    appState.toast("Mode course libre activé")
                    appState.go(.home)
                }) {
                    HStack(spacing: 14) {
                        AppMarkView(size: 26, radius: 8)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Mode course libre").displayStyle(17).foregroundColor(RUColor.textPrimary)
                            Text("Pas d'objectif précis — on te propose juste de quoi garder la forme.")
                                .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).lineSpacing(2)
                        }
                        Spacer(minLength: 0)
                        Text("→").foregroundColor(RUColor.text2)
                    }
                    .padding(18)
                }
                .buttonStyle(PressableStyle())
                .ruCard()
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .fullScreenCover(isPresented: $showNewGoal) {
            NewGoalWizardView()
        }
    }
}
