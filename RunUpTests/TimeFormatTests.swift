import XCTest
@testable import RunUp

/// Verrouille la mise en forme des durées, et surtout le défaut qu'elle a réparé : il y en avait
/// six copies sur trois cibles, et deux ne disaient pas la même chose que les autres.
///
/// Celle du widget est la plus instructive. `PaceModel.formatDuration` porte depuis longtemps la
/// mise en garde exacte — « a 95-minute long run used to render as "95:00" instead of "1:35:00"
/// everywhere this was (mis)used for that » — et la copie du widget, dans un autre dossier et une
/// autre cible, ne l'avait jamais reçue. Une sortie longue mise en pause affichait donc « 95:00 »
/// sur l'écran verrouillé. Un défaut hors de portée de la relecture : il ne se voit qu'en mettant
/// les deux fichiers côte à côte, et rien ne demandait de le faire.
final class TimeFormatTests: XCTestCase {

    // MARK: - Le défaut du widget

    func testUneHeureEtDemieNeSEcritPasQuatreVingtQuinzeMinutes() {
        XCTAssertEqual(TimeFormat.horloge(5700), "1:35:00")
        XCTAssertNotEqual(TimeFormat.horloge(5700), "95:00")
    }

    func testLHorlogeNAfficheLHeureQueQuandIlYEnAUne() {
        XCTAssertEqual(TimeFormat.horloge(0), "0:00")
        XCTAssertEqual(TimeFormat.horloge(59), "0:59")
        XCTAssertEqual(TimeFormat.horloge(60), "1:00")
        XCTAssertEqual(TimeFormat.horloge(3599), "59:59")
        XCTAssertEqual(TimeFormat.horloge(3600), "1:00:00")
    }

    func testLHorlogeArrondit() {
        XCTAssertEqual(TimeFormat.horloge(59.6), "1:00")
        XCTAssertEqual(TimeFormat.horloge(59.4), "0:59")
    }

    /// Une valeur négative ne doit pas produire un temps négatif : les trois copies d'origine ne
    /// s'en protégeaient pas toutes.
    func testAucuneDureeNegative() {
        XCTAssertEqual(TimeFormat.horloge(-10), "0:00")
        XCTAssertEqual(TimeFormat.allure(secondesParKm: -10), "0:00")
        XCTAssertEqual(TimeFormat.parle(-10), "0 min")
        XCTAssertEqual(TimeFormat.compacte(-10), "0 min")
    }

    // MARK: - L'allure

    func testLAllureArrondit() {
        XCTAssertEqual(TimeFormat.allure(secondesParKm: 299.6), "5:00")
        XCTAssertEqual(TimeFormat.allure(secondesParKm: 299.4), "4:59")
    }

    /// Une allure est une durée AU KILOMÈTRE : elle ne passe pas aux heures, et c'est voulu.
    /// Confondre les deux fonctions est précisément ce qui produisait « 95:00 ».
    func testLAllureNePasseJamaisAuxHeures() {
        XCTAssertEqual(TimeFormat.allure(secondesParKm: 5700), "95:00")
        XCTAssertEqual(TimeFormat.horloge(5700), "1:35:00")
    }

    // MARK: - La durée telle qu'on la dit

    func testLaDureeParleeNeCommenceJamaisParZeroHeure() {
        XCTAssertEqual(TimeFormat.parle(46 * 60), "46 min")
        XCTAssertEqual(TimeFormat.parle(3 * 3600 + 28 * 60), "3 h 28")
        XCTAssertEqual(TimeFormat.parle(3600 + 60), "1 h 01")
        XCTAssertFalse(TimeFormat.parle(46 * 60).contains("0 h"))
    }

    /// Les deux formes coexistent EXPRÈS, et la différence est exactement l'espacement — pas une
    /// valeur. Si l'une des deux se mettait à arrondir autrement, deux écrans montreraient deux
    /// durées pour la même course.
    func testLesDeuxFormesNeDifferentQueParLEspacement() {
        for secondes in [0, 59, 60, 3599, 3600, 5700, 12345, 86399] {
            let serree = TimeFormat.compacte(secondes).replacingOccurrences(of: " ", with: "")
            let espacee = TimeFormat.parle(secondes).replacingOccurrences(of: " ", with: "")
            XCTAssertEqual(serree, espacee, "Désaccord à \(secondes) s.")
        }
    }

    // MARK: - Les points d'entrée de l'app délèguent bien ici

    func testPaceModelNeGardeAucuneCopie() {
        XCTAssertEqual(PaceModel.paceText(299.6), TimeFormat.allure(secondesParKm: 299.6))
        XCTAssertEqual(PaceModel.formatDuration(5700), TimeFormat.horloge(5700))
        XCTAssertEqual(PaceModel.formatTotalDuration(5700), TimeFormat.compacte(5700))
    }
}
