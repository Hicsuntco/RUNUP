import SwiftUI

@main
struct RunUpWatchApp: App {
    @State private var workout = WatchWorkoutManager()

    // `@MainActor` explicite : `WatchWorkoutManager` et `WatchConnectivityManager` sont désormais
    // isolés sur l'acteur principal, et c'est ici qu'ils sont construits — dans la valeur par
    // défaut de `workout` comme dans le corps ci-dessous. `App.main()` s'exécute déjà sur le fil
    // principal, donc l'annotation ne fait qu'écrire noir sur blanc ce qui était vrai.
    @MainActor
    init() {
        // Activates the WCSession at launch so today's session context is ready before the UI
        // first renders (the singleton would otherwise only spin up on first property access).
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(workout)
        }
    }
}

/// Routes on the workout's own state — no navigation stack to get lost in on a 40mm screen.
struct WatchRootView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    var body: some View {
        switch workout.state {
        case .idle, .starting:
            WatchStartView()
        case .running, .paused:
            WatchRunView()
        case .ended:
            WatchSummaryView()
        }
    }
}
