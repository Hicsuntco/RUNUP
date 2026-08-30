import XCTest
@testable import RunUp

/// Verrouille la pause automatique, découverte cassée en allant courir : elle s'enclenchait dès
/// les premières secondes de chaque course, et l'écran ne montrait plus qu'un chrono figé.
///
/// La cause tenait en une conversion : `CLLocation.speed` rend une valeur négative quand
/// l'appareil ne connaît pas la vitesse — les premiers points de chaque sortie — et le code
/// écrivait `max(0, speed)`, ce qui rangeait « je ne sais pas » avec « 0 m/s », donc avec « elle
/// est à l'arrêt ». Dix ticks plus tard, pause. Rien dans la suite de tests ne pouvait le voir :
/// la règle vivait dans `tick()`, au milieu du chrono et des consignes vocales.
final class AutoPauseTests: XCTestCase {

    /// Fait tourner `n` secondes à une même vitesse et rend le nombre de pauses déclenchées.
    private func run(_ seconds: Int, speed: Double?, state: inout AutoPause.State,
                     enabled: Bool = true) -> Int {
        var pauses = 0
        for _ in 0..<seconds {
            if AutoPause.tick(&state, speed: speed, enabled: enabled) { pauses += 1 }
        }
        return pauses
    }

    // MARK: - Le défaut constaté sur le terrain

    /// Le cas exact rencontré : la puce GNSS n'a pas encore accroché, aucune vitesse n'est
    /// disponible, et le départ vient d'être donné. Rien ne doit se mettre en pause.
    func testNoPauseWhileGPSHasNotAcquiredYet() {
        var state = AutoPause.State()
        XCTAssertEqual(run(60, speed: nil, state: &state), 0,
                       "Une minute sans le moindre point GPS ne doit pas déclencher la pause.")
        XCTAssertFalse(state.armed)
    }

    /// La variante qui produisait le même symptôme : l'appareil rend bien des points, mais leur
    /// vitesse est indisponible. C'est ce que l'ancien `max(0, speed)` transformait en zéro.
    func testUnknownSpeedIsNeverAStop() {
        var state = AutoPause.State()
        _ = run(15, speed: 3.0, state: &state)
        XCTAssertTrue(state.armed)
        XCTAssertEqual(run(120, speed: nil, state: &state), 0,
                       "Deux minutes de vitesse indisponible en pleine course ne sont pas un arrêt.")
    }

    /// Et le cas symétrique, qui est le vrai zéro : immobile pour de bon, vitesse connue.
    func testRealStopStillPausesOnceArmed() {
        var state = AutoPause.State()
        _ = run(5, speed: 3.0, state: &state)
        XCTAssertEqual(run(Int(AutoPause.delaySeconds), speed: 0, state: &state), 1)
    }

    // MARK: - L'armement

    /// Debout à l'arrêt avant même d'avoir commencé — au feu, à chercher ses écouteurs. Il n'y a
    /// rien à mettre en pause tant qu'on ne l'a pas vue courir.
    func testStandingStillBeforeTheFirstStrideNeverPauses() {
        var state = AutoPause.State()
        XCTAssertEqual(run(300, speed: 0, state: &state), 0,
                       "Cinq minutes immobile AVANT le départ ne sont pas une pause, c'est une attente.")
    }

    /// Une marche lente n'arme pas : le seuil d'armement est celui de la reprise, pas celui de la
    /// pause, pour qu'un pas traînant devant chez soi ne compte pas comme « elle court ».
    func testWalkingDoesNotArm() {
        var state = AutoPause.State()
        _ = run(30, speed: 1.0, state: &state)
        XCTAssertFalse(state.armed)
    }

    /// Une fois armée, elle le reste : la course a commencé, même si le signal se dégrade ensuite.
    func testArmingSurvivesTheRestOfTheRun() {
        var state = AutoPause.State()
        _ = run(3, speed: 4.0, state: &state)
        _ = run(50, speed: nil, state: &state)
        XCTAssertTrue(state.armed)
    }

    // MARK: - Le délai

    /// Le délai est un délai : neuf secondes d'arrêt ne suffisent pas.
    func testPauseWaitsForTheFullDelay() {
        var state = AutoPause.State()
        _ = run(5, speed: 3.0, state: &state)
        XCTAssertEqual(run(Int(AutoPause.delaySeconds) - 1, speed: 0, state: &state), 0)
        XCTAssertEqual(run(1, speed: 0, state: &state), 1)
    }

    /// Un arrêt bref au milieu d'une course — un trottoir à traverser — ne déclenche rien, et ne
    /// laisse pas non plus de compteur à moitié plein qui ferait basculer le prochain trottoir.
    func testBriefStopsDoNotAccumulate() {
        var state = AutoPause.State()
        _ = run(5, speed: 3.0, state: &state)
        for _ in 0..<10 {
            XCTAssertEqual(run(5, speed: 0, state: &state), 0)
            _ = run(5, speed: 3.0, state: &state)
        }
        XCTAssertEqual(state.stationarySeconds, 0)
    }

    // MARK: - Le réglage coupé

    /// Réglage désactivé : aucune pause, jamais. Mais l'armement continue en silence, pour qu'une
    /// réactivation en pleine course ne mette pas immédiatement en pause une coureuse qui court.
    func testDisabledNeverPausesButKeepsArming() {
        var state = AutoPause.State()
        XCTAssertEqual(run(10, speed: 4.0, state: &state, enabled: false), 0)
        XCTAssertTrue(state.armed)
        XCTAssertEqual(run(60, speed: 0, state: &state, enabled: false), 0)
        // Réactivée, elle repart d'un compteur vide.
        XCTAssertEqual(state.stationarySeconds, 0)
        XCTAssertEqual(run(Int(AutoPause.delaySeconds) - 1, speed: 0, state: &state), 0)
    }

    // MARK: - La reprise

    /// Reprise par la vitesse, le cas nominal.
    func testResumesOnClearSpeed() {
        XCTAssertTrue(AutoPause.shouldResume(speed: 3.0, metersSincePause: 0))
    }

    /// Reprise par l'éloignement, quand la vitesse est indisponible — c'est-à-dire à l'arrêt sous
    /// un immeuble, exactement là où la vitesse manque. Sans cette seconde preuve, la pause
    /// automatique ne se levait plus jamais toute seule.
    func testResumesOnDisplacementWhenSpeedIsUnavailable() {
        XCTAssertFalse(AutoPause.shouldResume(speed: nil, metersSincePause: 0))
        XCTAssertTrue(AutoPause.shouldResume(speed: nil,
                                             metersSincePause: AutoPause.resumeDisplacementMeters + 1))
    }

    /// Le tremblement du GPS à l'arrêt ne relance pas la course : quinze mètres de dérive restent
    /// sous le seuil.
    func testGPSJitterAtAStandstillDoesNotResume() {
        XCTAssertFalse(AutoPause.shouldResume(speed: 0, metersSincePause: 15))
        XCTAssertFalse(AutoPause.shouldResume(speed: nil, metersSincePause: 15))
    }

    /// Hystérésis : repartir demande plus que ce qui a déclenché la pause, sinon pause et reprise
    /// clignotent à chaque fluctuation.
    func testResumeThresholdSitsAboveThePauseThreshold() {
        XCTAssertGreaterThan(AutoPause.resumeSpeedThreshold, AutoPause.pauseSpeedThreshold)
        XCTAssertFalse(AutoPause.shouldResume(speed: AutoPause.pauseSpeedThreshold + 0.1,
                                              metersSincePause: 0))
    }
}
