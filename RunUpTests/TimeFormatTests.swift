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
        XCTAssertEqual(TimeFormat.duree(-10), "0 min")
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

    // MARK: - La durée

    /// LE SYMBOLE SE TESTE PAR SON PARAMÈTRE, PAS PAR LA LANGUE COURANTE.
    ///
    /// Le simulateur de l'intégration continue tourne en ANGLAIS. Un test qui lirait
    /// `Locale.current` affirmerait donc « hr » ici et « h » sur la machine de quelqu'un
    /// d'autre — un test qui dépend de la langue de celui qui l'exécute ne vérifie rien. C'est
    /// exactement pour ça que `symboleHeure` prend la langue en argument.
    func testLeSymboleDeLHeureDependDeLaLangue() {
        XCTAssertEqual(TimeFormat.symboleHeure(langue: "en"), "hr")
        XCTAssertEqual(TimeFormat.symboleHeure(langue: "fr"), "h")
        XCTAssertEqual(TimeFormat.symboleHeure(langue: "es"), "h")
        // Langue inconnue ou absente : « h », le symbole international.
        XCTAssertEqual(TimeFormat.symboleHeure(langue: nil), "h")
        XCTAssertEqual(TimeFormat.symboleHeure(langue: "de"), "h")
    }

    /// La FORME, et non les lettres : la langue décide du symbole, pas ce test.
    func testLaDureeNeCommenceJamaisParZeroHeure() {
        // Sous l'heure, aucun symbole d'heure n'apparaît — donc la chaîne est la même partout.
        XCTAssertEqual(TimeFormat.duree(46 * 60), "46 min")
        XCTAssertEqual(TimeFormat.duree(0), "0 min")

        let troisHeures = TimeFormat.duree(3 * 3600 + 28 * 60)
        XCTAssertTrue(troisHeures.hasPrefix("3"), troisHeures)
        XCTAssertTrue(troisHeures.hasSuffix("28"), troisHeures)
        // Resserrée : plus d'espace autour du symbole, c'est tout l'objet de la fusion.
        XCTAssertFalse(troisHeures.contains(" "), troisHeures)

        // Les minutes sur deux chiffres dès qu'une heure les précède : « 1h1 » se lit mal.
        XCTAssertTrue(TimeFormat.duree(3600 + 60).hasSuffix("01"), TimeFormat.duree(3600 + 60))
        // Et jamais de « 0h » en tête pour une durée qui n'atteint pas l'heure.
        XCTAssertFalse(TimeFormat.duree(46 * 60).hasPrefix("0"), TimeFormat.duree(46 * 60))
    }

    /// La fusion ne doit pas avoir changé une VALEUR, seulement une mise en forme. Les heures et
    /// les minutes sortantes sont comparées aux nombres attendus, langue par langue.
    func testLaFusionNAPasChangeLesNombres() {
        for (secondes, heures, minutes) in [(3600, 1, 0), (5700, 1, 35), (12345, 3, 25),
                                            (86399, 23, 59)] {
            let rendu = TimeFormat.duree(secondes)
            // « hr » d'abord, et on s'arrête au premier trouvé : « 1hr35 » contient aussi « h »,
            // et couper dessus donnerait « r35 » pour les minutes. Le test passerait en français
            // et échouerait en anglais, c'est-à-dire sur la machine qui l'exécute vraiment.
            guard let symbole = ["hr", "h"].first(where: { rendu.contains($0) }) else {
                return XCTFail("« \(rendu) » ne porte aucun symbole d'heure à \(secondes) s.")
            }
            let morceaux = rendu.components(separatedBy: symbole)
            XCTAssertEqual(morceaux.first, "\(heures)", "Heures fausses à \(secondes) s.")
            XCTAssertEqual(morceaux.last, String(format: "%02d", minutes),
                           "Minutes fausses à \(secondes) s.")
        }
    }

    // MARK: - Les points d'entrée de l'app délèguent bien ici

    func testPaceModelNeGardeAucuneCopie() {
        XCTAssertEqual(PaceModel.paceText(299.6), TimeFormat.allure(secondesParKm: 299.6))
        XCTAssertEqual(PaceModel.formatDuration(5700), TimeFormat.horloge(5700))
        XCTAssertEqual(PaceModel.formatTotalDuration(5700), TimeFormat.duree(5700))
    }
}
