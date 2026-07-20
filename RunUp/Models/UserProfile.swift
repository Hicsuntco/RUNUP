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

    /// "female" | "male" | "unspecified" — collected once in onboarding (paired with birthdate).
    /// Only ever used to decide whether to offer cycle-tracking and folded into `CoachService`'s
    /// system prompt like every other onboarding fact; never used to gate any other feature.
    var sex: String? = nil

    // MARK: Cycle-aware training — opt-in, only ever offered when `sex == "female"`. Estimated
    // from real user-provided dates (same spirit as `readiness`: honestly approximate, never
    // fabricated) — see `cyclePhase` below. No HealthKit menstrual-flow sync yet; that's a real
    // future upgrade path, but a manual start date works from day one for everyone regardless of
    // whether they already log cycle data in Apple Santé.
    var cycleTrackingEnabled: Bool = false
    var lastPeriodStartDate: Date? = nil
    var averageCycleLengthDays: Int = 28

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
    /// "open" | "pro" — only ever populated when `goalId == .hyrox`. Reuses `raceDate` (event
    /// date) and `raceChrono` (target finish time) rather than adding parallel fields, since
    /// they mean the same thing for a HYROX goal; `PaceModel.referenceThresholdPace`'s
    /// `.race`-only guard already keeps `raceChrono` from being misparsed as a running-race split.
    var hyroxDivision: String? = nil

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
    /// Which weekday carries the long run — chosen at onboarding
    /// (`OnboardingViewModel.effectiveLongRunDay`), falls back to the latest `runningDays` entry
    /// for profiles that predate this field. `AdaptivePlanEngine.generateWeekSessions` places the
    /// long-run archetype here specifically, instead of wherever it lands positionally.
    var preferredLongRunDay: Int?
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

    // MARK: Daily goals
    // Séance du jour / Calories actives / Pas, reset each calendar day (see
    // `AdaptivePlanEngine.resetDailyGoalsIfNewDay`). Deliberately 3 distinct behaviors rather
    // than 3 measures of the same run (the old Bouger/Actif/Courir always moved together).
    // Tracks the last day these were reset, so a day rollover can be detected and self-heals
    // like `programStartDate` for profiles that predate this field.
    var lastDailyResetDay: Date?
    /// Was "Renfo & mobilité" (strength/mobility minutes) — replaced because a *daily* strength
    /// target doesn't match real training guidance (2-3x/week, not every day), which made the
    /// goal honestly near-impossible rather than motivating. Active calories work for everyone
    /// day to day (including non-Watch users — see `HealthKitService.activeCaloriesToday`) and a
    /// real daily-appropriate target.
    var activeCaloriesToday: Double = 0
    var activeCaloriesGoal: Double = 400
    var stepsToday: Double = 0
    var stepsGoal: Double = 6000
    /// Whether the "all daily goals done" +120 XP bonus (see
    /// `AdaptivePlanEngine.checkDailyGoalsBonus`) has already been granted today — without this,
    /// re-checking `dailyGoalsDone == dailyGoalsTotal` on every HealthKit sync would regrant it
    /// repeatedly.
    var dailyGoalsBonusAwarded: Bool = false
    /// Distance run today (km) — no longer part of the daily-goals widget, but still used
    /// elsewhere (Club leaderboard, program-end summary) as a rough recent-activity figure.
    var runValue: Double
    var runGoal: Double

    // MARK: Gamification
    var streak: Int
    var xp: Int
    /// Last up to 5 debrief severities (`3 - RPE.rawValue`, so 0 = facile ... 3 = tropDur, same
    /// scale the weekly tier adaptation already uses) — feeds the real `readiness` score below.
    /// Capped and updated in `AdaptivePlanEngine.applyDebrief`.
    var recentRPESeverities: [Int] = []

    // MARK: Meta
    /// No paid tier ships in this version — everyone gets full access. Kept as a field (rather
    /// than removed outright) so a future real subscription can gate on it without a migration.
    var premium: Bool
    var onboarded: Bool
    var distanceUnit: String
    var coachNotificationsEnabled: Bool
    /// Which `AccentTheme` swatch the user picked in Profil → Apparence — mirrored into
    /// `ThemeStore.shared` on load so `RUColor.rose`/`.rose2`/`.violet` reflect it everywhere.
    var accentThemeID: String = AccentTheme.defaultID
    /// Dark (default) or light app-wide theme — same mirror-into-`ThemeStore` pattern as
    /// `accentThemeID`, see `RUColor`'s theme-aware tokens.
    var isLightMode: Bool = false
    /// The kudos count last seen per own posted activity (`FeedItem.id`) — lets `ClubView` notice
    /// when someone new claps for one of your runs and post a real notification for it, instead
    /// of silently refetching the same feed over and over.
    var kudosSeenCounts: [String: Int] = [:]
    /// Same idea as `kudosSeenCounts` but for comments — lets `ClubView` notice when someone
    /// leaves a new comment on one of your own posted activities.
    var commentsSeenCounts: [String: Int] = [:]
    /// Real progress counters that gate the App Store review prompt (see
    /// `AppState.shouldRequestReview`) — asking right after a genuinely positive moment, at
    /// meaningful milestones, never on a fixed schedule or every single run.
    var completedDebriefsCount: Int = 0
    var lastReviewPromptDate: Date? = nil

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
        self.hyroxDivision = nil
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
        self.runValue = 0
        self.runGoal = 10
        self.streak = 0
        self.xp = 0
        self.premium = true
        self.onboarded = false
        self.distanceUnit = "km"
        self.coachNotificationsEnabled = true
    }

    // MARK: Derived

    private var todayWeekdayIndex: Int {
        (Calendar.current.component(.weekday, from: .now) + 5) % 7
    }

    /// True once today's planned session is done, or trivially true on a rest day (nothing was
    /// asked of you). Falls back to `false` if `weekSessions` hasn't been generated yet.
    var seanceDoneToday: Bool {
        guard let day = weekSessions.first(where: { $0.weekday == todayWeekdayIndex }) else { return false }
        guard let session = day.session, session.durationMinutes > 0 else { return true }
        return day.completed
    }

    /// True when today has no planned session at all — distinct from `seanceDoneToday`, which is
    /// trivially `true` on a rest day too (so the daily-goals bonus isn't blocked by a day off).
    /// UI reads this to show "Repos" instead of "Faite" — showing a run as "done" on a day nothing
    /// was ever planned reads as a bug (a gauge claiming a session happened with nothing in
    /// History to back it).
    var isRestDayToday: Bool {
        guard let day = weekSessions.first(where: { $0.weekday == todayWeekdayIndex }) else { return false }
        guard let session = day.session else { return true }
        return session.durationMinutes == 0
    }

    /// [Séance du jour, Calories actives, Pas] as 0...1 fractions, in that order — feeds
    /// `DailyGoalsBarsView`. On a rest day there's no real "séance" goal to close, so that slot
    /// stays at 0 rather than the trivially-true `seanceDoneToday` — a gauge showing full for a
    /// goal nothing ever asked of you reads as a bug (the same complaint already fixed for the
    /// "Faite"/"Repos" label; this is the bar underneath it, which still filled to 100% either way).
    var dailyGoalsProgress: [Double] {
        [
            isRestDayToday ? 0 : (seanceDoneToday ? 1 : 0),
            activeCaloriesGoal > 0 ? min(1, activeCaloriesToday / activeCaloriesGoal) : 0,
            stepsGoal > 0 ? min(1, stepsToday / stepsGoal) : 0
        ]
    }

    var dailyGoalsDone: Int {
        dailyGoalsProgress.filter { $0 >= 1 }.count
    }

    /// Real goals to close today — 2 on a rest day (no session was ever asked of you), 3
    /// otherwise. Drives the "X / Y bouclés" copy and the +120 XP bonus threshold below, so the
    /// bonus stays reachable on a rest day from the other 2 goals alone, without needing a fake
    /// "séance" credit to get there.
    var dailyGoalsTotal: Int { isRestDayToday ? 2 : 3 }

    /// False until at least one session has a real RPE behind it — the readiness ring reads as a
    /// confident, near-full gauge ("bonne forme !") the moment it shows any number at all, which
    /// is misleading before there's a single real data point feeding it. UI should show an honest
    /// "pas encore de données" state instead of `readiness` while this is false.
    var hasReadinessData: Bool { !recentRPESeverities.isEmpty }

    /// Real "forme du jour" score — computed, not a static value, from the severity trend of your
    /// last few sessions (`recentRPESeverities`, 0 = facile ... 3 = tropDur) and how many
    /// consecutive days you've trained without rest. No lab-grade recovery data (HRV, sleep) —
    /// just what's already tracked locally, but genuinely responsive instead of a fixed 80.
    /// Meaningless before `hasReadinessData` — callers should check that first.
    var readiness: Int {
        guard !recentRPESeverities.isEmpty else { return 80 }
        let avgSeverity = Double(recentRPESeverities.reduce(0, +)) / Double(recentRPESeverities.count)
        let severityAdjustment = (1.5 - avgSeverity) * 12 // easier recent sessions → higher score
        let streakPenalty = min(12, Double(max(0, streak - 3)) * 2) // fatigue past a 3-day run without rest
        let score = 82 + severityAdjustment - streakPenalty
        return Int(max(35, min(98, score)))
    }

    /// Short label for `readiness` — drives the readiness card's copy instead of a fixed
    /// "excellente" regardless of the actual score.
    var readinessLabel: String {
        switch readiness {
        case 85...: return "excellente"
        case 65..<85: return "bonne"
        case 50..<65: return "correcte"
        default: return "à surveiller"
        }
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

    enum CyclePhase: String {
        case menstrual, follicular, ovulation, luteal
    }

    /// Estimated from `lastPeriodStartDate` + `averageCycleLengthDays` via a standard
    /// proportional phase model — real user-provided data, honestly approximate (same spirit as
    /// `readiness`), never a fabricated guess. `nil` unless she's opted in and given a start
    /// date; `AdaptivePlanEngine` treats `nil` as "no adjustment" rather than assuming a phase.
    var cyclePhase: CyclePhase? {
        guard cycleTrackingEnabled, let lastPeriodStartDate else { return nil }
        let length = max(21, min(35, averageCycleLengthDays))
        let daysSince = Calendar.current.dateComponents([.day], from: lastPeriodStartDate, to: .now).day ?? 0
        guard daysSince >= 0 else { return nil }
        let cycleDay = (daysSince % length) + 1 // 1-indexed, wraps every `length` days
        let ovulationDay = length / 2

        switch cycleDay {
        case 1...5: return .menstrual
        case (ovulationDay - 1)...(ovulationDay + 1): return .ovulation
        case 6..<(ovulationDay - 1): return .follicular
        default: return .luteal
        }
    }
}
