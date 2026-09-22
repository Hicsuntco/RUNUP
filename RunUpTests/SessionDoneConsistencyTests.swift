import XCTest
import SwiftData
@testable import RunUp

/// « La séance du jour est-elle faite ? » — une question de fait, une seule réponse.
///
/// Elle en avait deux. Le drapeau du profil n'était écrit qu'à la VALIDATION du ressenti, alors
/// qu'une course entre dans l'historique bien avant — remontée d'Apple Santé, récupérée après un
/// plantage, ou simplement finie sans qu'on ait encore répondu à la feuille. Entre les deux
/// moments, l'app affirmait « Course · À faire » sur l'accueil pendant que « Ta journée » affichait
/// « Faite ✓ », avec un anneau plein et une barre vide sous le même mot.
///
/// AVOIR COURU EST UN FAIT, CE QU'ON A RESSENTI EST UNE QUESTION. Le premier ne doit pas attendre
/// le second.
@MainActor
final class SessionDoneConsistencyTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProfile(phase: ProgramPhase = .active) -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.programPhase = phase
        profile.weekStrip = (0..<7).map { DayStatus(weekday: $0, letter: "·", state: .upcoming) }
        profile.weekSessions = (0..<7).map { PlannedDay(weekday: $0) }
        container.mainContext.insert(profile)
        return profile
    }

    private func run(on date: Date) -> RunRecord {
        let record = AdaptivePlanEngine.buildRunRecord(
            title: "Test", elapsedSeconds: 1800, distanceKm: 5, kcal: 300, avgHeartRate: 150
        )
        record.date = date
        return record
    }

    /// Le cas des captures : course libre, une sortie enregistrée aujourd'hui, aucun ressenti
    /// donné. Avant, le drapeau restait faux et l'accueil annonçait « À faire ».
    func testUneCourseDuJourSuffitEnCourseLibre() {
        let profile = makeProfile(phase: .freerun)
        XCTAssertFalse(profile.seanceDoneToday, "rien n'a encore été couru")

        AdaptivePlanEngine.markSessionDone(for: run(on: .now), profile: profile)

        XCTAssertTrue(profile.seanceDoneToday, "la course existe, donc la séance est faite")
        XCTAssertEqual(profile.dailyGoalsProgress[0], 1,
                       "et la barre de l'objectif doit le dire aussi")
    }

    /// Le fait ne dépend pas du ressenti : aucun débriefing n'est nécessaire.
    func testAucunRessentiNEstRequisPourQueLeJourSoitCoche() {
        let profile = makeProfile()
        let today = Date.now
        AdaptivePlanEngine.markSessionDone(for: run(on: today), profile: profile)

        let jour = AdaptivePlanEngine.weekdayIndex(for: today)
        XCTAssertEqual(profile.weekStrip.first { $0.weekday == jour }?.state, .done)
        XCTAssertTrue(profile.weekSessions.first { $0.weekday == jour }?.completed ?? false)
    }

    /// Une sortie d'HIER remontée ce matin ne fait pas la séance d'aujourd'hui. Le drapeau de
    /// course libre portait `.now` quoi qu'il arrive : un import de plusieurs jours cochait donc
    /// le jour même, pour une course qui n'y appartenait pas.
    func testUneCourseDHierNeCochePasAujourdhui() {
        let profile = makeProfile(phase: .freerun)
        let hier = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        AdaptivePlanEngine.markSessionDone(for: run(on: hier), profile: profile)

        XCTAssertFalse(profile.seanceDoneToday,
                       "hier n'est pas aujourd'hui, même quand l'import arrive aujourd'hui")
    }

    /// Le garde-fou de semaine tient toujours : une course d'avant lundi ne coche rien.
    func testUneCourseDeLaSemainePasseeNeCocheRien() {
        let profile = makeProfile()
        let avantLundi = AdaptivePlanEngine.currentWeekRange().lowerBound.addingTimeInterval(-3600)

        AdaptivePlanEngine.markSessionDone(for: run(on: avantLundi), profile: profile)

        XCTAssertTrue(profile.weekStrip.allSatisfy { $0.state != .done })
    }

    /// Marquer deux fois — une course enregistrée PUIS son ressenti validé — ne doit rien casser.
    /// C'est le chemin normal, et `applyDebrief` appelle toujours le même marquage.
    func testMarquerDeuxFoisEstSansEffetSupplementaire() {
        let profile = makeProfile(phase: .freerun)
        let course = run(on: .now)

        AdaptivePlanEngine.markSessionDone(for: course, profile: profile)
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: course, profile: profile)

        XCTAssertTrue(profile.seanceDoneToday)
        let jour = AdaptivePlanEngine.weekdayIndex(for: course.date)
        XCTAssertEqual(profile.weekStrip.filter { $0.state == .done }.count, 1,
                       "un seul jour coché, pas deux")
        XCTAssertEqual(profile.weekStrip.first { $0.weekday == jour }?.state, .done)
    }

    /// Le cœur de la correction : les deux écrans lisent la MÊME chose. L'anneau de « Ta journée »
    /// calcule sa progression depuis `dailyGoalsProgress`, l'accueil affiche `seanceDoneToday` —
    /// ils ne doivent jamais pouvoir se contredire.
    func testLAnneauEtLAccueilNePeuventPlusSeContredire() {
        let profile = makeProfile(phase: .freerun)
        for _ in 0..<2 {
            let attendu: Double = profile.seanceDoneToday ? 1 : 0
            XCTAssertEqual(profile.dailyGoalsProgress[0], attendu)
            AdaptivePlanEngine.markSessionDone(for: run(on: .now), profile: profile)
        }
        XCTAssertEqual(profile.dailyGoalsProgress[0], 1)
        XCTAssertTrue(profile.seanceDoneToday)
    }
}
