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

/// Top-level switch: onboarding → main tabbed app.
private struct ContentRouterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if !appState.profile.onboarded {
                OnboardingContainerView()
            } else {
                RootTabView()
            }
        }
        .toastHost(appState.toastCenter)
    }
}
