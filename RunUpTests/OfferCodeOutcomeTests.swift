import XCTest
@testable import RunUp

final class OfferCodeOutcomeTests: XCTestCase {
    func testCodeAccepteOuvrePlus() {
        XCTAssertEqual(OfferCodeOutcome.decide(sheetFailed: false, isSubscribed: true), .unlocked)
    }

    func testFeuilleRefermeeSansRien() {
        XCTAssertEqual(OfferCodeOutcome.decide(sheetFailed: false, isSubscribed: false), .nothingApplied)
    }

    func testFeuilleQuiNeSOuvrePas() {
        XCTAssertEqual(OfferCodeOutcome.decide(sheetFailed: true, isSubscribed: false), .sheetFailed)
    }

    /// Le droit prime sur l'échec de la feuille : c'est le cas d'un code entré depuis l'App Store
    /// pendant que l'app tournait. Annoncer un échec à quelqu'un qui vient d'obtenir Plus serait
    /// le pire des deux messages possibles.
    func testLeDroitPrimeSurLEchecDeLaFeuille() {
        XCTAssertEqual(OfferCodeOutcome.decide(sheetFailed: true, isSubscribed: true), .unlocked)
    }

    /// `nil` d'abonnement veut dire « on ne sait pas encore ». Ce n'est pas un droit.
    func testEtatInconnuNEstPasUnDroit() {
        XCTAssertEqual(OfferCodeOutcome.decide(sheetFailed: false, isSubscribed: nil), .nothingApplied)
        XCTAssertEqual(OfferCodeOutcome.decide(sheetFailed: true, isSubscribed: nil), .sheetFailed)
    }

    func testSeulLEchecEtLeSuccesParlent() {
        XCTAssertNotNil(OfferCodeOutcome.unlocked.message)
        XCTAssertNotNil(OfferCodeOutcome.sheetFailed.message)
        XCTAssertNil(OfferCodeOutcome.nothingApplied.message)
    }
}
