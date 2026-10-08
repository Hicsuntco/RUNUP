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
        runningDays: [Int] = [0, 2, 4, 6],
        elevationM: Int? = nil
    ) -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.goalId = goal
        profile.level = .intermediaire
        profile.raceDistance = distance
        profile.raceElevationGainM = elevationM
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

    // MARK: - Ultra-trail : les mêmes garde-fous, dans une autre unité

    /// Les quatre épreuves qui couvrent le monde de l'ultra : du 50 km de montagne au 100 miles,
    /// plus un format long mais PLAT, qui ne doit pas déclencher les mêmes séances.
    private static let coursesDultra: [(nom: String, distance: RaceDistance, dplus: Int, semaines: Int)] = [
        ("50 km / 3 000 m", .ultra50, 3000, 14),
        ("80 km / 4 000 m", .ultra80, 4000, 16),
        ("100 km / 6 000 m", .ultra100, 6000, 18),
        ("100 miles / 10 000 m", .ultra100M, 10000, 20),
        ("50 km roulant / 500 m", .ultra50, 500, 14)
    ]

    /// Les types de séance qui SONT la sortie longue d'une semaine d'ultra.
    ///
    /// On la retrouve par son `kind` et non par le jour de la semaine : quand la course demande un
    /// enchaînement, le couple de jours peut glisser d'un cran, donc la longue ne tombe pas
    /// forcément sur le jour préféré. `.ultraNightRun` en est volontairement exclue — elle est
    /// classée dans la famille « sortie longue » pour sa couleur, mais c'est une séance d'une
    /// heure à durée fixe, pas la charge de la semaine.
    private static let sortiesLonguesDultra: Set<SessionKind> = [
        .ultraLongRun, .ultraSpecificLongRun, .ultraBackToBackDay1, .easedLongRun
    ]

    @MainActor
    private func ultraLongRunMinutes(week: Int, profile: UserProfile) -> Int? {
        AdaptivePlanEngine.generateWeekSessions(weekNumber: week, tier: 1, profile: profile)
            .compactMap(\.session)
            .filter { seance in seance.kind.map { Self.sortiesLonguesDultra.contains($0) } ?? false }
            .map(\.durationMinutes)
            .max()
    }

    /// LE DÉFAUT LE PLUS COÛTEUX DE TOUT L'OBJECTIF, ET IL ÉTAIT INVISIBLE.
    ///
    /// `ProgramShape.compute` ne périodisait que `.race` et `.hyrox` — la liste était écrite en
    /// dur au milieu de la fonction. Un objectif d'ultra-trail tombait donc dans la branche
    /// « programme ouvert » : zéro semaine de base, zéro de spécifique, zéro d'affûtage, et un
    /// cycle base/décharge qui tourne indéfiniment.
    ///
    /// Les onze séances d'ultra existaient, le moteur savait les produire, et il n'en servait
    /// jamais que deux blocs sur quatre. Pas de bloc spécifique, donc aucune sortie longue
    /// spécifique, aucun enchaînement du week-end, aucune sortie de nuit. Et pas d'affûtage : un
    /// ultra abordé fatiguée.
    @MainActor
    func testUltraPlanActuallyPeriodizesTowardTheRaceDate() {
        XCTAssertTrue(GoalType.ultraTrail.periodiseVersUneDate, "Un ultra-trail a une ligne d'arrivée")

        for course in Self.coursesDultra {
            let profile = makeProfile(goal: .ultraTrail, distance: course.distance,
                                      weeksUntilRace: course.semaines, elevationM: course.dplus)
            let s = shape(for: profile)
            guard let total = s.totalWeeks else {
                XCTFail("\(course.nom) : un ultra avec une date doit produire un plan de longueur finie")
                continue
            }
            XCTAssertEqual(s.baseWeeks + s.specificWeeks + s.taperWeeks, total,
                           "\(course.nom) : les blocs doivent couvrir exactement le plan")
            XCTAssertGreaterThanOrEqual(s.baseWeeks, 1, "\(course.nom) : il faut un bloc de base")
            XCTAssertGreaterThanOrEqual(s.specificWeeks, 1, "\(course.nom) : il faut un bloc spécifique")
            XCTAssertGreaterThanOrEqual(s.taperWeeks, 1, "\(course.nom) : un ultra sans affûtage s'aborde fatiguée")
        }
    }

    /// La rampe est la même qu'ailleurs — elle ne sait pas ce qu'elle rampe — mais il fallait
    /// encore lui donner la bonne quantité, et RACCORDER les deux blocs.
    ///
    /// Le défaut que ce test verrouille : le bloc spécifique repartait des deux tiers de SA
    /// cible, pas de là où la base s'était arrêtée. Comme la rampe ne dépasse jamais +10 %/semaine
    /// à l'intérieur d'un bloc, la base finit souvent sous sa cible nominale — et le premier
    /// week-end du spécifique sautait alors de plus de 30 % d'un coup.
    @MainActor
    func testUltraLongRunNeverJumpsMoreThanFifteenPercentBetweenLoadWeeks() {
        for course in Self.coursesDultra {
            let profile = makeProfile(goal: .ultraTrail, distance: course.distance,
                                      weeksUntilRace: course.semaines, elevationM: course.dplus)
            let s = shape(for: profile)
            let buildWeeks = s.baseWeeks + s.specificWeeks
            guard buildWeeks >= 2 else { continue }

            // Charge contre charge seulement : revenir au build après une décharge n'est pas un
            // pas de progression, c'est un retour à une charge déjà encaissée.
            let loadWeeks = (1...buildWeeks).filter {
                AdaptivePlanEngine.trainingBlock(forWeek: $0, shape: s) != .deload
            }
            let durees = loadWeeks.compactMap { ultraLongRunMinutes(week: $0, profile: profile) }
            XCTAssertEqual(durees.count, loadWeeks.count,
                           "\(course.nom) : sortie longue manquante sur une semaine de charge")

            for i in durees.indices.dropLast() {
                let avant = durees[i]
                let apres = durees[i + 1]
                guard avant > 0 else { continue }
                let croissance = (Double(apres) - Double(avant)) / Double(avant)
                XCTAssertLessThanOrEqual(
                    croissance, 0.15,
                    "\(course.nom) : la sortie longue bondit de \(Int(croissance * 100))% entre S\(loadWeeks[i]) (\(avant) min) et S\(loadWeeks[i + 1]) (\(apres) min)"
                )
            }
        }
    }

    /// Une décharge se déduit de la charge RÉELLEMENT portée. Le bloc n'existait pas du tout —
    /// `ultraTrailArchetypes` ne traitait que base / spécifique / affûtage — et une valeur fixe
    /// aurait fait tomber une préparation de 100 km de cinq heures à une heure : ce n'est plus un
    /// cutback, c'est une semaine perdue qu'il faudra regrimper.
    @MainActor
    func testUltraDeloadBacksOffWithoutDetraining() {
        var vues = 0
        for course in Self.coursesDultra {
            let profile = makeProfile(goal: .ultraTrail, distance: course.distance,
                                      weeksUntilRace: course.semaines, elevationM: course.dplus)
            let s = shape(for: profile)
            let buildWeeks = s.baseWeeks + s.specificWeeks
            let deloads = (2...max(2, buildWeeks)).filter {
                $0 <= buildWeeks && AdaptivePlanEngine.trainingBlock(forWeek: $0, shape: s) == .deload
            }
            for semaine in deloads {
                guard let allegee = ultraLongRunMinutes(week: semaine, profile: profile),
                      let avant = ultraLongRunMinutes(week: semaine - 1, profile: profile), avant > 0
                else { continue }
                vues += 1
                let ratio = Double(allegee) / Double(avant)
                XCTAssertLessThan(ratio, 1.0, "\(course.nom) : S\(semaine) est une décharge et ne réduit rien")
                XCTAssertGreaterThan(
                    ratio, 0.45,
                    "\(course.nom) : la décharge de S\(semaine) coupe à \(Int(ratio * 100))% — c'est du désentraînement"
                )
            }
        }
        XCTAssertGreaterThan(vues, 0, "Aucune semaine de décharge vérifiée : le test ne prouve rien")
    }

    /// L'affûtage doit ALLÉGER. La première version du modèle d'effort portait un plancher commun
    /// aux trois blocs, et pour une course courte l'affûtage prescrivait alors la même sortie
    /// longue que le bloc de base. Ici on le vérifie sur les séances réellement produites, pas
    /// sur le modèle en isolation.
    @MainActor
    func testUltraTaperIsLighterThanEverythingThatPrecedesIt() {
        for course in Self.coursesDultra {
            let profile = makeProfile(goal: .ultraTrail, distance: course.distance,
                                      weeksUntilRace: course.semaines, elevationM: course.dplus)
            let s = shape(for: profile)
            guard let total = s.totalWeeks else { continue }
            let buildWeeks = s.baseWeeks + s.specificWeeks
            guard buildWeeks >= 1, total > buildWeeks else { continue }

            guard let plusLongueDuBuild = (1...buildWeeks).compactMap({ ultraLongRunMinutes(week: $0, profile: profile) }).max() else {
                return XCTFail("\(course.nom) : aucune sortie longue sur le build")
            }
            for semaine in (buildWeeks + 1)...total {
                guard let affutage = ultraLongRunMinutes(week: semaine, profile: profile) else {
                    return XCTFail("\(course.nom) : S\(semaine) est en affûtage et n'a pas de sortie longue")
                }
                XCTAssertLessThan(
                    affutage, plusLongueDuBuild,
                    "\(course.nom) : l'affûtage de S\(semaine) (\(affutage) min) n'allège pas le build (\(plusLongueDuBuild) min)"
                )
            }
        }
    }

    /// Le plafond de deux séances dures par semaine vaut aussi en ultra — et les côtes et la
    /// descente y sont bien comptées comme dures (voir `SessionKind.family`), parce que les
    /// ranger ailleurs les ferait passer sous ce garde-fou.
    ///
    /// Compté par FAMILLE et non par titre : les libellés sont traduits, donc une assertion sur
    /// « Fractionné » ne vaut que sur un simulateur en français (voir `FeedLocalizationTests`).
    @MainActor
    func testUltraNeverMoreThanTwoQualitySessionsInAWeek() {
        for course in Self.coursesDultra {
            let profile = makeProfile(goal: .ultraTrail, distance: course.distance,
                                      weeksUntilRace: course.semaines, elevationM: course.dplus,
                                      runningDays: [0, 1, 2, 4, 5, 6])
            let s = shape(for: profile)
            guard let total = s.totalWeeks else { continue }

            for semaine in 1...total {
                let dures = AdaptivePlanEngine.generateWeekSessions(weekNumber: semaine, tier: 1, profile: profile)
                    .compactMap(\.session)
                    .filter { $0.family == .intervals || $0.family == .tempo }
                    .count
                XCTAssertLessThanOrEqual(
                    dures, 2,
                    "\(course.nom) : S\(semaine) programme \(dures) séances dures — plafond à 2"
                )
            }
        }
    }

    /// Chaque semaine de build garde au moins une séance d'endurance pure hors sortie longue. En
    /// ultra, le socle aérobie EST la préparation ; une semaine qui n'est que du dénivelé et de la
    /// descente n'en construit pas.
    @MainActor
    func testUltraBuildWeeksAlwaysIncludeAnEnduranceSession() {
        let profile = makeProfile(goal: .ultraTrail, distance: .ultra100, weeksUntilRace: 18,
                                  elevationM: 6000, runningDays: [0, 2, 4, 5, 6])
        let s = shape(for: profile)
        let buildWeeks = s.baseWeeks + s.specificWeeks

        for semaine in 1...buildWeeks {
            let seances = AdaptivePlanEngine.generateWeekSessions(weekNumber: semaine, tier: 1, profile: profile)
                .compactMap(\.session)
            XCTAssertTrue(
                seances.contains { $0.family == .endurance || $0.family == .recovery },
                "S\(semaine) ne contient aucune séance d'endurance ou de récupération"
            )
        }
    }

    // MARK: - L'enchaînement du week-end

    /// LA SÉANCE SIGNATURE DE L'ULTRA, ET LA SEULE DU MOTEUR QUI DÉPEND DE L'ORDRE DES JOURS.
    ///
    /// « Enchaînement · jour 2 » n'existe que pour partir sur des jambes entamées par la veille.
    /// Distribuée positionnellement comme les autres séances, elle pouvait tomber un mardi — trois
    /// jours AVANT le jour 1. Ce test exige les deux jours calendaires consécutifs, dans cet ordre,
    /// sur les séances réellement produites.
    @MainActor
    func testUltraBackToBackLandsOnTwoConsecutiveCalendarDays() {
        let profile = makeProfile(goal: .ultraTrail, distance: .ultra100, weeksUntilRace: 18,
                                  elevationM: 6000, runningDays: [0, 2, 4, 5, 6])
        let s = shape(for: profile)
        let premiereSpec = s.baseWeeks + 1
        let derniereSpec = s.baseWeeks + s.specificWeeks
        var vues = 0

        for semaine in premiereSpec...derniereSpec
        where AdaptivePlanEngine.trainingBlock(forWeek: semaine, shape: s) == .specifique {
            let jours = AdaptivePlanEngine.generateWeekSessions(weekNumber: semaine, tier: 1, profile: profile)
            let jour1 = jours.first { $0.session.flatMap(\.kind) == .ultraBackToBackDay1 }?.weekday
            let jour2 = jours.first { $0.session.flatMap(\.kind) == .ultraBackToBackDay2 }?.weekday
            guard let jour1, let jour2 else {
                XCTFail("S\(semaine) : un 100 km avec 6 000 m de D+ doit porter un enchaînement")
                continue
            }
            vues += 1
            XCTAssertEqual(jour2, jour1 + 1, "S\(semaine) : le jour 2 doit être le LENDEMAIN du jour 1")

            // Et il doit être plus court : deux sorties longues égales deux jours de suite est la
            // façon classique de se blesser en préparant un ultra.
            let d1 = jours.first { $0.weekday == jour1 }?.session?.durationMinutes ?? 0
            let d2 = jours.first { $0.weekday == jour2 }?.session?.durationMinutes ?? 0
            XCTAssertLessThan(d2, d1, "S\(semaine) : le jour 2 (\(d2) min) ne doit pas égaler le jour 1 (\(d1) min)")
            // Il ne doit pas non plus être symbolique : sous la moitié, la fatigue n'est plus le
            // sujet et la séance ne répète plus rien.
            XCTAssertGreaterThan(Double(d2) / Double(max(d1, 1)), 0.4, "S\(semaine) : le jour 2 est trop court pour répéter quoi que ce soit")
        }
        XCTAssertGreaterThan(vues, 0, "Aucune semaine spécifique vérifiée : le test ne prouve rien")
    }

    /// Et l'inverse, qui est le vrai piège : une semaine SANS deux jours consécutifs ne doit pas
    /// recevoir d'enchaînement du tout. Avec lundi / mercredi / vendredi / dimanche — la
    /// répartition la plus courante — « le jour de course suivant » n'existe pas après dimanche
    /// et « le précédent » est vendredi : on aurait prescrit deux sorties longues séparées de deux
    /// jours de repos, sous le nom de la séance censée l'éviter.
    @MainActor
    func testUltraBackToBackIsWithheldWhenTheWeekCannotCarryIt() {
        XCTAssertNil(
            AdaptivePlanEngine.jumelageEnchainement(runningDays: [0, 2, 4, 6], preferredLongRunDay: 6),
            "Lundi/mercredi/vendredi/dimanche n'offre aucun couple de jours consécutifs"
        )
        XCTAssertEqual(
            AdaptivePlanEngine.jumelageEnchainement(runningDays: [0, 1, 3, 5, 6], preferredLongRunDay: 6)?.longue, 5,
            "Un samedi disponible fait glisser la longue à la veille"
        )
        XCTAssertEqual(
            AdaptivePlanEngine.jumelageEnchainement(runningDays: [0, 1, 3, 5, 6], preferredLongRunDay: 5)?.lendemain, 6,
            "Un dimanche disponible accueille le second jour"
        )
        XCTAssertNil(
            AdaptivePlanEngine.jumelageEnchainement(runningDays: [3], preferredLongRunDay: 3),
            "Un seul jour de course ne porte aucun enchaînement"
        )

        let profile = makeProfile(goal: .ultraTrail, distance: .ultra100, weeksUntilRace: 18,
                                  elevationM: 6000, runningDays: [0, 2, 4, 6])
        let s = shape(for: profile)
        guard let total = s.totalWeeks else { return XCTFail("Un ultra doit périodiser") }

        for semaine in 1...total {
            let kinds = AdaptivePlanEngine.generateWeekSessions(weekNumber: semaine, tier: 1, profile: profile)
                .compactMap { $0.session?.kind }
            XCTAssertFalse(kinds.contains(.ultraBackToBackDay1), "S\(semaine) : enchaînement prescrit sur une semaine qui ne peut pas le porter")
            XCTAssertFalse(kinds.contains(.ultraBackToBackDay2), "S\(semaine) : jour 2 d'enchaînement orphelin en S\(semaine)")
        }
    }

    /// Un trail court n'a pas besoin d'apprendre à repartir sur des jambes mortes : sous quatre
    /// heures d'effort, prescrire un enchaînement coûte un week-end entier pour rien — et c'est le
    /// genre de séance qu'on saute une fois puis toujours.
    @MainActor
    func testShortTrailGetsAnOrdinaryLongRunInsteadOfABackToBack() {
        let profile = makeProfile(goal: .ultraTrail, distance: .other, weeksUntilRace: 12,
                                  elevationM: 900, runningDays: [0, 2, 4, 5, 6])
        profile.raceDistanceCustom = "Trail 22 km"
        let s = shape(for: profile)
        let premiereSpec = s.baseWeeks + 1
        let derniereSpec = s.baseWeeks + s.specificWeeks

        var vues = 0
        for semaine in premiereSpec...derniereSpec
        where AdaptivePlanEngine.trainingBlock(forWeek: semaine, shape: s) == .specifique {
            let kinds = AdaptivePlanEngine.generateWeekSessions(weekNumber: semaine, tier: 1, profile: profile)
                .compactMap { $0.session?.kind }
            vues += 1
            XCTAssertFalse(kinds.contains(.ultraBackToBackDay1), "Un trail de 22 km n'a pas besoin d'un enchaînement (S\(semaine))")
            XCTAssertTrue(kinds.contains(.ultraSpecificLongRun), "Il doit recevoir une sortie longue spécifique à la place (S\(semaine))")
        }
        XCTAssertGreaterThan(vues, 0, "Aucune semaine spécifique vérifiée : le test ne prouve rien")
    }
}
