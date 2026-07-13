import Foundation

/// Pure business logic for the adaptive-plan mechanic — ported from `app.jsx`
/// (`finishOb`, `stopRun`, `finishDebrief`, `endProgram`, `tickRecovery`, `chooseFreeRun`,
/// `startNewProgram`). Kept free of SwiftData/SwiftUI so it's easy to reason about and test;
/// callers (ViewModels) pass in a `UserProfile` to mutate and get back a toast string.
enum AdaptivePlanEngine {
    static let freeRunTemplates: [WorkoutSession] = [
        WorkoutSession(title: "Footing d'entretien", subtitle: "allure confort · reconnecte avec le plaisir de courir", durationMinutes: 35, pace: "5:40", zone: "Z2", adjustment: nil),
        WorkoutSession(title: "Fractionné léger 5 × 500 m", subtitle: "récup 300 m · garde le tonus sans se cramer", durationMinutes: 32, pace: "4:35", zone: "Z3", adjustment: nil),
        WorkoutSession(title: "Sortie découverte", subtitle: "change d'itinéraire, explore un nouveau parcours", durationMinutes: 45, pace: "5:30", zone: "Z2", adjustment: nil)
    ]

    // MARK: Onboarding → initial program

    struct OnboardingResult {
        var name: String
        var birthdate: Date?
        var goal: GoalType
        var raceDistance: RaceDistance?
        var raceDistanceCustom: String?
        var raceChrono: String?
        var raceDate: Date?
        var runningDays: [Int]
        var level: ExperienceLevel
        var connectedSources: [ConnectedSource]
        var weightNowKg: Double?
        var weightTargetKg: Double?
        var heightCm: Double?
        var focusArea: String?
        var bestRecentPerf: String?
        var lastRanRecency: String?
        var injuryArea: String?
        var weeklyTimeBudget: String?
        var preferredTimeOfDay: String?
    }

    static func applyOnboarding(_ result: OnboardingResult, to profile: UserProfile) {
        profile.name = result.name.isEmpty ? "Toi" : result.name
        profile.birthdate = result.birthdate
        profile.goalId = result.goal
        profile.raceDistance = result.raceDistance
        profile.raceDistanceCustom = result.raceDistanceCustom
        profile.raceChrono = result.raceChrono
        profile.raceDate = result.raceDate
        profile.runningDays = result.runningDays
        profile.level = result.level
        profile.connectedSources = result.connectedSources
        profile.weightNowKg = result.weightNowKg
        profile.weightTargetKg = result.weightTargetKg
        profile.heightCm = result.heightCm
        profile.focusArea = result.focusArea
        profile.bestRecentPerf = result.bestRecentPerf
        profile.lastRanRecency = result.lastRanRecency
        profile.injuryArea = result.injuryArea
        profile.weeklyTimeBudget = result.weeklyTimeBudget
        profile.preferredTimeOfDay = result.preferredTimeOfDay
        profile.goalDisplay = goalDisplay(goal: result.goal, distance: result.raceDistance, custom: result.raceDistanceCustom, chrono: result.raceChrono)
        profile.weekStrip = (0..<7).map { i in
            let state: DayStatus.State = result.runningDays.contains(i) ? (i == 3 ? .today : .upcoming) : .rest
            return DayStatus(weekday: i, letter: DayStatus.letters[i], state: state)
        }
        profile.onboarded = true
        profile.programPhase = .active
        profile.weekNumber = 1
    }

    private static func goalDisplay(goal: GoalType, distance: RaceDistance?, custom: String?, chrono: String?) -> String {
        switch goal {
        case .race:
            let label = distance == .other ? (custom?.isEmpty == false ? custom! : "Ta course") : (distance?.label ?? "Ta course")
            let chronoLabel = (chrono?.isEmpty ?? true) ? "finir" : chrono!
            return "\(label) · \(chronoLabel)"
        case .progress: return "Progresser"
        case .restart: return "Reprise en douceur"
        case .weight: return "Perte de poids"
        case .health: return "Rester en forme"
        }
    }

    // MARK: Live run → history

    static func fmt(_ seconds: Double) -> String {
        let s = max(0, seconds)
        return "\(Int(s / 60)):\(String(format: "%02d", Int(s.truncatingRemainder(dividingBy: 60))))"
    }

    static func buildRunRecord(title: String, elapsedSeconds: Double, distanceKm: Double, kcal: Double, avgHeartRate: Int) -> RunRecord {
        let dist = max(0.4, distanceKm)
        let t = max(30, elapsedSeconds)
        let secPerKm = t / dist
        let nkm = max(1, Int(dist))
        let splits = (0..<nkm).map { i -> String in
            let sec = secPerKm - 8 + Double(i) * 3 + (i == nkm - 1 ? -10 : 0)
            return fmt(max(230, sec))
        }
        return RunRecord(
            title: title,
            distanceKm: dist,
            durationSeconds: Int(t),
            avgPace: fmt(secPerKm),
            avgHeartRate: avgHeartRate,
            kcal: Int(kcal.rounded()),
            splits: splits
        )
    }

    // MARK: Debrief → rings/streak/xp/next session

    @discardableResult
    static func applyDebrief(rpe: RPE, run: RunRecord, profile: UserProfile) -> String {
        profile.moveValue = min(profile.moveGoal, profile.moveValue + Double(run.kcal))
        profile.activeValue = min(profile.activeGoal, (profile.activeValue + Double(run.durationSeconds) / 60).rounded())
        profile.runValue = min(profile.runGoal, ((profile.runValue + run.distanceKm) * 100).rounded() / 100)
        profile.weekStrip = profile.weekStrip.map { day in
            var d = day
            if d.state == .today { d.state = .done }
            return d
        }
        profile.streak += 1
        profile.xp += 120
        profile.todaySession = nextSession(after: rpe, current: profile.todaySession)
        return "Programme mis à jour · +120 XP"
    }

    private static func nextSession(after rpe: RPE, current: WorkoutSession) -> WorkoutSession {
        switch rpe {
        case .facile, .justeBien:
            return WorkoutSession(
                title: bumpedTitle(current.title),
                subtitle: "progression · récup 400 m",
                durationMinutes: current.durationMinutes + 4,
                pace: current.pace,
                zone: current.zone,
                adjustment: "+1 palier"
            )
        case .dur:
            return WorkoutSession(title: current.title, subtitle: current.subtitle, durationMinutes: current.durationMinutes, pace: current.pace, zone: current.zone, adjustment: nil)
        case .tropDur:
            return WorkoutSession(title: "Récupération active", subtitle: "allure confort · laisse le corps récupérer", durationMinutes: 30, pace: "5:40", zone: "Z2", adjustment: "allégée")
        }
    }

    private static func bumpedTitle(_ title: String) -> String {
        guard let range = title.range(of: #"\d+"#, options: .regularExpression),
              let n = Int(title[range]) else { return title }
        return title.replacingCharacters(in: range, with: String(n + 1))
    }

    // MARK: Program-end flow

    static func endProgram(_ profile: UserProfile) {
        profile.programPhase = .recovery
        profile.recoveryDaysLeft = profile.goalId.recoveryDays
    }

    static func tickRecovery(_ profile: UserProfile) {
        let left = profile.recoveryDaysLeft - 1
        if left <= 0 {
            profile.recoveryDaysLeft = 0
            profile.programPhase = .choice
        } else {
            profile.recoveryDaysLeft = left
        }
    }

    static func chooseFreeRun(_ profile: UserProfile) {
        let template = freeRunTemplates.first ?? .reprise
        profile.programPhase = .freerun
        profile.goalId = .health
        profile.goalDisplay = "Course libre"
        profile.todaySession = template
        profile.freeRunTemplateIndex = 0
    }

    struct NewGoalResult {
        var goal: GoalType
        var distance: RaceDistance?
        var chrono: String?
        var runningDays: [Int]
    }

    static func startNewProgram(_ result: NewGoalResult, profile: UserProfile) {
        profile.goalId = result.goal
        profile.raceDistance = result.distance
        profile.raceChrono = result.chrono
        profile.goalDisplay = goalDisplay(goal: result.goal, distance: result.distance, custom: nil, chrono: result.chrono)
        profile.runningDays = result.runningDays
        profile.programPhase = .active
        profile.weekNumber = 1
        profile.recoveryDaysLeft = 0
        if result.goal == .race {
            profile.raceDate = Calendar.current.date(byAdding: .day, value: 63, to: .now)
        }
        profile.weekStrip = (0..<7).map { i in
            let state: DayStatus.State = result.runningDays.contains(i) ? (i == 3 ? .today : .upcoming) : .rest
            return DayStatus(weekday: i, letter: DayStatus.letters[i], state: state)
        }
        profile.todaySession = .reprise
    }
}
