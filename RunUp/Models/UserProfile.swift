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
    var programPhase: ProgramPhase
    var recoveryDaysLeft: Int
    /// 0 = Monday ... 6 = Sunday.
    var runningDays: [Int]
    var todaySession: WorkoutSession
    var weekStrip: [DayStatus]
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
        self.programPhase = .active
        self.recoveryDaysLeft = 0
        self.runningDays = [0, 1, 3, 5]
        self.todaySession = .reprise
        self.weekStrip = (0..<7).map { DayStatus(weekday: $0, letter: DayStatus.letters[$0], state: .upcoming) }
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
        self.premium = false
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
