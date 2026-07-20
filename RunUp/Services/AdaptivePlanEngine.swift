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

    static let restSession = WorkoutSession(title: "Repos", subtitle: "Jour de repos — laisse ton corps récupérer", durationMinutes: 0, pace: "—", zone: "—", adjustment: nil)

    // MARK: Onboarding → initial program

    struct OnboardingResult {
        var name: String
        var birthdate: Date?
        var sex: String?
        var goal: GoalType
        var raceDistance: RaceDistance?
        var raceDistanceCustom: String?
        var raceChrono: String?
        var raceDate: Date?
        var hyroxDivision: String?
        var runningDays: [Int]
        /// Which weekday (0=Monday...6=Sunday) carries the long run — chosen at onboarding, see
        /// `OnboardingViewModel.effectiveLongRunDay`.
        var preferredLongRunDay: Int?
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
        var cycleTrackingEnabled: Bool
        var lastPeriodStartDate: Date?
        var averageCycleLengthDays: Int
    }

    static func applyOnboarding(_ result: OnboardingResult, to profile: UserProfile) {
        profile.name = result.name.isEmpty ? "Toi" : result.name
        profile.birthdate = result.birthdate
        profile.sex = result.sex
        profile.goalId = result.goal
        profile.raceDistance = result.raceDistance
        profile.raceDistanceCustom = result.raceDistanceCustom
        profile.raceChrono = result.raceChrono
        profile.raceDate = result.raceDate
        profile.hyroxDivision = result.hyroxDivision
        profile.runningDays = result.runningDays
        profile.preferredLongRunDay = result.preferredLongRunDay
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
        profile.cycleTrackingEnabled = result.cycleTrackingEnabled
        profile.lastPeriodStartDate = result.lastPeriodStartDate
        profile.averageCycleLengthDays = result.averageCycleLengthDays
        profile.goalDisplay = goalDisplay(goal: result.goal, distance: result.raceDistance, custom: result.raceDistanceCustom, chrono: result.raceChrono, hyroxDivision: result.hyroxDivision)
        profile.onboarded = true
        profile.programPhase = .active
        profile.weekNumber = 1
        profile.programStartDate = .now
        // Confirmed runners start with more volume than beginners from week 1, instead of
        // everyone starting at the same tier regardless of declared level — level only used to
        // feed the coach's system prompt before this.
        let tier = startingTier(for: result.level)
        profile.weekTier = tier
        beginWeek(weekNumber: 1, tier: tier, profile: profile)
    }

    private static func startingTier(for level: ExperienceLevel) -> Int {
        switch level {
        case .debutante: return 1
        case .intermediaire: return 2
        case .confirmee: return 3
        }
    }

    private static var mondayCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday — matches the app's L-M-M-J-V-S-D week strip.
        return cal
    }

    /// Advances `weekNumber`/`weekStrip`/`weekSessions` (and, once the program's real length is
    /// reached, `programPhase`) to match the device's real calendar date — call each time the app
    /// becomes active. This needs no network access: the device clock is available offline, so a
    /// real day/week always ticks forward on its own without the app having to be opened on a
    /// fixed schedule.
    static func refreshProgramForCurrentDate(_ profile: UserProfile) {
        guard profile.programPhase == .active else { return }

        // Backfill for any profile that never had a real week plan generated — migrated from a
        // build before this existed, or a launch that returned early below before reaching it.
        // Independent of every other branch here so it can never be skipped.
        if profile.weekSessions.count != 7 {
            profile.weekSessions = generateWeekSessions(weekNumber: profile.weekNumber, tier: profile.weekTier, profile: profile)
            let today = currentWeekdayIndex()
            profile.todaySession = profile.weekSessions.first(where: { $0.weekday == today })?.session ?? restSession
        }

        guard let startDate = profile.programStartDate else {
            // Pre-existing profile from before this field was tracked: adopt "now" as the
            // block's start so future launches can measure elapsed weeks from a real date.
            profile.programStartDate = .now
            return
        }

        let cal = mondayCalendar
        let startOfStartWeek = cal.dateInterval(of: .weekOfYear, for: startDate)?.start ?? startDate
        let startOfThisWeek = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let elapsedWeeks = max(0, cal.dateComponents([.weekOfYear], from: startOfStartWeek, to: startOfThisWeek).weekOfYear ?? 0)

        // Race goals periodize toward the real race date (a program for a race 6 weeks out is
        // shorter than one for a race 16 weeks out); every other goal has no finish line to
        // periodize toward, so it never auto-ends here — see `ProgramShape`.
        let shape = ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: startDate)
        if let totalWeeks = shape.totalWeeks, elapsedWeeks >= totalWeeks {
            endProgram(profile)
            return
        }

        let today = currentWeekdayIndex()
        let newWeekNumber = elapsedWeeks + 1

        if newWeekNumber != profile.weekNumber {
            // Crossed into a new week: adapt the tier from last week's average RPE — the plan
            // only ever changes here, never after a single run — then regenerate the whole week.
            profile.weekTier = max(1, profile.weekTier + tierDelta(sum: profile.weekRPESum, count: profile.weekRPECount))
            beginWeek(weekNumber: newWeekNumber, tier: profile.weekTier, profile: profile)
        } else {
            // Same week, just a day rolled over: move the "today" marker and pick up today's
            // already-planned session — no regeneration, this week was fully planned upfront
            // (the backfill above already covers a plan that was missing entirely). A running day
            // that's now in the past without ever being completed (app wasn't opened that day)
            // reads as neutral (`.rest`), not "upcoming" — it can't be upcoming if it's over.
            profile.weekStrip = profile.weekStrip.map { day in
                guard day.state != .rest, day.state != .done else { return day }
                var d = day
                if day.weekday == today {
                    d.state = .today
                } else if day.weekday < today {
                    d.state = .rest
                } else {
                    d.state = .upcoming
                }
                return d
            }
            profile.todaySession = profile.weekSessions.first(where: { $0.weekday == today })?.session ?? restSession
        }
    }

    /// Resets week-scoped state (strip, plan, RPE accumulator) and generates a fresh 7-day plan —
    /// shared by onboarding, week-boundary adaptation, and starting a new program.
    private static func beginWeek(weekNumber: Int, tier: Int, profile: UserProfile) {
        let today = currentWeekdayIndex()
        profile.weekNumber = weekNumber
        profile.weekRPESum = 0
        profile.weekRPECount = 0
        let cal = mondayCalendar
        let startOfThisWeek = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        profile.weekStrip = (0..<7).map { i in
            let state: DayStatus.State
            if !profile.runningDays.contains(i) {
                state = .rest
            } else if i == today {
                state = .today
            } else if i < today {
                // A running day that's already behind us this week (the plan is only being
                // generated now, mid-week — e.g. onboarding finishing on a Thursday) was never
                // "upcoming" to begin with.
                state = .rest
            } else {
                state = .upcoming
            }
            let date = cal.date(byAdding: .day, value: i, to: startOfThisWeek) ?? .now
            return DayStatus(weekday: i, letter: DayStatus.letters[i], state: state, date: date)
        }
        profile.weekSessions = generateWeekSessions(weekNumber: weekNumber, tier: tier, profile: profile)
        profile.todaySession = profile.weekSessions.first(where: { $0.weekday == today })?.session ?? restSession
    }

    // MARK: Daily goals

    /// Resets Calories actives/Pas back to 0 (and lets `runValue` fall back to 0 too) the first
    /// time this runs on a new calendar day — call unconditionally on every foreground, regardless
    /// of `programPhase`, since daily goals apply in recovery/free-run too. `Séance du jour` needs
    /// no reset here: it's computed live from `weekSessions`, which regenerates on its own schedule.
    static func resetDailyGoalsIfNewDay(_ profile: UserProfile) {
        let today = Calendar.current.startOfDay(for: .now)
        guard profile.lastDailyResetDay != today else { return }
        profile.lastDailyResetDay = today
        profile.activeCaloriesToday = 0
        profile.stepsToday = 0
        profile.runValue = 0
        profile.dailyGoalsBonusAwarded = false
    }

    /// Grants the "all 3 daily goals done" +120 XP bonus the first time all 3 are complete on a
    /// given day — call after anything that can flip a goal to done (HealthKit sync, run
    /// debrief). Returns whether it was newly granted, so callers can post it to the club feed /
    /// show a toast. Previously `RingsView`'s "JOURNÉE BOUCLÉE" state showed a "+120 XP" label
    /// with no XP ever actually granted — this is the real version of that.
    @discardableResult
    static func checkDailyGoalsBonus(_ profile: UserProfile) -> Bool {
        guard !profile.dailyGoalsBonusAwarded, profile.dailyGoalsDone == profile.dailyGoalsTotal else { return false }
        profile.dailyGoalsBonusAwarded = true
        profile.xp += 120
        return true
    }

    /// Reverses today's "séance faite" flag — call when the `RunRecord` behind it gets deleted
    /// from History, so the daily-goals gauge stops claiming a session is done with nothing left
    /// backing it. Deliberately narrow: only clears today's completion, never touches streak/XP
    /// (those aren't safely reversible without knowing exactly what this one run contributed —
    /// other activity may already have built on top of them since).
    static func undoTodaySessionCompletion(_ profile: UserProfile) {
        let today = currentWeekdayIndex()
        guard let idx = profile.weekSessions.firstIndex(where: { $0.weekday == today }) else { return }
        profile.weekSessions[idx].completed = false
        profile.weekStrip = profile.weekStrip.map { day in
            guard day.weekday == today, day.state == .done else { return day }
            var d = day
            d.state = .today
            return d
        }
    }

    /// Tier change to apply at a week boundary, from the previous week's average RPE severity
    /// (`3 - RPE.rawValue`, so 0 = facile, 3 = tropDur). No runs logged → no change.
    private static func tierDelta(sum: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let avg = Double(sum) / Double(count)
        if avg <= 1.5 { return 1 }   // mostly facile/juste bien → progress
        if avg <= 2.5 { return 0 }   // mostly dur → hold steady
        return -1                   // mostly trop dur → ease off
    }

    /// Today's index in the app's Monday-first week (0 = Monday … 6 = Sunday), derived from the
    /// real calendar date rather than hardcoded — `Calendar.component(.weekday)` is Sunday-first
    /// (1...7), so this remaps it.
    private static func currentWeekdayIndex() -> Int {
        (Calendar.current.component(.weekday, from: .now) + 5) % 7
    }

    // MARK: Periodization

    /// Program length + block boundaries. Race goals periodize toward the *real* race date
    /// (a program for a race 6 weeks out is shorter than one for a race 16 weeks out, capped to a
    /// sane 4–20 week range) — replacing a fixed 9 weeks for everyone regardless of how far away
    /// the race actually was. Every other goal (progress/weight/restart/health) has no finish
    /// line to periodize toward, so it's open-ended: `totalWeeks == nil` means it rolls
    /// indefinitely via a repeating deload cycle (see `trainingBlock`) until the user ends it
    /// manually (Profil → "Terminer le programme").
    struct ProgramShape {
        var totalWeeks: Int?
        var baseWeeks: Int
        var specificWeeks: Int
        var taperWeeks: Int

        static func compute(goal: GoalType, raceDate: Date?, from startDate: Date) -> ProgramShape {
            guard goal == .race || goal == .hyrox, let raceDate, raceDate > startDate else {
                return ProgramShape(totalWeeks: nil, baseWeeks: 0, specificWeeks: 0, taperWeeks: 0)
            }
            let weeksUntilRace = Calendar.current.dateComponents([.weekOfYear], from: startDate, to: raceDate).weekOfYear ?? 9
            let total = max(4, min(20, weeksUntilRace))
            let taper = max(1, Int((Double(total) * 0.15).rounded()))
            let specific = max(1, Int((Double(total) * 0.35).rounded()))
            let base = max(1, total - taper - specific)
            return ProgramShape(totalWeeks: total, baseWeeks: base, specificWeeks: specific, taperWeeks: taper)
        }
    }

    /// The named blocks a program moves through. `.deload` only appears in the open-ended
    /// (non-race) cycle — every 4th week backs off instead of piling on volume indefinitely.
    enum TrainingBlock: String {
        case base = "Base", specifique = "Spécifique", affutage = "Affûtage", deload = "Récup"
    }

    static func trainingBlock(forWeek week: Int, shape: ProgramShape) -> TrainingBlock {
        guard let total = shape.totalWeeks else {
            return week % 4 == 0 ? .deload : .base
        }
        if week > total { return .affutage } // shouldn't happen (refreshProgramForCurrentDate ends the program first), but never crash on it
        if week <= shape.baseWeeks { return .base }
        if week <= shape.baseWeeks + shape.specificWeeks { return .specifique }
        return .affutage
    }

    private enum SessionRole { case easy, speed, longRun }

    private struct SessionArchetype {
        var role: SessionRole
        var title: String
        var subtitle: String
        var pace: String
        var zone: String
        var baseDuration: Int
    }

    /// Reference distance (km) the long run scales toward — the user's real race distance when
    /// known, otherwise a generic 10K-ish reference so the long run still makes sense for
    /// progress/weight/restart/health goals.
    private static func referenceRaceKm(_ raceDistance: RaceDistance?) -> Double {
        raceDistance?.km ?? 10
    }

    private static func archetypes(for block: TrainingBlock, profile: UserProfile) -> [SessionArchetype] {
        let zones = PaceModel.zones(for: profile)
        let raceKm = referenceRaceKm(profile.raceDistance)

        func longRunDuration(_ km: Double) -> Int {
            max(20, Int((km * zones.easySecPerKm / 60).rounded()))
        }

        let base: [SessionArchetype]
        switch block {
        case .base:
            let longRunKm = min(raceKm * 0.55, 14)
            base = [
                SessionArchetype(role: .easy, title: "Footing tranquille", subtitle: "installe l'endurance de fond, allure confort", pace: zones.easy, zone: "Z2", baseDuration: 30),
                SessionArchetype(role: .speed, title: "Fractionné léger 5 × 500 m", subtitle: "récup 300 m · garde le tonus sans se cramer", pace: zones.threshold, zone: "Z3", baseDuration: 32),
                SessionArchetype(role: .longRun, title: "Sortie longue", subtitle: "allonge progressivement la distance", pace: zones.easy, zone: "Z2", baseDuration: longRunDuration(longRunKm))
            ]
        case .specifique:
            let longRunKm = min(raceKm * 0.8, 30)
            base = [
                SessionArchetype(role: .speed, title: "Fractionné VMA 6 × 800 m", subtitle: "récup 400 m · travaille la vitesse", pace: zones.interval, zone: "Z4", baseDuration: 40),
                SessionArchetype(role: .speed, title: "Tempo run", subtitle: "allure seuil soutenue", pace: zones.threshold, zone: "Z3", baseDuration: 35),
                SessionArchetype(role: .longRun, title: "Sortie longue", subtitle: "bloc spécifique, un peu d'allure course", pace: zones.marathon, zone: "Z2-3", baseDuration: longRunDuration(longRunKm))
            ]
        case .affutage:
            let longRunKm = max(6, raceKm * 0.35)
            base = [
                SessionArchetype(role: .easy, title: "Footing d'entretien", subtitle: "relâché, garde les jambes fraîches", pace: zones.easy, zone: "Z2", baseDuration: 25),
                SessionArchetype(role: .speed, title: "Rappel d'allure 3 × 1 km", subtitle: "à l'allure visée le jour J", pace: zones.marathon, zone: "Z3", baseDuration: 25),
                SessionArchetype(role: .longRun, title: "Sortie courte", subtitle: "décharge avant l'objectif", pace: zones.easy, zone: "Z2", baseDuration: longRunDuration(longRunKm))
            ]
        case .deload:
            base = [
                SessionArchetype(role: .easy, title: "Footing récup", subtitle: "coupe le volume, écoute tes jambes", pace: zones.easy, zone: "Z1-2", baseDuration: 22),
                SessionArchetype(role: .speed, title: "Footing tonique", subtitle: "quelques accélérations libres, sans chrono", pace: zones.threshold, zone: "Z2-3", baseDuration: 28),
                SessionArchetype(role: .longRun, title: "Sortie longue allégée", subtitle: "aucune pression de distance cette semaine", pace: zones.easy, zone: "Z2", baseDuration: longRunDuration(min(raceKm * 0.4, 8)))
            ]
        }

        return adjustForWellbeing(base, profile: profile)
    }

    /// HYROX-specific archetypes: real running still anchors pace/effort (via `PaceModel`, same as
    /// every other goal), but the week is built around the format's actual demand — running under
    /// accumulated fatigue from functional stations, not a continuous road-race build. Deliberately
    /// never states a precise competition kg figure (see `HyroxDivision`) — sessions describe
    /// structure/technique/effort, which stays true across seasons and skill levels instead of
    /// risking a stale or wrong "real" number.
    private static func hyroxArchetypes(for block: TrainingBlock, profile: UserProfile) -> [SessionArchetype] {
        let zones = PaceModel.zones(for: profile)
        let division = profile.hyroxDivision.flatMap { HyroxDivision(rawValue: $0) } ?? .open
        let loadNote = division == .pro ? "charge renforcée" : "charge standard"

        let base: [SessionArchetype]
        switch block {
        case .base:
            base = [
                SessionArchetype(role: .easy, title: "Footing base HYROX", subtitle: "endurance de fond — construit le volume de course du format", pace: zones.easy, zone: "Z2", baseDuration: 30),
                SessionArchetype(role: .speed, title: "Fonctionnel HYROX · Technique", subtitle: "SkiErg, rameur, farmers carry, wall balls — travaille le geste, \(loadNote) légère", pace: "—", zone: "Technique", baseDuration: 35),
                SessionArchetype(role: .longRun, title: "Course compromise 3 × 1 km", subtitle: "course + bloc fonctionnel entre chaque km — apprivoise la fatigue du format", pace: zones.easy, zone: "Z2-3", baseDuration: 40)
            ]
        case .specifique:
            base = [
                SessionArchetype(role: .speed, title: "Fonctionnel HYROX · Circuit intense", subtitle: "stations enchaînées à intensité course, sous fatigue, \(loadNote)", pace: "—", zone: "Z3-4", baseDuration: 40),
                SessionArchetype(role: .speed, title: "Tempo course + sled", subtitle: "allure seuil entrecoupée de sled push/pull", pace: zones.threshold, zone: "Z3", baseDuration: 35),
                SessionArchetype(role: .longRun, title: "Course compromise 6 × 1 km", subtitle: "simulation partielle : course + fonctionnel enchaînés, rythme course visé", pace: zones.marathon, zone: "Z3", baseDuration: 55)
            ]
        case .affutage:
            base = [
                SessionArchetype(role: .easy, title: "Footing d'entretien", subtitle: "relâché, garde les jambes et les bras frais", pace: zones.easy, zone: "Z2", baseDuration: 25),
                SessionArchetype(role: .speed, title: "Rappel technique stations", subtitle: "gestes affûtés, charge légère, aucune fatigue à accumuler", pace: "—", zone: "Technique", baseDuration: 25),
                SessionArchetype(role: .longRun, title: "Simulation HYROX allégée", subtitle: "format complet à intensité réduite — dernière répétition avant le jour J", pace: zones.marathon, zone: "Z2-3", baseDuration: 45)
            ]
        case .deload:
            base = [
                SessionArchetype(role: .easy, title: "Footing récup", subtitle: "coupe le volume, écoute ton corps", pace: zones.easy, zone: "Z1-2", baseDuration: 22),
                SessionArchetype(role: .speed, title: "Fonctionnel léger", subtitle: "mobilité et gestes techniques, sans charge", pace: "—", zone: "Récup", baseDuration: 25),
                SessionArchetype(role: .longRun, title: "Course compromise légère 2 × 1 km", subtitle: "aucune pression de chrono cette semaine", pace: zones.easy, zone: "Z2", baseDuration: 30)
            ]
        }

        return adjustForWellbeing(base, profile: profile)
    }

    /// Real, human-readable label for the raw onboarding id — `CoachService` used to interpolate
    /// the raw id ("knee") straight into the coach's system prompt instead of this.
    static func injuryLabel(_ id: String) -> String {
        switch id {
        case "knee": return "genou"
        case "ankle": return "cheville"
        case "back": return "dos"
        case "other": return "zone sensible"
        default: return id
        }
    }

    /// Eases the week's plan around a flagged injury and/or the estimated cycle phase — never
    /// changes the *shape* of the week (still easy/speed/longRun), only lightens the load and
    /// says so honestly in the subtitle, rather than silently deviating from what's printed.
    /// Both signals are opt-in/user-provided (`profile.injuryArea`, `profile.cyclePhase`), so
    /// this is a no-op for anyone who hasn't shared either.
    private static func adjustForWellbeing(_ archetypes: [SessionArchetype], profile: UserProfile) -> [SessionArchetype] {
        var result = archetypes
        let injury = profile.injuryArea
        let hasInjury = injury != nil && injury != "none"

        if hasInjury, let injury {
            result = result.map { a in
                guard a.role == .speed else { return a }
                var eased = a
                // Title is left as-is (still "Fractionné VMA 6 × 800 m" etc.) — SessionDetailSheet
                // parses the real rep count straight out of it; only the load actually eases.
                eased.subtitle = "adapté à ta \(injuryLabel(injury)) sensible · impact réduit"
                eased.zone = "Z2-3"
                eased.baseDuration = Int(Double(a.baseDuration) * 0.7)
                return eased
            }
        }

        // Every phase gets a real, distinct treatment — not just menstrual with the other three
        // silently ignored. Grounded in general exercise-physiology guidance (energy/recovery
        // capacity shifts across the cycle), framed as a nudge to listen to her body, never as a
        // medical claim.
        if let phase = profile.cyclePhase {
            result = result.map { a in
                var eased = a
                switch phase {
                case .menstrual:
                    // Energy/recovery capacity is typically lowest here — ease the whole week.
                    eased.baseDuration = Int(Double(a.baseDuration) * 0.85)
                    if a.role == .speed { eased.subtitle += " · allégé (phase menstruelle)" }
                case .luteal:
                    // Progesterone rise can raise perceived effort for the same real pace — a
                    // lighter touch than menstrual, and only on the hardest session.
                    if a.role == .speed {
                        eased.baseDuration = Int(Double(a.baseDuration) * 0.92)
                        eased.subtitle += " · vise le ressenti plus que le chrono (phase lutéale)"
                    }
                case .follicular:
                    // Rising estrogen typically means rising energy/recovery capacity — a real
                    // green light, not just "no adjustment".
                    if a.role == .speed { eased.subtitle += " · bon moment pour pousser (phase folliculaire)" }
                case .ovulation:
                    // Often the cycle's real performance peak — session stays exactly as planned,
                    // said explicitly rather than leaving it unremarked.
                    if a.role == .speed { eased.subtitle += " · pic de forme estimé, allure comme prévu (ovulation)" }
                }
                return eased
            }
        }

        return result
    }

    /// Builds the full 7-day plan for a given week: archetypes come from the training block
    /// (itself derived from `ProgramShape`, so it reflects the real weeks-until-race or the
    /// open-ended deload cycle), paces from `PaceModel` (seeded from the user's real target time/
    /// best recent performance/level), and the long run always lands on the user's chosen day
    /// (`preferredLongRunDay`) rather than wherever it happens to cycle to positionally. Scaled by
    /// `tier` — the only place session duration/labeling changes, and it only ever runs once per
    /// week (see `refreshProgramForCurrentDate`), never per individual run.
    static func generateWeekSessions(weekNumber: Int, tier: Int, profile: UserProfile) -> [PlannedDay] {
        let shape = ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
        let block = trainingBlock(forWeek: weekNumber, shape: shape)
        let templates = profile.goalId == .hyrox ? hyroxArchetypes(for: block, profile: profile) : archetypes(for: block, profile: profile)
        let sortedRunDays = profile.runningDays.sorted()

        let longRunDay = profile.preferredLongRunDay.flatMap { sortedRunDays.contains($0) ? $0 : nil } ?? sortedRunDays.max()
        let longTemplate = templates.first { $0.role == .longRun }
        let otherTemplates = templates.filter { $0.role != .longRun }

        var otherIndex = 0
        return (0..<7).map { weekday in
            guard sortedRunDays.contains(weekday) else { return PlannedDay(weekday: weekday, session: nil) }

            let archetype: SessionArchetype
            if weekday == longRunDay, let longTemplate {
                archetype = longTemplate
            } else if !otherTemplates.isEmpty {
                archetype = otherTemplates[otherIndex % otherTemplates.count]
                otherIndex += 1
            } else {
                archetype = templates[0]
            }

            let session = WorkoutSession(
                title: archetype.title,
                subtitle: archetype.subtitle,
                durationMinutes: archetype.baseDuration + (tier - 1) * 4,
                pace: archetype.pace,
                zone: archetype.zone,
                adjustment: tier > 1 ? "Niveau \(tier)" : nil
            )
            return PlannedDay(weekday: weekday, session: session)
        }
    }

    private static func goalDisplay(goal: GoalType, distance: RaceDistance?, custom: String?, chrono: String?, hyroxDivision: String? = nil) -> String {
        switch goal {
        case .race:
            let label = distance == .other ? (custom?.isEmpty == false ? custom! : "Ta course") : (distance?.label ?? "Ta course")
            let chronoLabel = (chrono?.isEmpty ?? true) ? "finir" : chrono!
            return "\(label) · \(chronoLabel)"
        case .progress: return "Progresser"
        case .restart: return "Reprise en douceur"
        case .weight: return "Perte de poids"
        case .health: return "Rester en forme"
        case .hyrox:
            let divisionLabel = hyroxDivision.flatMap { HyroxDivision(rawValue: $0)?.title }
            let chronoLabel = (chrono?.isEmpty ?? true) ? "finir" : chrono!
            return divisionLabel.map { "HYROX \($0) · \(chronoLabel)" } ?? "HYROX · \(chronoLabel)"
        }
    }

    // MARK: Live run → history

    static func fmt(_ seconds: Double) -> String {
        let s = max(0, seconds)
        return "\(Int(s / 60)):\(String(format: "%02d", Int(s.truncatingRemainder(dividingBy: 60))))"
    }

    /// `realSplitSeconds` is the actual elapsed time between consecutive whole-km GPS crossings
    /// (see `LiveRunViewModel`) — when available, splits are the real pace-per-km the runner
    /// actually ran, not a formula-shaped curve. Falls back to that formula only for the
    /// no-GPS "Marquer comme faite" path, where there's no real per-km data to derive splits
    /// from at all (and that record's splits are never shown in the UI either way).
    static func buildRunRecord(
        title: String,
        elapsedSeconds: Double,
        distanceKm: Double,
        kcal: Double,
        avgHeartRate: Int,
        elevationGainM: Int = 0,
        realSplitSeconds: [Double]? = nil,
        route: [RunRecord.RoutePoint] = []
    ) -> RunRecord {
        let dist = max(0.4, distanceKm)
        let t = max(30, elapsedSeconds)
        let secPerKm = t / dist
        let splits: [String]
        if let realSplitSeconds, !realSplitSeconds.isEmpty {
            splits = realSplitSeconds.map { fmt(max(0, $0)) }
        } else {
            let nkm = max(1, Int(dist))
            splits = (0..<nkm).map { i -> String in
                let sec = secPerKm - 8 + Double(i) * 3 + (i == nkm - 1 ? -10 : 0)
                return fmt(max(230, sec))
            }
        }
        return RunRecord(
            title: title,
            distanceKm: dist,
            durationSeconds: Int(t),
            avgPace: fmt(secPerKm),
            avgHeartRate: avgHeartRate,
            kcal: Int(kcal.rounded()),
            elevationGainM: elevationGainM,
            splits: splits,
            route: route
        )
    }

    // MARK: Debrief → rings/streak/xp/weekly RPE accumulator

    /// Records this run's outcome but does **not** change any session — today's and the rest of
    /// the week's sessions were already planned when the week began. The RPE just feeds the
    /// accumulator that `refreshProgramForCurrentDate` averages at the next week boundary, and
    /// (separately) the rolling window `UserProfile.readiness` reads for "forme du jour".
    @discardableResult
    static func applyDebrief(rpe: RPE, run: RunRecord, profile: UserProfile) -> String {
        profile.runValue = min(profile.runGoal, ((profile.runValue + run.distanceKm) * 100).rounded() / 100)
        let today = currentWeekdayIndex()
        profile.weekStrip = profile.weekStrip.map { day in
            var d = day
            if d.state == .today { d.state = .done }
            return d
        }
        if let idx = profile.weekSessions.firstIndex(where: { $0.weekday == today }) {
            profile.weekSessions[idx].completed = true
        }
        let severity = 3 - rpe.rawValue // 0 = facile ... 3 = tropDur, same scale UserProfile.readiness reads
        profile.weekRPESum += severity
        profile.weekRPECount += 1
        profile.recentRPESeverities.append(severity)
        if profile.recentRPESeverities.count > 5 { profile.recentRPESeverities.removeFirst() }
        profile.streak += 1
        profile.xp += 120
        profile.completedDebriefsCount += 1
        return "Programme mis à jour · +120 XP"
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
        var raceDate: Date?
        var runningDays: [Int]
    }

    static func startNewProgram(_ result: NewGoalResult, profile: UserProfile) {
        profile.goalId = result.goal
        profile.raceDistance = result.distance
        profile.raceChrono = result.chrono
        profile.raceDate = result.goal == .race ? result.raceDate : nil
        profile.goalDisplay = goalDisplay(goal: result.goal, distance: result.distance, custom: nil, chrono: result.chrono)
        profile.runningDays = result.runningDays
        profile.preferredLongRunDay = result.runningDays.max()
        profile.programPhase = .active
        profile.programStartDate = .now
        profile.recoveryDaysLeft = 0
        profile.weekTier = startingTier(for: profile.level)
        beginWeek(weekNumber: 1, tier: profile.weekTier, profile: profile)
    }
}
