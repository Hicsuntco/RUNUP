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
        }
        AdaptivePlanEngine.refreshProgramForCurrentDate(self.profile)
    }

    /// Re-checks the program week/phase against the real calendar date — call whenever the app
    /// returns to the foreground so a skipped week or program completion is picked up even if the
    /// user didn't open the app on the exact day it happened.
    func refreshProgramForCurrentDate() {
        AdaptivePlanEngine.refreshProgramForCurrentDate(profile)
    }

    func go(_ screen: AppScreen) {
        self.screen = screen
    }

    func startRun() {
        // Guard here (not per call site) so every entry point — Home's session card, the session
        // detail sheet, the tab bar's resume pill — is protected from silently overwriting an
        // in-progress run's LiveRunViewModel (which would orphan its timer/location task with no
        // RunRecord ever produced for it).
        guard !isRunActive else {
            screen = .live
            return
        }
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

    func replayOnboarding() {
        profile.onboarded = false
    }

    func toast(_ message: String) {
        toastCenter.show(message)
    }
}
