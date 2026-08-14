import XCTest
import SwiftData
@testable import RunUp

/// Locks in the training-safety invariants that the plan engine must never lose again.
///
/// These are not coverage-for-coverage's-sake tests. Each one corresponds to a specific defect a
/// running coach flagged as a genuine overuse-injury risk in a generated plan — the kind of bug
/// that ships silently because the app still "works" and the plan still looks plausible on screen.
/// The engine is the one piece of this codebase whose output a real person acts on with their body,
/// so the invariants are asserted on the ACTUAL generated sessions, not on the helpers in isolation.
final class AdaptivePlanEngineSafetyTests: XCTestCase {

    // MARK: - Fixtures

    /// A profile is a `@Model`, so it needs a container to live in. In-memory: these tests must
    /// never touch the real store.
    private var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserProfile.self, configurations: config)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    @MainActor
    private func makeProfile(
        goal: GoalType,
        distance: RaceDistance?,
        weeksUntilRace: Int,
        runningDays: [Int] = [0, 2, 4, 6]
    ) -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.goalId = goal
        profile.level = .intermediaire
        profile.raceDistance = distance
        profile.runningDays = runningDays
        profile.preferredLongRunDay = runningDays.max()
        let start = Date()
        profile.programStartDate = start
        profile.raceDate = Calendar.current.date(byAdding: .weekOfYear, value: weeksUntilRace, to: start)
        container.mainContext.insert(profile)
        return profile
    }

    private func shape(for profile: UserProfile) -> AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(
            goal: profile.goalId,
            raceDate: profile.raceDate,
            from: profile.programStartDate ?? .now
        )
    }

    /// The long run's planned distance for a given week, recovered from the generated session's
    /// duration and the profile's real easy pace — the engine expresses the long run in minutes,
    /// but every training-safety rule is about DISTANCE, so the assertions convert back.
    @MainActor
    private func longRunKm(week: Int, profile: UserProfile) -> Double? {
        let sessions = AdaptivePlanEngine.generateWeekSessions(
            weekNumber: week, tier: profile.weekTier, profile: profile
        )
        let longDay = profile.preferredLongRunDay
        guard let session = sessions.first(where: { $0.weekday == longDay })?.session else { return nil }
        let easySecPerKm = PaceModel.zones(for: profile).easySecPerKm
        guard easySecPerKm > 0 else { return nil }
        return Double(session.durationMinutes) * 60 / easySecPerKm
    }

    // MARK: - Deload weeks exist inside a fixed-length build

    /// Race and HYROX plans used to run the entire Base + Spécifique build with no planned
    /// recovery week at all — the only letup was the final taper. That is the textbook overuse
    /// pattern, and it applied to exactly the two goals carrying the highest load.
    @MainActor
    func testFixedLengthPlanSchedulesCutbackWeeks() {
        let profile = makeProfile(goal: .race, distance: .marathon, weeksUntilRace: 15)
        let s = shape(for: profile)
        let buildWeeks = s.baseWeeks + s.specificWeeks

        let deloads = (1...buildWeeks).filter {
            AdaptivePlanEngine.trainingBlock(forWeek: $0, shape: s) == .deload
        }

        XCTAssertFalse(deloads.isEmpty, "Un plan à date de course doit contenir des semaines de décharge planifiées")
        // Never two build weeks apart by more than 4 without a cutback between them.
        var previous = 0
        for week in deloads {
            XCTAssertLessThanOrEqual(week - previous, 4, "Plus de 4 semaines de charge consécutives sans décharge")
            previous = week
        }
    }

    /// The taper must never also be marked as a deload: it already sheds load by construction, and
    /// stacking a cutback on it would flatten the sharpening it exists to produce.
    @MainActor
    func testTaperIsNeverAlsoADeload() {
        let profile = makeProfile(goal: .race, distance: .semi, weeksUntilRace: 12)
        let s = shape(for: profile)
        guard let total = s.totalWeeks else { return XCTFail("Un objectif course doit avoir une durée totale") }

        for week in (s.baseWeeks + s.specificWeeks + 1)...total {
            XCTAssertEqual(
                AdaptivePlanEngine.trainingBlock(forWeek: week, shape: s), .affutage,
                "La semaine \(week) est dans l'affûtage et ne doit pas être requalifiée en décharge"
            )
        }
    }

    // MARK: - Long-run progression

    /// The defect this exists for: a marathon plan sat at 14 km every Base week, then asked for
    /// 30 km on the first Spécifique week — +115% in one week. The rule of thumb is ~10%/week; the
    /// assertion allows a little headroom for the block boundary but nothing remotely like a cliff.
    @MainActor
    func testLongRunNeverJumpsMoreThanFifteenPercentBetweenLoadWeeks() {
        for (distance, weeks) in [(RaceDistance.marathon, 15), (.semi, 12), (.k10, 9)] {
            let profile = makeProfile(goal: .race, distance: distance, weeksUntilRace: weeks)
            let s = shape(for: profile)
            let buildWeeks = s.baseWeeks + s.specificWeeks

            // Only compare LOAD weeks to LOAD weeks. Returning to the build after a cutback is a
            // return to a load already handled, not a new peak, so it is not a progression step.
            let loadWeeks = (1...buildWeeks).filter {
                AdaptivePlanEngine.trainingBlock(forWeek: $0, shape: s) != .deload
            }
            let distances = loadWeeks.compactMap { longRunKm(week: $0, profile: profile) }
            XCTAssertEqual(distances.count, loadWeeks.count, "\(distance): sortie longue manquante sur une semaine de charge")

            for (previous, next) in zip(distances, distances.dropFirst()) {
                guard previous > 0 else { continue }
                let growth = (next - previous) / previous
                XCTAssertLessThanOrEqual(
                    growth, 0.15,
                    "\(distance): la sortie longue bondit de \(Int(growth * 100))% entre deux semaines de charge"
                )
            }
        }
    }

    /// A cutback should back off from the load actually being carried — not collapse to a fixed
    /// short distance that amounts to detraining mid-build and then has to be climbed back.
    @MainActor
    func testDeloadIsProportionalToCurrentLoadNotAFixedFloor() {
        let profile = makeProfile(goal: .race, distance: .marathon, weeksUntilRace: 15)
        let s = shape(for: profile)
        let buildWeeks = s.baseWeeks + s.specificWeeks

        let deloadWeeks = (2...buildWeeks).filter {
            AdaptivePlanEngine.trainingBlock(forWeek: $0, shape: s) == .deload
        }
        XCTAssertFalse(deloadWeeks.isEmpty, "Aucune semaine de décharge à vérifier")

        for week in deloadWeeks {
            guard let deloadKm = longRunKm(week: week, profile: profile),
                  let previousKm = longRunKm(week: week - 1, profile: profile), previousKm > 0
            else { continue }
            let ratio = deloadKm / previousKm
            XCTAssertLessThan(ratio, 1.0, "Une semaine de décharge doit réduire la sortie longue (S\(week))")
            XCTAssertGreaterThan(
                ratio, 0.45,
                "La décharge de S\(week) coupe à \(Int(ratio * 100))% de la charge précédente — c'est du désentraînement, pas un cutback"
            )
        }
    }

    // MARK: - Weekly intensity distribution

    /// The Spécifique block used to contain only VMA + Tempo outside the long run, so someone
    /// running 4-5 days got 3-4 hard sessions a week and not one easy run — the inverse of the
    /// ~80/20 polarized model. Asserted on a 5-day week, the worst case for the old cycling.
    @MainActor
    func testNeverMoreThanTwoQualitySessionsInAWeek() {
        let profile = makeProfile(
            goal: .race, distance: .marathon, weeksUntilRace: 15,
            runningDays: [0, 1, 2, 4, 6]
        )
        let s = shape(for: profile)
        guard let total = s.totalWeeks else { return XCTFail("Un objectif course doit avoir une durée totale") }

        // Titles the engine uses for genuine quality work. The long run is excluded by design:
        // it is its own role and is never counted against the quality budget.
        let qualityMarkers = ["Fractionné", "Tempo", "Rappel d'allure"]

        for week in 1...total {
            let sessions = AdaptivePlanEngine.generateWeekSessions(
                weekNumber: week, tier: profile.weekTier, profile: profile
            )
            let longDay = profile.preferredLongRunDay
            let qualityCount = sessions
                .filter { $0.weekday != longDay }
                .compactMap { $0.session }
                .filter { session in qualityMarkers.contains { session.title.contains($0) } }
                .count

            XCTAssertLessThanOrEqual(
                qualityCount, 2,
                "S\(week) programme \(qualityCount) séances de qualité hors sortie longue — plafond à 2"
            )
        }
    }

    /// Every build week must offer at least one genuinely easy run outside the long run — the
    /// aerobic base is the point, not filler.
    @MainActor
    func testBuildWeeksAlwaysIncludeAnEasyRun() {
        let profile = makeProfile(
            goal: .race, distance: .marathon, weeksUntilRace: 15,
            runningDays: [0, 1, 2, 4, 6]
        )
        let s = shape(for: profile)
        let buildWeeks = s.baseWeeks + s.specificWeeks

        for week in 1...buildWeeks {
            let sessions = AdaptivePlanEngine.generateWeekSessions(
                weekNumber: week, tier: profile.weekTier, profile: profile
            )
            let longDay = profile.preferredLongRunDay
            let hasEasy = sessions
                .filter { $0.weekday != longDay }
                .compactMap { $0.session }
                .contains { $0.title.contains("Footing") }

            XCTAssertTrue(hasEasy, "S\(week) ne contient aucun footing facile hors sortie longue")
        }
    }

    // MARK: - Taper integrity

    /// `tier` is an accumulator built up across Base and Spécifique. Letting it keep inflating
    /// durations during the taper added 20-30 min to sessions whose entire purpose is to shed load.
    @MainActor
    func testTaperIgnoresAccumulatedTier() {
        let profile = makeProfile(goal: .race, distance: .marathon, weeksUntilRace: 15)
        let s = shape(for: profile)
        guard let total = s.totalWeeks else { return XCTFail("Un objectif course doit avoir une durée totale") }
        let taperWeek = total

        let atTierOne = AdaptivePlanEngine.generateWeekSessions(weekNumber: taperWeek, tier: 1, profile: profile)
        let atTierSix = AdaptivePlanEngine.generateWeekSessions(weekNumber: taperWeek, tier: 6, profile: profile)

        for (low, high) in zip(atTierOne, atTierSix) {
            XCTAssertEqual(
                low.session?.durationMinutes, high.session?.durationMinutes,
                "L'affûtage ne doit pas dépendre du tier accumulé (jour \(low.weekday))"
            )
            XCTAssertNil(high.session?.adjustment, "Aucun badge de niveau ne doit s'afficher pendant l'affûtage")
        }
    }

    // MARK: - Pace zones

    /// At threshold × 0.92 the "VMA" session was only 8% faster than threshold — effectively a
    /// second tempo run, never a VO2max stimulus. Real vVO2max sits ~12-18% faster.
    @MainActor
    func testIntervalPaceIsAGenuineVO2maxStimulus() {
        let profile = makeProfile(goal: .race, distance: .k10, weeksUntilRace: 10)
        let zones = PaceModel.zones(for: profile)

        guard let intervalSec = PaceModel.parseSecPerKm(zones.interval) else {
            return XCTFail("Allure VMA illisible : \(zones.interval)")
        }
        let gap = (zones.thresholdSecPerKm - intervalSec) / zones.thresholdSecPerKm

        XCTAssertGreaterThanOrEqual(gap, 0.11, "L'écart seuil→VMA (\(Int(gap * 100))%) est trop faible pour un vrai stimulus VO2max")
        XCTAssertLessThanOrEqual(gap, 0.20, "L'écart seuil→VMA (\(Int(gap * 100))%) est irréaliste — ce n'est plus une allure tenable sur 800 m")
    }

    /// Ordering sanity: easy must be slower than marathon, which is slower than threshold, which
    /// is slower than interval. A regression that inverts two zones would otherwise be invisible.
    @MainActor
    func testPaceZonesAreCorrectlyOrdered() {
        let profile = makeProfile(goal: .race, distance: .semi, weeksUntilRace: 12)
        let zones = PaceModel.zones(for: profile)

        let paces = [zones.easy, zones.marathon, zones.threshold, zones.interval]
            .compactMap { PaceModel.parseSecPerKm($0) }
        XCTAssertEqual(paces.count, 4, "Une allure de zone est illisible")

        for (slower, faster) in zip(paces, paces.dropFirst()) {
            XCTAssertGreaterThan(slower, faster, "Les zones d'allure doivent aller du plus lent au plus rapide")
        }
    }

    // MARK: - Courses proches : le plan ne doit jamais dépasser la ligne d'arrivée

    /// Le plancher `max(4, weeksUntilRace)` n'écourtait pas un plan trop court, il l'ALLONGEAIT.
    /// Pour une course dans deux semaines il produisait quatre semaines : la course tombait en
    /// semaine 2, donc en bloc « Base » — une sortie longue trois jours avant un marathon — et
    /// l'affûtage était planifié deux semaines APRÈS la ligne d'arrivée.
    ///
    /// C'est le cas d'usage le plus fréquent d'un téléchargement d'app de running : on s'inscrit
    /// à une course, puis on cherche une app.
    @MainActor
    func testShortNoticePlanEndsOnRaceWeekAndIsAllTaper() {
        // 1 et 2 seulement : à 0 la date de course égale le départ, ce qui n'est pas une course
        // proche mais une absence de date exploitable (couvert par le test suivant) ; à 3 on
        // atteint quatre semaines de plan, donc un vrai bloc de construction réapparaît.
        for weeksAway in 1...2 {
            let profile = makeProfile(goal: .race, distance: .marathon, weeksUntilRace: weeksAway)
            let s = shape(for: profile)

            XCTAssertEqual(
                s.totalWeeks, weeksAway + 1,
                "Un plan pour une course dans \(weeksAway) semaine(s) doit se terminer la semaine de la course"
            )
            XCTAssertEqual(s.baseWeeks, 0, "Rien à construire à cette échéance")
            XCTAssertEqual(s.specificWeeks, 0, "Rien à construire à cette échéance")
            XCTAssertEqual(s.taperWeeks, s.totalWeeks, "Tout le plan doit être de l'affûtage")

            // Et surtout : chaque semaine réellement générée est en affûtage, jamais en base.
            for week in 1...(s.totalWeeks ?? 1) {
                XCTAssertEqual(
                    AdaptivePlanEngine.trainingBlock(forWeek: week, shape: s), .affutage,
                    "Semaine \(week) d'un plan à \(weeksAway) semaine(s) doit être en affûtage"
                )
            }
        }
    }

    /// Le seuil de quatre semaines ne doit pas créer de marche : les blocs couvrent toujours
    /// exactement le plan, à toutes les échéances, et un vrai bloc de construction réapparaît
    /// dès qu'il y a de quoi construire.
    @MainActor
    func testPlanBlocksAlwaysSumToTotalAcrossEveryHorizon() {
        for weeksAway in 1...24 {
            let profile = makeProfile(goal: .race, distance: .semi, weeksUntilRace: weeksAway)
            let s = shape(for: profile)
            guard let total = s.totalWeeks else {
                XCTFail("Un objectif course avec une date future doit produire un plan de longueur finie")
                continue
            }
            XCTAssertEqual(
                s.baseWeeks + s.specificWeeks + s.taperWeeks, total,
                "Les blocs doivent couvrir exactement le plan (course dans \(weeksAway) semaines)"
            )
            XCTAssertLessThanOrEqual(total, 20, "Un plan ne dépasse jamais 20 semaines")
            XCTAssertGreaterThanOrEqual(s.taperWeeks, 1, "Il y a toujours au moins une semaine d'affûtage")
            if total >= 4 {
                XCTAssertGreaterThanOrEqual(s.baseWeeks, 1, "Au-delà de 4 semaines, il y a de quoi construire")
            }
        }
    }

    /// Une date de course déjà passée, ou égale au départ, ne périodise rien : le plan doit
    /// retomber sur un plan OUVERT, pas sur un plan de longueur nulle ou négative.
    @MainActor
    func testPastOrSameDayRaceFallsBackToAnOpenEndedPlan() {
        let profile = makeProfile(goal: .race, distance: .k10, weeksUntilRace: 1)
        let start = profile.programStartDate ?? .now

        for offsetDays in [-30, -1, 0] {
            profile.raceDate = Calendar.current.date(byAdding: .day, value: offsetDays, to: start)
            let s = shape(for: profile)
            XCTAssertNil(
                s.totalWeeks,
                "Une course à J\(offsetDays) ne peut pas périodiser un plan — il doit rester ouvert"
            )
        }
    }
}
