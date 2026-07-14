import Foundation
import SwiftData

/// The single per-device user/program/rings/gamification document — mirrors the flat `store`
/// object in app.jsx. Deliberately not decomposed into a web of 1:1-related SwiftData entities:
/// there is exactly one of these per install, fetched once via `AppState` and mutated in place.
/// Collections that genuinely grow over time (`RunRecord`, `ChatMessage`, `AppNotification`)
/// are separate @Model types instead.
@Model
final class UserProfile {
    // MARK: Identity
    var name: String
    var birthdate: Date?
    var goalId: GoalType
    var level: ExperienceLevel
    var connectedSources: [ConnectedSource]

    // MARK: Goal-specific deep-dive fields (only the relevant subset is populated)
    var raceDistance: RaceDistance?
    var raceDistanceCustom: String?
    var raceChrono: String?
    var raceDate: Date?
    var weightNowKg: Double?
    var weightTargetKg: Double?
    var heightCm: Double?
    var focusArea: String?
    var bestRecentPerf: String?
    var lastRanRecency: String?
    var injuryArea: String?
    var weeklyTimeBudget: String?
    var preferredTimeOfDay: String?

    // MARK: Goal display (free text summary shown across the app, e.g. "10 km · 47:30")
    var goalDisplay: String

    // MARK: Program
    var weekNumber: Int
    /// When the current 9-week block began — used to derive `weekNumber` and the week strip from
    /// the device's real calendar date instead of requiring the app to be opened on a schedule.
    /// Optional so profiles created before this field existed migrate in as `nil` and self-heal
    /// (see `AdaptivePlanEngine.refreshProgramForCurrentDate`).
    var programStartDate: Date?
    var programPhase: ProgramPhase
    var recoveryDaysLeft: Int
    /// 0 = Monday ... 6 = Sunday.
    var runningDays: [Int]
    var todaySession: WorkoutSession
    var weekStrip: [DayStatus]
    /// The current week's full 7-day plan — regenerated once per week (see
    /// `AdaptivePlanEngine.refreshProgramForCurrentDate`), not mutated after each run. Needs an
    /// inline default (not just one set in `init`) so SwiftData's lightweight migration can add
    /// this column to profiles saved before this field existed, instead of crashing at launch.
    var weekSessions: [PlannedDay] = []
    /// Difficulty tier for session duration/labeling — only ever changes at a week boundary,
    /// based on the previous week's average RPE, never after a single run.
    var weekTier: Int = 1
    /// Accumulates this week's submitted RPEs (as `3 - RPE.rawValue`, so higher = harder) so the
    /// week-boundary adaptation can average them; reset to 0 whenever a new week starts.
    var weekRPESum: Int = 0
    var weekRPECount: Int = 0
    var freeRunTemplateIndex: Int

    // MARK: Rings
    var moveValue: Double
    var moveGoal: Double
    var activeValue: Double
    var activeGoal: Double
    var runValue: Double
    var runGoal: Double

    // MARK: Gamification
    var streak: Int
    var xp: Int
    var readiness: Int

    // MARK: Meta
    /// No paid tier ships in this version — everyone gets full access. Kept as a field (rather
    /// than removed outright) so a future real subscription can gate on it without a migration.
    var premium: Bool
    var onboarded: Bool
    var distanceUnit: String
    var coachNotificationsEnabled: Bool

    init(name: String = "") {
        self.name = name
        self.birthdate = nil
        self.goalId = .health
        self.level = .intermediaire
        self.connectedSources = []
        self.raceDistance = nil
        self.raceDistanceCustom = nil
        self.raceChrono = nil
        self.raceDate = nil
        self.weightNowKg = nil
        self.weightTargetKg = nil
        self.heightCm = nil
        self.focusArea = nil
        self.bestRecentPerf = nil
        self.lastRanRecency = nil
        self.injuryArea = nil
        self.weeklyTimeBudget = nil
        self.preferredTimeOfDay = nil
        self.goalDisplay = "Rester en forme"
        self.weekNumber = 1
        self.programStartDate = .now
        self.programPhase = .active
        self.recoveryDaysLeft = 0
        self.runningDays = [0, 1, 3, 5]
        self.todaySession = .reprise
        self.weekStrip = (0..<7).map { DayStatus(weekday: $0, letter: DayStatus.letters[$0], state: .upcoming) }
        self.weekSessions = (0..<7).map { PlannedDay(weekday: $0, session: nil) }
        self.weekTier = 1
        self.weekRPESum = 0
        self.weekRPECount = 0
        self.freeRunTemplateIndex = 0
        self.moveValue = 0
        self.moveGoal = 650
        self.activeValue = 0
        self.activeGoal = 60
        self.runValue = 0
        self.runGoal = 10
        self.streak = 0
        self.xp = 0
        self.readiness = 80
        self.premium = true
        self.onboarded = false
        self.distanceUnit = "km"
        self.coachNotificationsEnabled = true
    }

    // MARK: Derived

    var ringsDone: Int {
        [moveValue >= moveGoal, activeValue >= activeGoal, runValue >= runGoal].filter { $0 }.count
    }

    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: .now).year
    }

    var raceDistanceLabel: String {
        guard let raceDistance else { return "" }
        return raceDistance == .other ? (raceDistanceCustom?.isEmpty == false ? raceDistanceCustom! : "Ta course") : raceDistance.label
    }

    var daysUntilRace: Int? {
        guard let raceDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: raceDate).day ?? 0
        return days >= 0 ? days : nil
    }
}
