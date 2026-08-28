import SwiftUI
import SwiftData

/// Post-recovery choice: new goal or free-run mode. Mirrors `ChoiceView` in screensD.jsx.
struct ChoiceView: View {
    @Environment(AppState.self) private var appState
    @Query private var runs: [RunRecord]
    @State private var showNewGoal = false

    private var profile: UserProfile { appState.profile }

    private var totalKm: Int {
        // Just the run records — `profile.runValue` is today's km, already inside `runs`, so
        // adding it double-counted today's distance in the end-of-program bilan.
        Int(runs.reduce(0) { $0 + $1.distanceKm })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // `.profile` is not a tab — the ONLY ways into it anywhere in the app are this
                // avatar and the identical one on `HomeView`/`RecoveryView`, all three of which
                // sit in the header of whatever `AppScreen.home` currently resolves to. This
                // screen replaces `HomeView.mainContent` outright for the whole `.choice` phase
                // (see `HomeView.body`'s switch), and it was the one of the three that had
                // `EmptyView()` here instead — so for as long as a finished program sat waiting on
                // this choice, Profil was unreachable from the entire app, and with it Réglages,
                // Apparence, le compte, les chaussures and "Voir mon objectif". Not a styling
                // omission: an actual dead end, in the exact phase where "je regarde mes stats et
                // mon compte avant de repartir" is the most likely thing she'd want to do.
                HeaderView(eyebrow: "Récupération terminée", title: "Et maintenant ?") {
                    AvatarButton(initial: String(profile.name.prefix(1)), imageData: profile.avatarImageData) { appState.go(.profile) }
                }

                VStack(alignment: .leading, spacing: 10) {
                    RUCardHeader(icon: "checkmark.seal.fill", tint: RUColor.rose, title: "Bilan de ton programme")
                    HStack(spacing: 20) {
                        MetricColumn(value: "\(totalKm)", label: "km parcourus")
                        // Deux clés entières plutôt qu'un « s » recollé : le pluriel ne se fabrique
                        // pas de la même façon dans les trois langues.
                        MetricColumn(value: "\(profile.weekNumber)", label: profile.weekNumber > 1 ? String(localized: "semaines") : String(localized: "semaine"))
                        MetricColumn(value: "\(profile.streak)", label: profile.streak > 1 ? String(localized: "jours de série") : String(localized: "jour de série"), valueColor: RUColor.rose2)
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
                    appState.toast(String(localized: "Mode course libre activé"))
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
