import XCTest
@testable import RunUp

/// Verrouille les temps prévus sur 5 km, 10 km, semi et marathon.
///
/// Ce sont les chiffres sur lesquels quelqu'un décide de viser un marathon, ou d'y renoncer.
///
/// `projectedPace` appliquait la formule de Riegel — le temps croît avec la distance élevée à la
/// puissance 1,06. Elle passe maintenant par Daniels (voir `Vdot`), et Riegel n'est plus que le
/// repli pour ce que la méthode ne couvre pas : en dessous de 1 500 m, au-delà du marathon, ou
/// quand la performance de référence sort de la plage plausible.
///
/// L'enjeu reste le même. Une allure constante quelle que soit la distance annoncerait le temps
/// d'un 10 km multiplié par quatre — une promesse qui blesse. Trop pessimiste, la prédiction
/// décourage. Ces tests verrouillent le SENS de la courbe et deux repères connus, pas la
/// troisième décimale.
final class PaceProjectionTests: XCTestCase {

    /// 10 km en 50:00, soit 5:00/km.
    private let refSecPerKm: Double = 300
    private let refKm: Double = 10

    /// Le plus important : plus la distance monte, plus l'allure ralentit. Une prédiction qui
    /// garderait l'allure du 10 km sur un marathon annoncerait 3 h 30 à quelqu'un qui en fera 4.
    func testLongerDistancesAreSlower() {
        let five = PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: refKm, toKm: 5)
        let half = PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: refKm, toKm: 21.0975)
        let full = PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: refKm, toKm: 42.195)
        XCTAssertLessThan(five, refSecPerKm, "Un 5 km se court plus vite qu'un 10.")
        XCTAssertGreaterThan(half, refSecPerKm, "Un semi se court plus lentement qu'un 10.")
        XCTAssertGreaterThan(full, half, "Un marathon se court plus lentement qu'un semi.")
    }

    /// À distance égale, la référence ressort intacte.
    func testTheReferenceDistanceReturnsItself() {
        XCTAssertEqual(PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: refKm, toKm: refKm),
                       refSecPerKm, accuracy: 0.001)
    }

    /// Repère connu : 50:00 au 10 km donne un marathon autour de 3 h 51 selon Riegel. On vérifie
    /// une fourchette large — l'exactitude à la seconde n'a pas de sens pour une prédiction, mais
    /// sortir de cette fourchette voudrait dire que l'exposant a bougé.
    func testMarathonFromATenKilometreReference() {
        let secPerKm = PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: refKm, toKm: 42.195)
        let total = secPerKm * 42.195
        XCTAssertTrue((13_600...14_200).contains(total),
                      "Marathon prévu : \(Int(total)) s, hors de la fourchette attendue (3 h 47 – 3 h 57).")
    }

    /// Et le 5 km, dans l'autre sens : 50:00 au 10 km donne environ 24 minutes.
    func testFiveKilometresFromATenKilometreReference() {
        let total = PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: refKm, toKm: 5) * 5
        XCTAssertTrue((1_400...1_480).contains(total),
                      "5 km prévu : \(Int(total)) s, hors de la fourchette attendue (23 – 24 min 40).")
    }

    /// Une distance à zéro vient d'un profil incomplet, pas d'un cas exotique : mieux vaut rendre
    /// la référence que diviser par zéro au milieu d'un écran de statistiques.
    func testDegenerateInputsFallBackInsteadOfExploding() {
        XCTAssertEqual(PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: 0, toKm: 10), refSecPerKm)
        XCTAssertEqual(PaceModel.projectedPace(fromSecPerKm: refSecPerKm, fromKm: 10, toKm: 0), refSecPerKm)
    }

    /// CE TEST EXIGEAIT UNE PROPORTIONNALITÉ EXACTE, ET C'ÉTAIT UNE PROPRIÉTÉ DE RIEGEL.
    ///
    /// Il demandait que quelqu'un deux fois plus lent obtienne une prédiction exactement deux fois
    /// plus lente. C'est vrai d'une loi de puissance — Riegel multiplie le temps de référence par
    /// un facteur qui ne dépend que des distances — et c'est faux de la course à pied : deux
    /// personnes dont les 10 km sont dans un rapport de deux n'ont pas des marathons dans un
    /// rapport de deux, parce que la fraction de VO2max qu'on soutient dépend de la DURÉE, et que
    /// la plus lente passe bien plus de temps sur la distance.
    ///
    /// Comme le test de l'allure de VMA, celui-ci verrouillait l'algèbre d'une formule en croyant
    /// verrouiller une vérité. Ce qui compte vraiment, et qui est vérifié ci-dessous, c'est le
    /// SENS : plus lent reste plus lent, et jamais l'inverse.
    func testASlowerReferenceIsAlwaysASlowerPrediction() {
        for cible in [5.0, 10.0, 21.0975, 42.195] {
            var precedente = 0.0
            for reference in [240.0, 300.0, 360.0, 420.0, 480.0, 540.0, 600.0] {
                let predite = PaceModel.projectedPace(fromSecPerKm: reference, fromKm: 10, toKm: cible)
                XCTAssertGreaterThan(predite, precedente,
                                     "sur \(cible) km, une référence de \(Int(reference)) s/km "
                                     + "prédit plus vite qu'une référence plus rapide")
                precedente = predite
            }
        }
    }

    /// UNE PLUS LONGUE DISTANCE NE SE PRÉDIT JAMAIS PLUS VITE QUE LA RÉFÉRENCE.
    ///
    /// C'est la promesse qui blesse, et c'est le défaut que le bornage du VDOT avait introduit :
    /// une référence hors plage était ramenée au plancher, et quelqu'un qui court son 10 km en
    /// 1 h 40 s'entendait prédire un marathon à 7:55/km — plus vite, au kilomètre, que son propre
    /// 10 km. Le chiffre tombait sur l'écran où l'on décide de viser un marathon.
    func testALongerRaceIsNeverPredictedFasterThanTheReference() {
        for reference in [240.0, 300.0, 420.0, 600.0, 720.0, 900.0] {
            for cible in [10.0, 21.0975, 42.195] {
                let predite = PaceModel.projectedPace(fromSecPerKm: reference, fromKm: 10, toKm: cible)
                XCTAssertGreaterThanOrEqual(predite, reference - 0.001,
                                            "référence \(Int(reference)) s/km sur 10 km : le "
                                            + "\(cible) km est prédit à \(Int(predite)) s/km")
            }
        }
    }

    /// Et le cas exact qui a servi : un 10 km en 1 h 40 est une vraie personne, pas une faute de
    /// frappe. Son marathon se prédit plus lentement que son 10 km, pas plus vite.
    func testAVerySlowButRealRunnerGetsAnHonestMarathon() {
        let reference = 600.0   // 10:00/km, soit 10 km en 1 h 40
        let marathon = PaceModel.projectedPace(fromSecPerKm: reference, fromKm: 10, toKm: 42.195)
        XCTAssertGreaterThan(marathon, reference,
                             "le marathon est prédit à \(Int(marathon)) s/km, plus vite que les "
                             + "\(Int(reference)) s/km de son 10 km")
        // Et il reste dans le plausible : pas une projection qui s'envole.
        XCTAssertLessThan(marathon, reference * 1.6)
    }
}
