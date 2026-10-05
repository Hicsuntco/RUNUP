import XCTest
import SwiftData
@testable import RunUp

/// « J'ai couru un jour de repos » — ce que la journée devient.
///
/// # LA DÉCISION
///
/// Un jour de repos où l'on est sortie quand même n'est plus un jour de repos : la journée
/// repasse à trois objectifs, et sa séance est bouclée.
///
/// # L'OPTION ÉCARTÉE, ET POURQUOI
///
/// L'autre façon de « faire compter » la course était d'ajouter un troisième objectif au moment
/// où elle arrive. Elle est absurde, et d'une façon qu'aucun habillage ne rattrape : une journée
/// de repos à « 2/2 bouclés » serait passée à « 2/3 » À L'INSTANT où l'on sort. L'app ferait
/// reculer quelqu'un parce qu'il a couru.
///
/// Le dernier test de ce fichier est celui qui compte vraiment : il interdit que courir fasse
/// jamais baisser la proportion d'objectifs bouclés, quelle que soit la journée.
@MainActor
final class RestDayErasedByRunTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Sept jours sans séance : la semaine entière est du repos, aujourd'hui compris.
    private func reposAujourdhui() -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.programPhase = .active
        profile.weekStrip = (0..<7).map { DayStatus(weekday: $0, letter: "·", state: .upcoming) }
        profile.weekSessions = (0..<7).map { PlannedDay(weekday: $0) }
        container.mainContext.insert(profile)
        return profile
    }

    /// La même convention que `UserProfile.todayWeekdayIndex`, recopiée parce qu'elle est privée.
    private var aujourdhui: Int { (Calendar.current.component(.weekday, from: .now) + 5) % 7 }

    private func courseDuJour() -> RunRecord {
        let record = AdaptivePlanEngine.buildRunRecord(
            title: "Test", elapsedSeconds: 1800, distanceKm: 5, kcal: 300, avgHeartRate: 150
        )
        record.date = .now
        return record
    }

    func testUnReposSansCourseResteUnRepos() {
        let p = reposAujourdhui()
        XCTAssertTrue(p.isRestDayToday)
        XCTAssertEqual(p.dailyGoalsTotal, 2)
        // La séance n'est pas un objectif du jour : son arc n'existe pas.
        XCTAssertEqual(p.dailyGoalSlotsToday.map { $0.slot }, [1, 2])
    }

    func testUneCourseEffaceLeRepos() {
        let p = reposAujourdhui()
        AdaptivePlanEngine.markSessionDone(for: courseDuJour(), profile: p)

        XCTAssertFalse(p.isRestDayToday, "courir doit effacer le repos du jour")
        XCTAssertEqual(p.dailyGoalsTotal, 3)
        XCTAssertEqual(p.dailyGoalSlotsToday.map { $0.slot }, [0, 1, 2])
        XCTAssertTrue(p.seanceDoneToday)
        // Et l'arc de la séance est plein, pas seulement présent.
        XCTAssertEqual(p.dailyGoalSlotsToday.first { $0.slot == 0 }?.progress, 1)
    }

    /// La règle est réversible : supprimer la course de l'historique rend son repos à la journée.
    /// Sans ça, une sortie enregistrée par erreur retirerait définitivement un jour de repos du
    /// plan, et l'anneau réclamerait pour toujours une séance que personne n'a demandée.
    func testSupprimerLaCourseRendLeRepos() {
        let p = reposAujourdhui()
        AdaptivePlanEngine.markSessionDone(for: courseDuJour(), profile: p)
        XCTAssertFalse(p.isRestDayToday)

        AdaptivePlanEngine.undoTodaySessionCompletion(p)
        XCTAssertTrue(p.isRestDayToday, "le repos doit revenir quand la course disparaît")
        XCTAssertEqual(p.dailyGoalsTotal, 2)
    }

    func testUnJourDeSeanceNEstPasAffecte() {
        let p = reposAujourdhui()
        var jour = PlannedDay(weekday: aujourdhui)
        jour.session = WorkoutSession(title: "Footing tranquille", subtitle: "",
                                      durationMinutes: 40, pace: "6:03", zone: "Z2",
                                      adjustment: nil)
        p.weekSessions[aujourdhui] = jour

        XCTAssertFalse(p.isRestDayToday)
        XCTAssertEqual(p.dailyGoalsTotal, 3)
        XCTAssertFalse(p.seanceDoneToday, "une séance prévue et non faite reste à faire")
    }

    /// L'INVARIANT QUI JUSTIFIE TOUT LE CHOIX : courir ne doit JAMAIS faire baisser la proportion
    /// d'objectifs bouclés. C'est exactement ce que la solution écartée aurait produit — 2/2
    /// devenant 2/3 au moment de sortir.
    func testCourirNeFaitJamaisBaisserLaProportion() {
        for (calories, pas) in [(0.0, 0.0), (400.0, 6000.0), (400.0, 0.0)] {
            let p = reposAujourdhui()
            p.activeCaloriesToday = calories
            p.stepsToday = pas

            let avant = Double(p.dailyGoalsDone) / Double(p.dailyGoalsTotal)
            AdaptivePlanEngine.markSessionDone(for: courseDuJour(), profile: p)
            let apres = Double(p.dailyGoalsDone) / Double(p.dailyGoalsTotal)

            XCTAssertGreaterThanOrEqual(
                apres, avant,
                "avec \(Int(calories)) kcal et \(Int(pas)) pas, courir a fait passer la journée "
                + "de \(p.dailyGoalsDone)/\(p.dailyGoalsTotal) en arrière"
            )
        }
    }
}
