import XCTest
import SwiftData
@testable import RunUp

/// À quel jour une course validée est-elle imputée.
///
/// La bande de la semaine ne connaît que des jours de la semaine — lundi vaut 0, dimanche vaut 6.
/// Une course d'avant lundi y désigne donc le MÊME jour, sept jours plus tard : une sortie du
/// dimanche validée le lundi cochait le dimanche à venir, dans une semaine qui n'a pas encore eu
/// lieu. Le cas était rare tant que les courses arrivaient en direct ; l'import depuis Apple Santé
/// remonte plusieurs jours en arrière et le rend courant.
@MainActor
final class DebriefWeekAttributionTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProfile() -> UserProfile {
        let profile = UserProfile(name: "Test")
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

    /// Le cas normal, et de loin le plus fréquent : la course est de cette semaine, elle coche son
    /// jour.
    func testARunFromThisWeekMarksItsDay() {
        let profile = makeProfile()
        let today = Date.now
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: run(on: today), profile: profile)

        let day = AdaptivePlanEngine.weekdayIndex(for: today)
        XCTAssertEqual(profile.weekStrip.first { $0.weekday == day }?.state, .done)
        XCTAssertTrue(profile.weekSessions.first { $0.weekday == day }?.completed ?? false)
    }

    /// Et le cas qui abîmait la semaine : une course d'avant le lundi ne coche RIEN. Mieux vaut une
    /// case vide qu'une case cochée pour un jour qui n'est pas encore arrivé.
    func testARunFromLastWeekMarksNothing() {
        let profile = makeProfile()
        let lastWeek = AdaptivePlanEngine.currentWeekRange().lowerBound.addingTimeInterval(-3600)
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: run(on: lastWeek), profile: profile)

        XCTAssertTrue(profile.weekStrip.allSatisfy { $0.state != .done },
                      "une course de la semaine passée a coché un jour de celle-ci")
        XCTAssertTrue(profile.weekSessions.allSatisfy { !$0.completed })
    }

    /// Mais elle compte quand même : le ressenti et l'XP ne sont pas attachés à une case de la
    /// bande. Ne rien créditer du tout pour une sortie réellement courue serait l'autre erreur.
    func testARunFromLastWeekStillCounts() {
        let profile = makeProfile()
        let xpBefore = profile.xp
        let lastWeek = AdaptivePlanEngine.currentWeekRange().lowerBound.addingTimeInterval(-3600)
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: run(on: lastWeek), profile: profile)

        XCTAssertGreaterThan(profile.xp, xpBefore)
        XCTAssertEqual(profile.weekRPECount, 1)
    }
}
