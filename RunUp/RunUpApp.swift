import SwiftUI
import SwiftData

@main
struct RunUpApp: App {
    let container = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
    }
}

/// Bootstraps `AppState` once a `modelContext` is available from the environment, then hands
/// off to `ContentRouterView`.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState: AppState?

    var body: some View {
        ZStack {
            RUColor.bg.ignoresSafeArea()
            if let appState {
                ContentRouterView()
                    .environment(appState)
            }
        }
        .onAppear {
            if appState == nil {
                appState = AppState(modelContext: modelContext)
            }
        }
    }
}

/// Top-level switch: onboarding → paywall (post-onboarding upsell) → main tabbed app.
private struct ContentRouterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if !appState.profile.onboarded {
                OnboardingContainerView()
            } else if appState.showPaywall {
                PaywallView()
            } else {
                RootTabView()
            }
        }
        .toastHost(appState.toastCenter)
    }
}
