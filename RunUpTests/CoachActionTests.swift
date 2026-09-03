import XCTest
import SwiftData
@testable import RunUp

/// Verrouille ce que le coach peut faire au programme — et surtout ce qu'il ne peut pas.
///
/// Ces valeurs viennent d'un modèle de langage, pas d'un formulaire : aucune n'est acquise, même
/// quand le schéma d'outil est respecté. La question posée ici n'est donc pas « le décodage
/// marche-t-il », c'est « que se passe-t-il quand l'appel est absurde ». Une séance de zéro
/// minute, un bridage jusqu'en 2040, un programme ramené à un seul jour de course : rien de tout
/// cela ne doit être représentable, quoi qu'il arrive en amont.
final class CoachActionTests: XCTestCase {

    private func input(_ json: String) -> Data { Data(json.utf8) }

    private let calendar = Calendar(identifier: .gregorian)

    /// Un « aujourd'hui » fixe, pour que les bornes de dates se testent sans dépendre du jour où
    /// la suite tourne.
    private let today = DateComponents(calendar: Calendar(identifier: .gregorian),
                                       year: 2026, month: 9, day: 3).date!

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: dayOfMonth).date!
    }

    // MARK: - Allègement

    func testEaseCarriesCapAndSpeedBan() {
        let action = CoachAction.make(
            name: "ease_training_load",
            input: input(#"{"max_minutes":30,"no_speed_work":true,"until":"2026-09-17","reason":"Tendinite"}"#),
            today: today, calendar: calendar
        )
        guard case .ease(let ease)? = action else { return XCTFail("action attendue, reçu \(String(describing: action))") }
        XCTAssertEqual(ease.maxMinutes, 30)
        XCTAssertTrue(ease.noSpeedWork)
        XCTAssertEqual(ease.reason, "Tendinite")
        XCTAssertEqual(calendar.startOfDay(for: ease.until), day(2026, 9, 17))
    }

    /// Le cas qui ne contraint rien. Poser une contrainte vide afficherait à la coureuse un
    /// bandeau « programme allégé » au-dessus d'un programme identique.
    func testEaseWithNothingToConstrainIsRefused() {
        XCTAssertNil(CoachAction.make(
            name: "ease_training_load",
            input: input(#"{"no_speed_work":false,"until":"2026-09-17","reason":"rien"}"#),
            today: today, calendar: calendar
        ))
    }

    func testEaseDurationIsClampedBothWays() {
        func cap(_ raw: Int) -> Int? {
            guard case .ease(let ease)? = CoachAction.make(
                name: "ease_training_load",
                input: input(#"{"max_minutes":\#(raw),"no_speed_work":false,"until":"2026-09-17","reason":"x"}"#),
                today: today, calendar: calendar
            ) else { return nil }
            return ease.maxMinutes
        }
        XCTAssertEqual(cap(0), TrainingEase.minSessionMinutes, "une séance de 0 minute n'est pas une séance")
        XCTAssertEqual(cap(5000), TrainingEase.maxSessionMinutes)
        XCTAssertEqual(cap(45), 45, "une valeur raisonnable passe telle quelle")
    }

    /// Un allègement sans échéance devient un plafond permanent que plus personne ne retire, et le
    /// programme cesse silencieusement de progresser.
    func testEaseHorizonIsBounded() {
        guard case .ease(let ease)? = CoachAction.make(
            name: "ease_training_load",
            input: input(#"{"max_minutes":30,"no_speed_work":true,"until":"2040-01-01","reason":"x"}"#),
            today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        let horizon = calendar.date(byAdding: .day, value: TrainingEase.maxHorizonDays, to: today)!
        XCTAssertEqual(calendar.startOfDay(for: ease.until), calendar.startOfDay(for: horizon))
    }

    /// Une date déjà passée donnerait une contrainte inactive à l'instant où on la pose : le coach
    /// annoncerait un allègement, et le programme ne bougerait pas.
    func testEaseInThePastIsPulledToToday() {
        guard case .ease(let ease)? = CoachAction.make(
            name: "ease_training_load",
            input: input(#"{"max_minutes":30,"no_speed_work":false,"until":"2020-01-01","reason":"x"}"#),
            today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        XCTAssertEqual(calendar.startOfDay(for: ease.until), calendar.startOfDay(for: today))
        XCTAssertTrue(ease.isActive(on: today, calendar: calendar))
    }

    func testEaseWithoutParsableDateIsRefused() {
        for bad in ["17/09/2026", "bientôt", "la semaine prochaine", ""] {
            XCTAssertNil(CoachAction.make(
                name: "ease_training_load",
                input: input(#"{"max_minutes":30,"no_speed_work":true,"until":"\#(bad)","reason":"x"}"#),
                today: today, calendar: calendar
            ), "« \(bad) » ne doit pas produire d'action")
        }
    }

    func testEaseReasonIsNeverEmptyAndNeverEndless() {
        guard case .ease(let blank)? = CoachAction.make(
            name: "ease_training_load",
            input: input(#"{"max_minutes":30,"no_speed_work":false,"until":"2026-09-17","reason":"   "}"#),
            today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        XCTAssertFalse(blank.reason.isEmpty, "l'étiquette portée par les séances ne peut pas être vide")

        guard case .ease(let long)? = CoachAction.make(
            name: "ease_training_load",
            input: input(#"{"max_minutes":30,"no_speed_work":false,"until":"2026-09-17","reason":"\#(String(repeating: "a", count: 400))"}"#),
            today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        XCTAssertLessThanOrEqual(long.reason.count, 80)
    }

    /// La contrainte court jusqu'au dernier jour inclus — c'est ce que « jusqu'au 17 » veut dire
    /// pour la personne qui le lit.
    func testEaseIsActiveThroughItsLastDay() {
        let ease = TrainingEase(maxMinutes: 30, noSpeedWork: true, until: day(2026, 9, 17), reason: "x")
        XCTAssertTrue(ease.isActive(on: day(2026, 9, 17), calendar: calendar))
        XCTAssertFalse(ease.isActive(on: day(2026, 9, 18), calendar: calendar))
    }

    // MARK: - Zone sensible

    func testSensitiveAreaAcceptsOnlyKnownZones() {
        guard case .sensitiveArea(let knee)? = CoachAction.make(
            name: "set_sensitive_area", input: input(#"{"area":"knee"}"#), today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        XCTAssertEqual(knee, "knee")

        guard case .sensitiveArea(let cleared)? = CoachAction.make(
            name: "set_sensitive_area", input: input(#"{"area":"none"}"#), today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        XCTAssertNil(cleared, "« none » lève le signalement")

        // Une zone inconnue afficherait son propre identifiant brut à la coureuse.
        XCTAssertNil(CoachAction.make(
            name: "set_sensitive_area", input: input(#"{"area":"shoulder"}"#), today: today, calendar: calendar
        ))
    }

    // MARK: - Jours de course

    func testRunningDaysAreDedupedSortedAndBounded() {
        guard case .runningDays(let days, let longRun)? = CoachAction.make(
            name: "set_running_days",
            input: input(#"{"days":[4,0,0,9,-2,2],"long_run_day":4}"#),
            today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        XCTAssertEqual(days, [0, 2, 4], "hors 0…6 écarté, doublons fondus, ordre rétabli")
        XCTAssertEqual(longRun, 4)
    }

    /// Moins de deux jours n'est pas un programme : le générateur produirait une semaine quasi
    /// vide que personne n'a demandée.
    func testRunningDaysBelowTwoIsRefused() {
        XCTAssertNil(CoachAction.make(
            name: "set_running_days", input: input(#"{"days":[3]}"#), today: today, calendar: calendar
        ))
        XCTAssertNil(CoachAction.make(
            name: "set_running_days", input: input(#"{"days":[]}"#), today: today, calendar: calendar
        ))
    }

    func testLongRunDayOutsideRunningDaysIsDropped() {
        guard case .runningDays(_, let longRun)? = CoachAction.make(
            name: "set_running_days",
            input: input(#"{"days":[0,2],"long_run_day":5}"#),
            today: today, calendar: calendar
        ) else { return XCTFail("action attendue") }
        XCTAssertNil(longRun, "une sortie longue un jour où elle ne court pas n'aurait nulle part où aller")
    }

    // MARK: - Le reste

    func testArgumentlessActionsDecode() {
        XCTAssertEqual(CoachAction.make(name: "move_todays_session", input: input("{}"),
                                        today: today, calendar: calendar), .moveTodaysSession)
        XCTAssertEqual(CoachAction.make(name: "resume_normal_training", input: input("{}"),
                                        today: today, calendar: calendar), .resumeNormal)
    }

    func testUnknownToolAndMalformedInputAreRefused() {
        XCTAssertNil(CoachAction.make(name: "delete_everything", input: input("{}"),
                                      today: today, calendar: calendar))
        XCTAssertNil(CoachAction.make(name: "ease_training_load", input: input("pas du json"),
                                      today: today, calendar: calendar))
    }
}

/// Vérifie que l'allègement atteint réellement les séances produites — et qu'il y survit à la
/// régénération, qui est toute la raison d'être de sa forme.
final class CoachActionPlanEffectTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(for: UserProfile.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    @MainActor
    private func makeProfile() -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.goalId = .progress
        profile.level = .intermediaire
        profile.runningDays = [0, 2, 4, 6]
        profile.preferredLongRunDay = 6
        profile.programStartDate = Date()
        profile.weekTier = 3
        container.mainContext.insert(profile)
        return profile
    }

    @MainActor
    private func sessions(_ profile: UserProfile) -> [WorkoutSession] {
        AdaptivePlanEngine
            .generateWeekSessions(weekNumber: profile.weekNumber, tier: profile.weekTier, profile: profile)
            .compactMap(\.session)
    }

    /// Balayé sur plusieurs semaines : les blocs d'entraînement n'ont pas tous la même forme, et
    /// une assertion posée sur la seule semaine 1 prouverait ce que cette semaine-là contient
    /// plutôt que la règle.
    private static let weeksUnderTest = 1...8

    @MainActor
    func testCapAppliesOnTopOfTheTierNotUnderIt() {
        let profile = makeProfile()
        let unconstrained = Self.weeksUnderTest.flatMap { week -> [WorkoutSession] in
            profile.weekNumber = week
            return sessions(profile)
        }
        XCTAssertTrue(unconstrained.contains { $0.durationMinutes > 30 },
                      "sans dépassement à raboter, le test ne prouverait rien")

        profile.trainingEase = TrainingEase(maxMinutes: 30, noSpeedWork: false,
                                            until: Date().addingTimeInterval(7 * 86_400), reason: "Tendinite")
        for week in Self.weeksUnderTest {
            profile.weekNumber = week
            for session in sessions(profile) {
                XCTAssertLessThanOrEqual(session.durationMinutes, 30,
                                         "semaine \(week) : « Niveau 3 » repasse au-dessus du plafond annoncé")
            }
        }
    }

    /// Une séance raccourcie qui s'annonce « Niveau 3 » est un écran qui se contredit.
    @MainActor
    func testEaseOwnsTheLabelWhenItBites() {
        let profile = makeProfile()
        profile.trainingEase = TrainingEase(maxMinutes: 25, noSpeedWork: false,
                                            until: Date().addingTimeInterval(7 * 86_400), reason: "Tendinite")
        let capped = sessions(profile).filter { $0.durationMinutes == 25 }
        XCTAssertFalse(capped.isEmpty, "sans séance rabotée, le test ne prouverait rien")
        XCTAssertEqual(Set(capped.compactMap(\.adjustment)), ["Tendinite"])
    }

    /// « Plus de fractionné » n'est pas « un fractionné plus court » : la séance change d'identité,
    /// sinon l'écran affiche des répétitions qu'on vient justement de retirer.
    @MainActor
    func testNoSpeedWorkRemovesTheIntervalsThemselves() {
        let profile = makeProfile()
        let unconstrained = Self.weeksUnderTest.flatMap { week -> [WorkoutSession] in
            profile.weekNumber = week
            return sessions(profile)
        }
        XCTAssertTrue(unconstrained.contains { $0.intervals != nil },
                      "sans fractionné au départ, le test ne prouverait rien")

        profile.trainingEase = TrainingEase(maxMinutes: nil, noSpeedWork: true,
                                            until: Date().addingTimeInterval(7 * 86_400), reason: "Tendinite")
        for week in Self.weeksUnderTest {
            profile.weekNumber = week
            XCTAssertFalse(sessions(profile).contains { $0.intervals != nil },
                           "semaine \(week) : il reste des répétitions à faire")
        }
    }

    /// La raison d'être de toute cette forme : le programme est regénéré, et la contrainte doit
    /// être encore là après. C'est exactement ce qu'une séance éditée à la main ne ferait pas.
    @MainActor
    func testEaseSurvivesRegeneration() {
        let profile = makeProfile()
        profile.programPhase = .active
        AdaptivePlanEngine.refreshProgramForCurrentDate(profile)

        let ease = TrainingEase(maxMinutes: 30, noSpeedWork: true,
                                until: Date().addingTimeInterval(7 * 86_400), reason: "Tendinite")
        XCTAssertNotNil(AdaptivePlanEngine.applyCoachAction(.ease(ease), to: profile))

        AdaptivePlanEngine.applyProgramSettingsChange(profile)
        let after = profile.weekSessions.compactMap(\.session).filter { $0.durationMinutes > 0 }
        XCTAssertFalse(after.isEmpty)
        for session in after {
            XCTAssertLessThanOrEqual(session.durationMinutes, 30)
            XCTAssertNil(session.intervals)
        }
    }

    /// Une échéance dépassée doit tomber au lancement, pas au lundi suivant : sinon le bandeau dit
    /// « jusqu'au 17 » et les séances restent plafonnées le 18.
    @MainActor
    func testExpiredEaseIsClearedOnRefresh() {
        let profile = makeProfile()
        profile.programPhase = .active
        profile.trainingEase = TrainingEase(maxMinutes: 20, noSpeedWork: true,
                                            until: Date().addingTimeInterval(-2 * 86_400), reason: "Tendinite")
        AdaptivePlanEngine.refreshProgramForCurrentDate(profile)
        XCTAssertNil(profile.trainingEase)
        XCTAssertTrue(profile.weekSessions.compactMap(\.session).contains { $0.durationMinutes > 20 },
                      "le programme doit être revenu à ses vraies durées, pas seulement le drapeau")
    }

    /// « Annuler » doit rendre le programme à l'identique, y compris pour l'action qui ne change
    /// aucun réglage mais permute deux jours.
    @MainActor
    func testUndoRestoresEveryAction() {
        let profile = makeProfile()
        profile.programPhase = .active
        AdaptivePlanEngine.refreshProgramForCurrentDate(profile)
        let before = profile.weekSessions

        let snapshot = AdaptivePlanEngine.snapshot(profile)
        let ease = TrainingEase(maxMinutes: 20, noSpeedWork: true,
                                until: Date().addingTimeInterval(7 * 86_400), reason: "Tendinite")
        _ = AdaptivePlanEngine.applyCoachAction(.ease(ease), to: profile)
        XCTAssertNotNil(profile.trainingEase)

        AdaptivePlanEngine.restore(snapshot, to: profile)
        XCTAssertNil(profile.trainingEase)
        XCTAssertEqual(profile.weekSessions.map(\.session?.durationMinutes),
                       before.map(\.session?.durationMinutes))
    }

    /// Une action qui ne change rien ne doit pas produire de ligne dans le fil : un bandeau
    /// « c'est fait » au-dessus d'un programme identique est pire que pas de bandeau du tout.
    @MainActor
    func testNoOpActionsReportNothing() {
        let profile = makeProfile()
        profile.programPhase = .active
        XCTAssertNil(AdaptivePlanEngine.applyCoachAction(.resumeNormal, to: profile),
                     "rien à lever")
        XCTAssertNil(AdaptivePlanEngine.applyCoachAction(.runningDays(days: [0, 2, 4, 6], longRunDay: 6), to: profile),
                     "les jours sont déjà ceux-là")
    }
}
