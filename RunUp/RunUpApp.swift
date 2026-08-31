import SwiftUI
import SwiftData
import UIKit

@main
struct RunUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .preferredColorScheme(RUColor.colorScheme)
        }
    }
}

/// Real APNs device tokens only ever arrive through this UIKit callback — there's no SwiftUI
/// equivalent — so this stays a thin pass-through into `NotificationService` rather than growing
/// any app logic of its own.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.handleDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No APNs entitlement yet, Simulator (which can't receive real push), or a transient
        // registration failure — none of these should be user-facing; local reminders still work
        // either way.
    }
}

/// Bootstraps `AppState` once a `modelContext` is available from the environment, then hands
/// off to `ContentRouterView`.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState?
    /// True only on this process's cold launch — `RootView` is created once per launch (SwiftUI
    /// doesn't recreate it on background/foreground), so this never re-shows the splash just from
    /// backgrounding the app, only from a real relaunch.
    @State private var showSplash = true
    /// Raised once, after the splash, when the on-disk SwiftData store refused to open and
    /// `PersistenceController` fell back to a throwaway in-memory one (see `StoreState` there).
    /// Deliberately an alert rather than an `appState.toast` — the toast auto-dismisses in 2.2s
    /// and would be covered by the splash anyway, and "nothing you do right now is being saved"
    /// isn't a message she can afford to blink and miss.
    @State private var storeFailureAlertPresented = false

    var body: some View {
        ZStack {
            RUColor.bg.ignoresSafeArea()
            if let appState {
                ContentRouterView()
                    .environment(appState)
            }
            if showSplash {
                SplashView(onFinished: {
                    showSplash = false
                    storeFailureAlertPresented = PersistenceController.isUsingFallbackStore
                })
            }
        }
        .alert("Tes données n'ont pas pu être ouvertes", isPresented: $storeFailureAlertPresented) {
            Button("Continuer", role: .cancel) {}
        } message: {
            // Says the two things that actually matter, in that order: nothing is being saved this
            // session, and nothing has been lost. The old "delete the store and carry on" behaviour
            // would have made the second half a lie.
            Text("L'app fonctionne, mais rien de cette session ne sera enregistré. Tes courses, ton programme et tes messages sont toujours sur ton téléphone — ils n'ont pas été supprimés — et devraient réapparaître après une mise à jour de l'app.")
        }
        .onAppear {
            if appState == nil {
                appState = AppState(modelContext: modelContext)
            }
            // Cold launch never fires the `scenePhase` handler below (there's no previous phase to
            // transition from), so this is the only place a launch-time open is counted.
            Analytics.shared.trackAppOpenedIfNewSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState?.refreshProgramForCurrentDate()
                appState?.retryPendingClubActivities()
                // Debounced to one per real session inside `Analytics` — glancing at a
                // notification and coming back is not a second visit.
                Analytics.shared.trackAppOpenedIfNewSession()
            }
        }
        .onOpenURL { url in
            ReferralLinkHandler.handle(url)
        }
    }
}

/// Aiguillage de premier niveau : inscription → app.
///
/// # Pourquoi le paywall n'est PLUS ici
///
/// Il occupait cette place parce que le modèle verrouillait l'app entière après sept jours. La
/// construction était juste pour ce modèle — au même niveau que l'inscription, sans aucun geste
/// pour passer outre — et c'est le modèle qui a changé.
///
/// Le mur enfermait le Club, le fil d'amis, les classements et les itinéraires partagés avec le
/// reste. Une fonctionnalité sociale sans monde ne vaut rien : personne ne paye pour rejoindre un
/// club vide, donc le club restait vide, donc personne ne payait. Le suivi, l'historique et tout
/// le social sont désormais gratuits pour toujours ; ce qui se vend est le programme et le coach
/// (voir `PlusFeature`), et le paywall s'ouvre depuis la fonctionnalité qu'on vient de vouloir —
/// au moment où l'on sait ce qu'on achète, plutôt qu'au septième jour devant une porte fermée.
private struct ContentRouterView: View {
    @Environment(AppState.self) private var appState
    @State private var subscriptions = SubscriptionService()

    /// L'offre montrée une fois, juste après l'inscription.
    ///
    /// Sans le mur, plus rien ne présentait spontanément l'abonnement : on perdrait les gens qui
    /// viennent de répondre à six questions sur leur objectif, c'est-à-dire précisément ceux qui
    /// sont le plus disposés à écouter. La différence avec l'ancien modèle n'est pas qu'on ne
    /// demande plus — c'est qu'on accepte un non. L'écran se ferme, et l'app derrière fonctionne.
    @AppStorage("paywall.introShown.v1") private var introShown = false
    @State private var showIntro = false

    var body: some View {
        Group {
            if !appState.profile.onboarded {
                OnboardingContainerView()
            } else {
                RootTabView()
            }
        }
        .toastHost(appState.toastCenter)
        // Posée à la racine, au-dessus de TOUT — intégration et paywall compris. Un compte peut se
        // connecter depuis n'importe où, et la question « à qui sont ces données » ne peut pas
        // attendre qu'on soit passé par un écran d'abonnement.
        .sheet(isPresented: Binding(
            get: { appState.profileOwnerConflict != nil },
            set: { if !$0 { appState.profileOwnerConflict = nil } }
        )) {
            AccountSwitchSheet()
                .runUpSheetStyle(detents: [.medium])
        }
        // Une seule présentation du paywall, à la racine — au-dessus des onglets, donc il
        // survit à un changement d'onglet, et aucun écran verrouillé n'a à savoir comment on
        // présente une feuille. Les verrous se contentent de poser `appState.plusPrompt`.
        .sheet(item: Binding(
            get: { appState.plusPrompt },
            set: { appState.plusPrompt = $0 }
        )) { feature in
            PaywallView(subscriptions: subscriptions,
                        highlighted: feature,
                        onClose: { appState.plusPrompt = nil })
        }
        // Plein écran, et non une feuille : c'est l'offre d'ouverture, elle mérite la place. Une
        // présentation distincte de celle des verrous ci-dessus, pour que les deux ne se
        // disputent jamais la même source — deux `sheet(item:)` sur la même vue est le genre de
        // construction qui marche jusqu'au jour où les deux se déclenchent ensemble.
        .fullScreenCover(isPresented: $showIntro) {
            PaywallView(subscriptions: subscriptions, onClose: { showIntro = false })
        }
        .onChange(of: appState.profile.onboarded) { _, onboarded in
            guard onboarded, !introShown else { return }
            introShown = true
            showIntro = true
        }
        .environment(subscriptions)
        .task { await subscriptions.start() }
    }

}
