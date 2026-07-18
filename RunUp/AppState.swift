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
    let auth = AuthService()

    var profile: UserProfile
    var screen: AppScreen = .home

    // Sheets
    var sessionDetailPresented = false
    var programSettingsPresented = false
    var notificationsPresented = false
    var manualDebriefPresented = false

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
        AdaptivePlanEngine.resetDailyGoalsIfNewDay(self.profile)
        ThemeStore.shared.themeID = self.profile.accentThemeID
        NotificationService.shared.rescheduleDailyReminder(for: self.profile)
        Task { await self.syncDailyGoalsFromHealthKit() }
    }

    /// Re-checks the program week/phase against the real calendar date — call whenever the app
    /// returns to the foreground so a skipped week or program completion is picked up even if the
    /// user didn't open the app on the exact day it happened.
    func refreshProgramForCurrentDate() {
        let previousWeek = profile.weekNumber
        AdaptivePlanEngine.refreshProgramForCurrentDate(profile)
        AdaptivePlanEngine.resetDailyGoalsIfNewDay(profile)
        if profile.weekNumber != previousWeek {
            notify(
                icon: "mark", colorHex: 0xFF3B6B,
                title: "Nouvelle semaine",
                text: "Semaine \(profile.weekNumber) prête, ajustée d'après ta forme de la semaine passée.",
                coachOnly: true
            )
        }
        NotificationService.shared.rescheduleDailyReminder(for: profile)
        Task { await syncDailyGoalsFromHealthKit() }
    }

    /// Pulls today's step count and strength/mobility workout minutes from Apple Santé, if
    /// connected — the "Renfo & mobilité" and "Pas" daily goals are HealthKit-sourced, not
    /// something logged inside the app.
    private func syncDailyGoalsFromHealthKit() async {
        guard profile.connectedSources.contains(.apple) else { return }
        async let steps = healthKit.stepsToday()
        async let strength = healthKit.strengthMobilityMinutesToday()
        profile.stepsToday = await steps
        profile.strengthMinutesToday = await strength
        if AdaptivePlanEngine.checkDailyGoalsBonus(profile) {
            postClubActivity(type: "badge", text: "a bouclé ses 3 objectifs du jour", xpEarned: 120)
            notify(icon: "🎉", colorHex: 0xC9FF3B, title: "Journée bouclée", text: "Tes 3 objectifs du jour sont faits — +120 XP.")
            toast("Journée bouclée · +120 XP 🎉")
        }
    }

    /// Inserts a real bell-icon notification — replaces what used to be a purely decorative UI
    /// (the bell/badge/sheet existed and read from `AppNotification`, but nothing ever created
    /// one). `coachOnly` gates it on the "Notifications du coach" toggle in Profil, for
    /// program-related updates specifically; social/gamification ones (kudos, daily goals) always
    /// post regardless of that toggle.
    func notify(icon: String, colorHex: Int, title: String, text: String, coachOnly: Bool = false) {
        if coachOnly && !profile.coachNotificationsEnabled { return }
        modelContext.insert(AppNotification(icon: icon, colorHex: colorHex, title: title, text: text))
    }

    /// Posts to the real club feed/leaderboard if signed in — silently does nothing otherwise
    /// (Club participation is optional; this must never block the flow it's called from). See
    /// `ClubService.postActivity`.
    func postClubActivity(type: String, text: String, xpEarned: Int) {
        guard auth.isSignedIn else { return }
        let service = ClubService(auth: auth)
        Task { try? await service.postActivity(type: type, text: text, xpEarned: xpEarned) }
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

    /// Logs today's planned session as done without going through the GPS Live Run flow — for a
    /// strength day, a treadmill session, or simply forgetting to hit record. Builds a synthetic
    /// `RunRecord` from the session's own planned duration/pace (no real heart-rate reading, so
    /// `avgHeartRate` is 0 — `HistoryView` already knows to hide that line rather than show a
    /// fake number) and opens the same RPE debrief every other run goes through, so streak/XP/
    /// plan-adaptation all work identically either way.
    func markTodaySessionDone() {
        let session = profile.todaySession
        guard session.durationMinutes > 0 else { return }
        let elapsedSeconds = Double(session.durationMinutes * 60)
        let secPerKm = parsePaceSecondsPerKm(session.pace) ?? 300
        let distanceKm = elapsedSeconds / secPerKm
        let record = AdaptivePlanEngine.buildRunRecord(
            title: session.title,
            elapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            kcal: distanceKm * 62,
            avgHeartRate: 0
        )
        modelContext.insert(record)
        lastRun = record
        manualDebriefPresented = true
    }

    private func parsePaceSecondsPerKm(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
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
