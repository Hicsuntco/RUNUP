import XCTest
@testable import RunUp

/// Verrouille la série.
///
/// C'est le nombre le plus regardé de l'app — l'accueil, le profil, le débriefing après chaque
/// course. Et son enjeu n'est pas l'exactitude pour l'exactitude : une série que l'on croit
/// perdue à tort est une raison d'arrêter de courir, pas seulement un chiffre faux.
///
/// La règle était écrite deux fois, dans deux méthodes du moteur, chacune affirmant de son côté
/// qu'un écart de plus de trois jours rompt la chaîne. Ces tests portent sur l'implémentation
/// unique qui les remplace, et le dernier vérifie explicitement que les deux entrées — avancer
/// après une séance, recalculer depuis l'historique — tombent bien d'accord.
final class StreakTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000)))!
    }
    private var today: Date { day(0) }

    // MARK: - Avancer après une séance

    func testFirstEverSessionStartsAtOne() {
        let s = Streak.afterSession(Streak.State(count: 0, lastDay: nil), on: today, calendar: cal)
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s.lastDay, today)
    }

    func testARunTheNextDayContinues() {
        let s = Streak.afterSession(Streak.State(count: 4, lastDay: day(-1)), on: today, calendar: cal)
        XCTAssertEqual(s.count, 5)
    }

    /// Le défaut historique : « série de 52 jours » pour quelqu'un qui court une fois par
    /// semaine, parce que deux séances le même jour comptaient deux fois.
    func testASecondSessionTheSameDayDoesNotCountTwice() {
        let s = Streak.afterSession(Streak.State(count: 4, lastDay: today), on: today, calendar: cal)
        XCTAssertEqual(s.count, 4, "Un incrément par JOUR, pas par séance.")
    }

    /// Un plan à trois séances par semaine peut poser mardi puis vendredi. Casser la série à ce
    /// moment-là punirait quelqu'un qui suit exactement le programme qu'on lui a donné.
    func testAPlannedRestBlockDoesNotBreakTheChain() {
        for gap in 1...Streak.toleratedGapDays {
            let s = Streak.afterSession(Streak.State(count: 6, lastDay: day(-gap)), on: today, calendar: cal)
            XCTAssertEqual(s.count, 7, "Un écart de \(gap) jour(s) ne doit rien rompre.")
        }
    }

    func testABiggerGapRestartsAtOne() {
        let s = Streak.afterSession(Streak.State(count: 30, lastDay: day(-(Streak.toleratedGapDays + 1))),
                                    on: today, calendar: cal)
        XCTAssertEqual(s.count, 1)
    }

    // MARK: - Recalculer depuis l'historique

    func testNoRunsMeansNoStreak() {
        let s = Streak.recompute(runDays: [], today: today, calendar: cal)
        XCTAssertEqual(s, Streak.State(count: 0, lastDay: nil))
    }

    func testConsecutiveDaysCount() {
        let s = Streak.recompute(runDays: [day(0), day(-1), day(-2)], today: today, calendar: cal)
        XCTAssertEqual(s.count, 3)
    }

    func testTwoRunsOnOneDayCountOnce() {
        let s = Streak.recompute(runDays: [day(0), day(0), day(-1)], today: today, calendar: cal)
        XCTAssertEqual(s.count, 2)
    }

    func testTheChainStopsAtTheFirstTooLongGap() {
        // Aujourd'hui, hier — puis un trou de dix jours, et trois jours plus anciens qui ne
        // doivent pas être recollés à la chaîne courante.
        let s = Streak.recompute(runDays: [day(0), day(-1), day(-11), day(-12), day(-13)],
                                 today: today, calendar: cal)
        XCTAssertEqual(s.count, 2)
    }

    /// Quelqu'un qui revient après un mois ne doit pas retrouver son ancienne série intacte.
    func testAnOldChainIsOver() {
        let s = Streak.recompute(runDays: [day(-30), day(-31), day(-32)], today: today, calendar: cal)
        XCTAssertEqual(s, Streak.State(count: 0, lastDay: nil))
    }

    /// Les dates arrivent d'une requête SwiftData, sans garantie d'ordre.
    func testOrderOfTheRunsDoesNotMatter() {
        let shuffled = Streak.recompute(runDays: [day(-2), day(0), day(-1)], today: today, calendar: cal)
        XCTAssertEqual(shuffled.count, 3)
    }

    // MARK: - Les deux entrées doivent s'accorder

    /// Le vrai objet de cette extraction. Avancer jour après jour et recalculer depuis
    /// l'historique décrivent la MÊME série : c'est leur désaccord, invisible et silencieux, que
    /// deux implémentations séparées rendaient possible.
    func testAdvancingAndRecomputingAgree() {
        let days = [day(-5), day(-4), day(-2), day(-1), day(0)] // écarts de 1, 2, 1, 1
        var advanced = Streak.State(count: 0, lastDay: nil)
        for d in days { advanced = Streak.afterSession(advanced, on: d, calendar: cal) }
        let recomputed = Streak.recompute(runDays: days, today: today, calendar: cal)
        XCTAssertEqual(advanced.count, recomputed.count,
                       "Les deux chemins doivent donner la même série : \(advanced.count) contre \(recomputed.count).")
        XCTAssertEqual(advanced.lastDay, recomputed.lastDay)
    }

    func testBothPathsBreakOnTheSameGap() {
        let days = [day(-10), day(-1), day(0)] // le premier écart, de 9 jours, casse
        var advanced = Streak.State(count: 0, lastDay: nil)
        for d in days { advanced = Streak.afterSession(advanced, on: d, calendar: cal) }
        let recomputed = Streak.recompute(runDays: days, today: today, calendar: cal)
        XCTAssertEqual(advanced.count, recomputed.count)
        XCTAssertEqual(advanced.count, 2)
    }
}
