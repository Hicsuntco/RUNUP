import XCTest
@testable import RunUp

/// Verrouille le réancrage du suivi du cycle.
///
/// La phase pilote `AdaptivePlanEngine.adjustForWellbeing`, donc la charge d'entraînement proposée.
/// Une moyenne qui apprendrait trop vite, ou une date réancrée sur une saisie aberrante, ne se
/// verrait pas à l'écran — elle se verrait dans un programme trop dur au mauvais moment du mois.
final class CycleTrackingTests: XCTestCase {

    private func date(_ daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    /// Premier enregistrement : rien à apprendre, on pose la date.
    func testFirstRecordingJustSetsTheDate() {
        let now = Date()
        let result = CycleTracking.recordingPeriodStart(lastStart: nil, averageLength: 28, newStart: now)
        XCTAssertEqual(result.lastStart, now)
        XCTAssertEqual(result.averageLength, 28)
    }

    /// La moyenne apprend à MOITIÉ de l'écart observé.
    ///
    /// Un cycle décalé par un voyage, une maladie ou un stress ne doit pas redéfinir la moyenne à
    /// lui seul. Vingt-huit attendus, trente-deux observés : la moyenne va à trente, pas à
    /// trente-deux. Une vraie tendance s'installe en deux ou trois cycles, un accident isolé
    /// s'efface au suivant.
    func testAverageLearnsHalfOfTheObservedGap() {
        let result = CycleTracking.recordingPeriodStart(
            lastStart: date(32), averageLength: 28, newStart: Date()
        )
        XCTAssertEqual(result.averageLength, 30)
    }

    /// Un écart hors de 15–60 jours n'est pas un cycle : c'est une correction de saisie, une
    /// reprise après interruption, ou deux appuis rapprochés. On réancre la date sans rien
    /// apprendre — une moyenne inchangée vaut mieux qu'une moyenne fausse.
    func testImplausibleGapsTeachNothing() {
        let now = Date()
        let tooShort = CycleTracking.recordingPeriodStart(lastStart: date(3), averageLength: 28, newStart: now)
        XCTAssertEqual(tooShort.averageLength, 28)
        XCTAssertEqual(tooShort.lastStart, now, "la date est réancrée quand même")

        let tooLong = CycleTracking.recordingPeriodStart(lastStart: date(120), averageLength: 28, newStart: now)
        XCTAssertEqual(tooLong.averageLength, 28)
        XCTAssertEqual(tooLong.lastStart, now)
    }

    /// Deux appuis le même jour ne doivent rien casser.
    func testSameDayRecordingIsHarmless() {
        let now = Date()
        let result = CycleTracking.recordingPeriodStart(lastStart: now, averageLength: 28, newStart: now)
        XCTAssertEqual(result.averageLength, 28)
        XCTAssertEqual(result.lastStart, now)
    }

    /// La durée stockée reste dans les bornes que `UserProfile.cyclePhase` applique de son côté.
    ///
    /// Sans cet écrêtage à l'écriture, le réglage afficherait « 38 jours » pendant que le calcul de
    /// phase en utiliserait 35 : un nombre visible que l'app n'utilise pas.
    func testStoredLengthStaysWithinTheBoundsThePhaseCalculationUses() {
        let long = CycleTracking.recordingPeriodStart(lastStart: date(58), averageLength: 35, newStart: Date())
        XCTAssertLessThanOrEqual(long.averageLength, 35)

        let short = CycleTracking.recordingPeriodStart(lastStart: date(16), averageLength: 21, newStart: Date())
        XCTAssertGreaterThanOrEqual(short.averageLength, 21)

        XCTAssertEqual(CycleTracking.clamped(12), 21)
        XCTAssertEqual(CycleTracking.clamped(99), 35)
    }
}
