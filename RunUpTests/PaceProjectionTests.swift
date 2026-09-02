import XCTest
@testable import RunUp

/// Verrouille les temps prévus sur 5 km, 10 km, semi et marathon.
///
/// `projectedPace` applique la formule de Riegel — le temps croît avec la distance élevée à la
/// puissance 1,06 — et elle n'avait aucun test alors qu'elle est déjà une fonction pure, donc
/// gratuite à vérifier. Ce sont pourtant les chiffres sur lesquels quelqu'un décide de viser un
/// marathon, ou d'y renoncer.
///
/// L'enjeu tient dans l'exposant. À 1,0, l'allure serait constante quelle que soit la distance,
/// et le marathon prévu serait le temps d'un 10 km multiplié par quatre — une promesse qui blesse.
/// Trop haut, la prédiction devient si pessimiste qu'elle décourage. Ces tests verrouillent le
/// SENS de la courbe et deux repères connus, pas la troisième décimale.
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

    /// La projection est proportionnelle à la vitesse de référence : quelqu'un deux fois plus
    /// lent doit obtenir une prédiction deux fois plus lente, pas un décalage arbitraire.
    func testProjectionScalesWithTheReferencePace() {
        let normal = PaceModel.projectedPace(fromSecPerKm: 300, fromKm: 10, toKm: 42.195)
        let slower = PaceModel.projectedPace(fromSecPerKm: 600, fromKm: 10, toKm: 42.195)
        XCTAssertEqual(slower, normal * 2, accuracy: 0.001)
    }
}
