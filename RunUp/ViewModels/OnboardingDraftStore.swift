import Foundation

/// Snapshot of in-progress onboarding answers, persisted to `UserDefaults` so a phone call, a
/// low-battery kill, or just backgrounding the app mid-wizard doesn't throw away everything she's
/// already answered — the 9-step wizard used to be pure in-memory `@Observable` state, gone the
/// instant `OnboardingContainerView` (and the `OnboardingViewModel` it owns) got torn down and
/// recreated on next launch. Restored by `OnboardingViewModel.loadDraft()` on init, saved on every
/// step change and app-background, cleared once `OnboardingContainerView.finish()` actually
/// completes onboarding.
private struct OnboardingDraft: Codable {
    var showWelcome: Bool
    var step: Int
    var name: String
    var birthdate: Date?
    var sex: String?
    var goal: GoalType?
    var distance: RaceDistance?
    var customDistance: String
    var chrono: String?
    var isCustomChrono: Bool
    var raceDate: Date?
    var hyroxDivision: HyroxDivision?
    var weightNow: String
    var weightTarget: String
    var height: String
    var focusArea: String?
    var bestRecentPerf: String
    var lastRanRecency: String?
    var weeklyTimeBudget: String?
    var preferredTimeOfDay: String?
    var injuryArea: String?
    var cycleTrackingEnabled: Bool
    var lastPeriodStartDate: Date?
    var averageCycleLengthDays: Int
    var runningDays: Set<Int>
    var preferredLongRunDay: Int?
    var runningDaysTouched: Bool
    var level: ExperienceLevel
    var levelTouched: Bool
    var connected: Set<ConnectedSource>
}

extension OnboardingViewModel {
    private static let draftKey = "onboardingDraft.v1"

    func loadDraft() {
        guard let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else { return }
        showWelcome = draft.showWelcome
        step = draft.step
        name = draft.name
        birthdate = draft.birthdate
        sex = draft.sex
        goal = draft.goal
        distance = draft.distance
        customDistance = draft.customDistance
        chrono = draft.chrono
        isCustomChrono = draft.isCustomChrono
        raceDate = draft.raceDate
        hyroxDivision = draft.hyroxDivision
        weightNow = draft.weightNow
        weightTarget = draft.weightTarget
        height = draft.height
        focusArea = draft.focusArea
        bestRecentPerf = draft.bestRecentPerf
        lastRanRecency = draft.lastRanRecency
        weeklyTimeBudget = draft.weeklyTimeBudget
        preferredTimeOfDay = draft.preferredTimeOfDay
        injuryArea = draft.injuryArea
        cycleTrackingEnabled = draft.cycleTrackingEnabled
        lastPeriodStartDate = draft.lastPeriodStartDate
        averageCycleLengthDays = draft.averageCycleLengthDays
        runningDays = draft.runningDays
        preferredLongRunDay = draft.preferredLongRunDay
        runningDaysTouched = draft.runningDaysTouched
        level = draft.level
        levelTouched = draft.levelTouched
        connected = draft.connected
    }

    func saveDraft() {
        // Nothing worth resuming until she's actually started (past Welcome) — skip persisting
        // the untouched default state so a fresh install doesn't write a no-op draft before she's
        // typed anything.
        guard !showWelcome else { return }
        let draft = OnboardingDraft(
            showWelcome: showWelcome, step: step, name: name, birthdate: birthdate, sex: sex, goal: goal,
            distance: distance, customDistance: customDistance, chrono: chrono, isCustomChrono: isCustomChrono,
            raceDate: raceDate, hyroxDivision: hyroxDivision, weightNow: weightNow, weightTarget: weightTarget,
            height: height, focusArea: focusArea, bestRecentPerf: bestRecentPerf, lastRanRecency: lastRanRecency,
            weeklyTimeBudget: weeklyTimeBudget, preferredTimeOfDay: preferredTimeOfDay, injuryArea: injuryArea,
            cycleTrackingEnabled: cycleTrackingEnabled, lastPeriodStartDate: lastPeriodStartDate,
            averageCycleLengthDays: averageCycleLengthDays, runningDays: runningDays,
            preferredLongRunDay: preferredLongRunDay, runningDaysTouched: runningDaysTouched,
            level: level, levelTouched: levelTouched, connected: connected
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftKey)
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }
}
