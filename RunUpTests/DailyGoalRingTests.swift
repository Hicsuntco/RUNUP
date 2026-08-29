import XCTest
@testable import RunUp

/// Verrouille la règle « l'anneau ne dessine que les objectifs en jeu ».
///
/// Le bug qu'elle remplace : un jour de repos, `dailyGoalsProgress` rend trois valeurs — la
/// première à 0 pour que le compte reste juste — et l'anneau lisait ce tableau comme la liste
/// des objectifs. Il traçait trois arcs sous un titre annonçant « 0/2 bouclés », dont un qui ne
/// pouvait jamais se remplir. La correction distingue compter (`dailyGoalsProgress`, toujours
/// trois valeurs) d'afficher (`dailyGoalSlots`, seulement les objectifs réels, chacun portant
/// son RANG d'origine — c'est le rang qui porte la couleur).
///
/// Si quelqu'un « simplifie » un jour `dailyGoalSlots` en re-dérivant le rang de la position,
/// le premier test qui casse est celui des couleurs de jour de repos : « calories » hériterait
/// du rose de la séance.
final class DailyGoalRingTests: XCTestCase {

    // MARK: dailyGoalSlots

    func testRestDayExposesTwoSlotsAndSkipsTheSessionSlot() {
        let slots = UserProfile.dailyGoalSlots(sessionDone: nil, steps: 4000, stepsGoal: 8000,
                                               activeCalories: 300, activeCaloriesGoal: 600)
        XCTAssertEqual(slots.map(\.slot), [1, 2],
                       "Un jour de repos n'a que deux objectifs — et chacun garde son rang d'origine.")
    }

    func testTrainingDayExposesThreeSlotsInOrder() {
        let slots = UserProfile.dailyGoalSlots(sessionDone: false, steps: 0, stepsGoal: 8000,
                                               activeCalories: 0, activeCaloriesGoal: 600)
        XCTAssertEqual(slots.map(\.slot), [0, 1, 2])
    }

    func testSlotProgressMatchesTheCountingArray() {
        let slots = UserProfile.dailyGoalSlots(sessionDone: true, steps: 4000, stepsGoal: 8000,
                                               activeCalories: 600, activeCaloriesGoal: 600)
        XCTAssertEqual(slots[0].progress, 1, "Séance faite → arc plein.")
        XCTAssertEqual(slots[1].progress, 1, accuracy: 0.001)
        XCTAssertEqual(slots[2].progress, 0.5, accuracy: 0.001)
    }

    func testZeroGoalsNeverDivideByZero() {
        let slots = UserProfile.dailyGoalSlots(sessionDone: false, steps: 500, stepsGoal: 0,
                                               activeCalories: 100, activeCaloriesGoal: 0)
        XCTAssertEqual(slots.map(\.progress), [0, 0, 0],
                       "Un objectif à zéro (HealthKit pas encore lu) rend 0, pas NaN.")
    }

    // MARK: RingSegmentGeometry — le partage du cercle suit le nombre d'objectifs

    func testTwoSegmentsShareTheFullCircle() {
        let first = RingSegmentGeometry.segment(at: 0, count: 2)
        let second = RingSegmentGeometry.segment(at: 1, count: 2)
        XCTAssertEqual(first.trimStart, 0)
        XCTAssertEqual(second.trimStart, 0.5, accuracy: 0.0001,
                       "À deux objectifs, le second arc part à l'opposé du cercle — pas au tiers.")
        XCTAssertLessThan(first.trimEnd, 0.5, "Le premier arc s'arrête avant le départ du second : l'écart reste.")
    }

    func testGradientDegreesDescribeTheSameArcAsTheTrim() {
        for count in [2, 3] {
            for index in 0..<count {
                let seg = RingSegmentGeometry.segment(at: index, count: count)
                XCTAssertEqual(seg.gradientStartDegrees, seg.trimStart * 360, accuracy: 0.0001)
                XCTAssertEqual(seg.gradientEndDegrees, seg.trimEnd * 360, accuracy: 0.0001,
                               "Le dégradé doit balayer exactement l'arc que le trim découpe — sinon il glisse.")
            }
        }
    }

    // MARK: La fenêtre du plan ouvert (même logique que `PlanView.weekRange`)

    func testOpenProgramShapeIsUnbounded() {
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: .progress, raceDate: nil, from: .now)
        XCTAssertNil(shape.totalWeeks, "Un programme ouvert n'a pas de fin — c'est la fenêtre de la vue qui borne.")
    }

    func testRacePlanIsCappedAtTwentyWeeks() {
        let raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 40, to: .now)!
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: .race, raceDate: raceDate, from: .now)
        XCTAssertEqual(shape.totalWeeks, 20,
                       "Le graphique du plan compte sur ce plafond : 20 barres de 13 pt tiennent, 40 non.")
    }
}
