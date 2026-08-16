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
    /// When the recovery phase actually began — recovery days used to advance one per TAP of
    /// "JOUR SUIVANT" (N quick taps skipped recovery entirely; never opening the app never
    /// advanced it). Now derived from this real date, same mechanism as `programStartDate` above.
    /// Optional for the same migrate-as-nil-and-self-heal reason.
    var recoveryStartedAt: Date?
    /// Course libre's own "séance faite" tracking — set by `AdaptivePlanEngine.applyDebrief` when
    /// `programPhase == .freerun`. Free-run's `todaySession` is a template picked independently
    /// of `weekSessions` (see `chooseFreeRun`), so reading `weekSessions`-based `seanceDoneToday`/
    /// `isRestDayToday` in that mode meant checking a plan that has nothing to do with what's
    /// actually being offered — stale (or absent) `weekSessions` entries made the session card
    /// claim "faite" on a day nothing was done, while the goals ring (reading the same stale data
    /// differently) said "Repos" at the same time.
    var freeRunSessionDoneDate: Date?
    /// A real uploaded profile photo — compressed client-side before storage (see
    /// `ProfileView.setAvatar`), shown here and anywhere else an avatar appears (Home's header
    /// button, Club leaderboard/feed once signed in — see `AuthService.updateAvatar`). Nil falls
    /// back to the initial-letter gradient circle every avatar spot already used.
    /// External storage — `UserProfile` is the app's hottest-written model (every debrief, every
    /// goal edit rewrites it), and without this a several-hundred-KB JPEG blob would be
    /// re-serialized on every one of those unrelated writes instead of living in its own file.
    @Attribute(.externalStorage) var avatarImageData: Data?
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
    /// The one calendar day `AdaptivePlanEngine.applySameDayAdjustmentIfNeeded` has already
    /// checked — guards against re-running (and re-easing an already-eased session, or fighting a
    /// manual edit) on every single HealthKit sync of the same day. Nil for anyone who hasn't hit
    /// that code path yet, same self-healing spirit as `lastDailyResetDay`.
    var lastSameDayAdjustmentCheckDay: Date?
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
    /// Date of the last debrief that counted toward `streak` — what lets the série actually
    /// reset after a real gap (and not double-count a 2-session day). Optional so profiles from
    /// before this field existed migrate as nil (their first debrief just continues the streak).
    var lastStreakDate: Date?
    var xp: Int
    /// Last up to 5 debrief severities (`3 - RPE.rawValue`, so 0 = facile ... 3 = tropDur, same
    /// scale the weekly tier adaptation already uses) — feeds the real `readiness` score below.
    /// Capped and updated in `AdaptivePlanEngine.applyDebrief`.
    var recentRPESeverities: [Int] = []
    /// The pair auto-attached to every new run (GPS or "FAIT") so tracking wear doesn't require
    /// picking a shoe on every single run — `ShoesView` is where this actually gets set. `nil`
    /// until she's added at least one pair, or after her only/default pair is retired.
    var defaultShoeID: UUID? = nil

    // MARK: Meta
    /// No paid tier ships in this version — everyone gets full access. Kept as a field (rather
    /// than removed outright) so a future real subscription can gate on it without a migration.
    var premium: Bool
    var onboarded: Bool
    var distanceUnit: String
    var coachNotificationsEnabled: Bool
    /// Auto-pause at a stop (red light, water fountain) during a live run — on by default, like
    /// Strava/Garmin, but some runners find it fights real short walk breaks in an interval
    /// session, so it's a real opt-out, not just a hidden behavior.
    var autoPauseEnabled: Bool = true
    /// Spoken pace-zone nudges during a live run ("accélère un peu" / "ralentis légèrement") when
    /// her real recent pace drifts off the session's target — on by default (this is the one
    /// place a competitor's "voice coaching" is usually just a scripted clip; RunUp's is a real
    /// comparison against her actual GPS pace), but a real opt-out for anyone who'd rather run in
    /// silence or just glance at the screen.
    var paceAlertsEnabled: Bool = true
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
    /// Every `ClubBadgeCatalog` key already shown as a full-screen unlock celebration (see
    /// `BadgeUnlockedView`) — same idea as `kudosSeenCounts`, a persisted "already surfaced" set so
    /// `ClubView` can tell a newly-crossed threshold apart from a badge that's simply been earned
    /// since before this feature existed, and never re-celebrate the same badge on a later launch.
    var seenBadgeKeys: [String] = []
    /// False until `ClubView` has run its FIRST badge-diff pass on this device. That first pass
    /// backfills `seenBadgeKeys` with every badge already earned WITHOUT celebrating any of them —
    /// without this flag, every existing player with a streak/distance badge from months ago would
    /// get a false "just unlocked!" full-screen cover the moment they first open Club after this
    /// feature ships (an empty `seenBadgeKeys` on that first pass looks identical to a genuinely
    /// brand-new profile that hasn't earned anything yet, so the two cases can't be told apart
    /// without a separate marker).
    var didBackfillSeenBadges: Bool = false

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
        self.goalDisplay = String(localized: "Rester en forme")
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
    /// Course libre reads its own tracking instead — see `freeRunSessionDoneDate`.
    var seanceDoneToday: Bool {
        if programPhase == .freerun {
            guard let date = freeRunSessionDoneDate else { return false }
            return Calendar.current.isDateInToday(date)
        }
        guard let day = weekSessions.first(where: { $0.weekday == todayWeekdayIndex }) else { return false }
        guard let session = day.session, session.durationMinutes > 0 else { return true }
        return day.completed
    }

    /// True when today has no planned session at all — distinct from `seanceDoneToday`, which is
    /// trivially `true` on a rest day too (so the daily-goals bonus isn't blocked by a day off).
    /// UI reads this to show "Repos" instead of "Faite" — showing a run as "done" on a day nothing
    /// was ever planned reads as a bug (a gauge claiming a session happened with nothing in
    /// History to back it). Course libre has no rest-day concept — a session is always on offer,
    /// optional, every day — so this is always `false` there.
    var isRestDayToday: Bool {
        if programPhase == .freerun { return false }
        guard let day = weekSessions.first(where: { $0.weekday == todayWeekdayIndex }) else { return false }
        guard let session = day.session else { return true }
        return session.durationMinutes == 0
    }

    /// Sum of every planned session's distance this week (`durationMinutes / pace`, same
    /// conversion `PaceModel` already uses elsewhere) — `weekSessions` only ever holds the CURRENT
    /// week's plan, so this is always "this week's real target," not a stale or hypothetical
    /// number. Feeds the Club "% objectif" leaderboard mode: synced up so a mixed-level club can
    /// rank by how close each member is to THEIR OWN plan, not raw km, which flattens a beginner's
    /// 15 km week and a marathoner's 60 km week onto the same scale. 0 for course libre (no fixed
    /// weekly plan to measure against) or before `weekSessions` has ever been generated.
    var plannedWeeklyKm: Double {
        guard programPhase != .freerun else { return 0 }
        return weekSessions.reduce(0) { total, day in
            guard let session = day.session, let secPerKm = PaceModel.parseSecPerKm(session.pace), secPerKm > 0 else { return total }
            return total + Double(session.durationMinutes * 60) / secPerKm
        }
    }

    /// [Séance du jour, Calories actives, Pas] as 0...1 fractions, in that order — feeds
    /// `DailyGoalsBarsView`. On a rest day there's no real "séance" goal to close, so that slot
    /// stays at 0 rather than the trivially-true `seanceDoneToday` — a gauge showing full for a
    /// goal nothing ever asked of you reads as a bug (the same complaint already fixed for the
    /// "Faite"/"Repos" label; this is the bar underneath it, which still filled to 100% either way).
    var dailyGoalsProgress: [Double] {
        Self.dailyGoalsProgress(sessionDone: isRestDayToday ? nil : seanceDoneToday, steps: stepsToday, stepsGoal: stepsGoal, activeCalories: activeCaloriesToday, activeCaloriesGoal: activeCaloriesGoal)
    }

    var dailyGoalsDone: Int {
        dailyGoalsProgress.filter { $0 >= 1 }.count
    }

    /// Real goals to close today — 2 on a rest day (no session was ever asked of you), 3
    /// otherwise. Drives the "X / Y bouclés" copy and the +120 XP bonus threshold below, so the
    /// bonus stays reachable on a rest day from the other 2 goals alone, without needing a fake
    /// "séance" credit to get there.
    var dailyGoalsTotal: Int { isRestDayToday ? 2 : 3 }

    /// [Séance du jour, Calories actives, Pas] as 0...1 fractions — the same shape as
    /// `dailyGoalsProgress` above (which now just calls this for `.now`), pulled out into a pure
    /// function so `RingsView`'s day browser can compute an honest ring for ANY past date without
    /// duplicating the "rest day excludes the séance slot" logic. `sessionDone: nil` means rest
    /// day (no séance goal existed that day) — matches `isRestDayToday`'s semantics.
    static func dailyGoalsProgress(sessionDone: Bool?, steps: Double, stepsGoal: Double, activeCalories: Double, activeCaloriesGoal: Double) -> [Double] {
        [
            sessionDone == true ? 1 : 0,
            activeCaloriesGoal > 0 ? min(1, activeCalories / activeCaloriesGoal) : 0,
            stepsGoal > 0 ? min(1, steps / stepsGoal) : 0
        ]
    }

    /// Best-effort "was this weekday a running day" for a date that isn't necessarily in the
    /// current week — `weekSessions` only ever holds the CURRENT week's plan (regenerated at
    /// every week boundary, older weeks aren't retained), so there's no way to know exactly what
    /// was planned on an older date. `runningDays` is the stable weekly pattern the plan is built
    /// around and rarely changes, so it's the honest best answer available rather than guessing —
    /// same spirit as `isRestDayToday`, just without a real `weekSessions` entry to read.
    func isRunningDay(weekday: Int) -> Bool {
        runningDays.contains(weekday)
    }

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
        // A single debrief shouldn't be enough to swing all the way to "excellente" or "à
        // surveiller" — confidence ramps in over the first 3 data points, so severity's pull on
        // the score starts weak and only reaches full strength once there's a real trend behind it.
        let confidence = min(1, Double(recentRPESeverities.count) / 3)
        let severityAdjustment = (1.5 - avgSeverity) * 12 * confidence // easier recent sessions → higher score
        let streakPenalty = min(12, Double(max(0, streak - 3)) * 2) // fatigue past a 3-day run without rest
        let score = 82 + severityAdjustment - streakPenalty
        return Int(max(35, min(98, score)))
    }

    /// Short label for `readiness` — drives the readiness card's copy instead of a fixed
    /// "excellente" regardless of the actual score.
    var readinessLabel: String {
        switch readiness {
        case 85...: return String(localized: "excellente")
        case 65..<85: return String(localized: "bonne")
        case 50..<65: return String(localized: "correcte")
        default: return String(localized: "à surveiller")
        }
    }

    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: .now).year
    }

    var raceDistanceLabel: String {
        guard let raceDistance else { return "" }
        return raceDistance == .other ? (raceDistanceCustom?.isEmpty == false ? raceDistanceCustom! : String(localized: "Ta course")) : raceDistance.label
    }

    /// Real numeric race distance in km — a preset's fixed value, or a best-effort parse of the
    /// free-text `raceDistanceCustom` (".other", e.g. "Trail 22 km", "15 km") when she typed a
    /// distance instead of picking a preset. `RaceDistance.km` itself always returns nil for
    /// `.other` (a bare enum case can't hold the free-text number) — every place that scales pace
    /// or long-run distance to the real race goal should read this instead, so a custom distance
    /// doesn't silently fall back to a generic reference the way `raceDistance?.km` alone would.
    /// Compiled once — this getter is read from `StatsView`'s body on every render for a
    /// race-goal user, and `.range(of:options:.regularExpression)` re-compiles the pattern per
    /// call.
    /// Anchored to a "km" suffix (comma or dot decimals) — a bare first-number grab turned
    /// "EcoTrail 2026 80 km" into a 2026 km race and "Course des 3 Châteaux 15 km" into 3 km,
    /// then fed that into every pace projection.
    private static let customDistanceRegex = /(\d+(?:[.,]\d+)?)\s*(?:km|k\b)/.ignoresCase()

    var effectiveRaceDistanceKm: Double? {
        if let km = raceDistance?.km { return km }
        guard raceDistance == .other, let custom = raceDistanceCustom,
              let match = custom.firstMatch(of: Self.customDistanceRegex),
              let km = Double(match.1.replacingOccurrences(of: ",", with: ".")), km > 0, km < 500
        else { return nil }
        return km
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
