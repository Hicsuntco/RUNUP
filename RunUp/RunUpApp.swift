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

    var body: some View {
        ZStack {
            RUColor.bg.ignoresSafeArea()
            if let appState {
                ContentRouterView()
                    .environment(appState)
            }
            if showSplash {
                SplashView(onFinished: { showSplash = false })
            }
        }
        .onAppear {
            if appState == nil {
                appState = AppState(modelContext: modelContext)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState?.refreshProgramForCurrentDate()
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
