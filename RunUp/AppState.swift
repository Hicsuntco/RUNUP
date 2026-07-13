import Foundation
import SwiftData
import Observation

/// Central app store + router — mirrors the `store`/`ctx` object threaded through the
/// prototype via React context. Held once at the root and read via `@Environment(AppState.self)`.
@Observable
final class AppState {
    let modelContext: ModelContext
    let healthKit = HealthKitService()
    let toastCenter = ToastCenter()

    var profile: UserProfile
    var screen: AppScreen = .home
    var showPaywall = false

    // Sheets
    var sessionDetailPresented = false
    var programSettingsPresented = false
    var notificationsPresented = false

    // Live run (ephemeral, survives navigating away from the Live screen)
    var liveRun: LiveRunViewModel?
    var isRunActive: Bool { liveRun != nil }
    /// The most recently completed run, shown on the Recap screen. Transient — not persisted
    /// on `UserProfile` itself, just a navigation hand-off (the `RunRecord` is already inserted
    /// into `modelContext` and lives on independently via the History query).
    var lastRun: RunRecord?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            self.profile = existing
        } else {
            let fresh = UserProfile()
            modelContext.insert(fresh)
            self.profile = fresh
            Self.seedInitialData(modelContext: modelContext)
        }
    }

    /// First-launch seed data — mirrors the `NOTIFS`/`HISTORY_SEED` constants in app.jsx/screensC.jsx
    /// so the app doesn't open to a blank Notifications/History screen before any real activity exists.
    private static func seedInitialData(modelContext: ModelContext) {
        let now = Date.now
        let calendar = Calendar.current

        let notifications: [(String, Int, String, String, Int, Bool)] = [
            ("mark", 0xFF0F5B, "Séance ajustée", "Ta forme est excellente — on a relevé la séance du jour d'un palier.", -1, false),
            ("🔥", 0x7C5CFF, "Série de 12 jours", "Tu tiens ta série — encore une sortie pour passer à 13.", -8, false),
            ("🏆", 0xC8FF3D, "Défi du mois", "Plus que 29 km pour boucler les 100 km de juillet.", -20, true)
        ]
        for (icon, color, title, text, hoursAgo, read) in notifications {
            let timestamp = calendar.date(byAdding: .hour, value: hoursAgo, to: now) ?? now
            modelContext.insert(AppNotification(icon: icon, colorHex: color, title: title, text: text, timestamp: timestamp, read: read))
        }

        let runs: [(Int, String, Double, Int, String, Int)] = [
            (-4, "Fractionné 6 × 800 m", 7.2, 1842, "4:16", 157),
            (-6, "Sortie longue", 12.4, 4380, "5:53", 148),
            (-8, "Récup active", 5.0, 1800, "6:00", 132),
            (-10, "Fractionné 5 × 1000 m", 8.1, 2160, "4:26", 161),
            (-12, "Footing", 6.5, 2280, "5:50", 139)
        ]
        for (daysAgo, title, dist, duration, pace, hr) in runs {
            let date = calendar.date(byAdding: .day, value: daysAgo, to: now) ?? now
            modelContext.insert(RunRecord(date: date, title: title, distanceKm: dist, durationSeconds: duration, avgPace: pace, avgHeartRate: hr, kcal: Int(dist * 65)))
        }
    }

    func go(_ screen: AppScreen) {
        self.screen = screen
    }

    func startRun() {
        let vm = LiveRunViewModel(profile: profile, healthKit: healthKit)
        liveRun = vm
        vm.start()
        screen = .live
    }

    func endLiveRun() -> RunRecord? {
        guard let vm = liveRun else { return nil }
        let record = vm.stop()
        modelContext.insert(record)
        lastRun = record
        liveRun = nil
        screen = .recap
        return record
    }

    func openSessionDetail() { sessionDetailPresented = true }
    func openProgramSettings() { programSettingsPresented = true }
    func openNotifications() { notificationsPresented = true }
    func openPaywall() { showPaywall = true }

    func replayOnboarding() {
        profile.onboarded = false
    }

    func toast(_ message: String) {
        toastCenter.show(message)
    }
}
