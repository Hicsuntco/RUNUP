import XCTest
@testable import RunUp

/// Verrouille le rapport de charge aigu sur chronique.
///
/// Ce n'est pas une statistique d'agrément : c'est un marqueur de blessure. Une semaine nettement
/// plus lourde que celles qui la précèdent est le mécanisme par lequel on se blesse en suivant
/// scrupuleusement son programme, et 1,5 est le seuil que la littérature retient pour le signaler.
///
/// Le calcul vivait dans une propriété de `StatsView`, où il n'était vérifiable qu'en accumulant
/// huit semaines de vraies courses. Autrement dit : jamais.
final class TrainingLoadTests: XCTestCase {

    /// Sous quatre semaines, il n'y a pas d'habitude à laquelle comparer. Rendre un rapport
    /// serait pire que n'en rendre aucun : il donnerait une alerte, ou un feu vert, sans
    /// fondement.
    func testTooLittleHistoryGivesNoRatio() {
        XCTAssertNil(TrainingLoad.acuteChronicRatio(weeklyKm: []))
        XCTAssertNil(TrainingLoad.acuteChronicRatio(weeklyKm: [20, 20, 20]))
    }

    /// Quatre semaines à zéro : personne n'a couru, il n'y a rien à comparer non plus.
    func testNoDistanceGivesNoRatio() {
        XCTAssertNil(TrainingLoad.acuteChronicRatio(weeklyKm: [0, 0, 0, 0]))
    }

    /// Une charge stable tourne autour de 1.
    func testASteadyLoadSitsAtOne() {
        let ratio = TrainingLoad.acuteChronicRatio(weeklyKm: [30, 30, 30, 30])
        XCTAssertEqual(ratio ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(TrainingLoad.zone(for: ratio ?? 0), .optimal)
    }

    /// Le cas dangereux : trois semaines tranquilles, puis une semaine qui double.
    func testASuddenlyHeavyWeekIsFlagged() {
        let ratio = TrainingLoad.acuteChronicRatio(weeklyKm: [20, 20, 20, 60])
        XCTAssertNotNil(ratio)
        XCTAssertEqual(TrainingLoad.zone(for: ratio!), .high,
                       "Tripler le volume en une semaine doit être signalé.")
    }

    /// Et le cas inverse : un arrêt, ou une semaine de décharge.
    func testAQuietWeekIsFlaggedAsLowLoad() {
        let ratio = TrainingLoad.acuteChronicRatio(weeklyKm: [40, 40, 40, 8])
        XCTAssertEqual(TrainingLoad.zone(for: ratio!), .low)
    }

    /// La moyenne INCLUT la semaine en cours, ce qui amortit le rapport : doubler ne donne pas
    /// 2,0 mais 1,6. Ce test documente ce comportement plutôt que de le corriger — déplacer la
    /// fenêtre changerait le seuil auquel l'alerte se déclenche, et ce choix appartient à
    /// l'entraînement, pas au remaniement.
    func testTheCurrentWeekIsPartOfItsOwnAverage() {
        let ratio = TrainingLoad.acuteChronicRatio(weeklyKm: [20, 20, 20, 40])!
        XCTAssertEqual(ratio, 40 / 25, accuracy: 0.0001,
                       "Moyenne sur quatre semaines, semaine en cours comprise.")
    }

    /// Les bornes sont des bornes : à 1,5 pile on n'est pas encore en charge élevée.
    func testTheThresholdsAreExclusive() {
        XCTAssertEqual(TrainingLoad.zone(for: TrainingLoad.highRatio), .optimal)
        XCTAssertEqual(TrainingLoad.zone(for: TrainingLoad.highRatio + 0.01), .high)
        XCTAssertEqual(TrainingLoad.zone(for: TrainingLoad.lowRatio), .optimal)
        XCTAssertEqual(TrainingLoad.zone(for: TrainingLoad.lowRatio - 0.01), .low)
    }

    /// Seules les quatre dernières semaines comptent : un gros mois vieux de six semaines ne doit
    /// plus peser sur le jugement d'aujourd'hui.
    func testOnlyTheRecentWindowCounts() {
        let withOldSpike = TrainingLoad.acuteChronicRatio(weeklyKm: [90, 90, 30, 30, 30, 30])
        let withoutIt = TrainingLoad.acuteChronicRatio(weeklyKm: [30, 30, 30, 30])
        XCTAssertEqual(withOldSpike ?? 0, withoutIt ?? -1, accuracy: 0.0001)
    }

    /// Chaque zone doit porter une clé, et trois clés distinctes — deux zones qui affichent le
    /// même libellé sont deux zones qu'on aurait pu ne pas distinguer.
    func testEveryZoneHasItsOwnLabel() {
        let keys = Set([TrainingLoad.Zone.low, .optimal, .high].map(\.labelKey))
        XCTAssertEqual(keys.count, 3)
        XCTAssertFalse(keys.contains(""))
    }
}
