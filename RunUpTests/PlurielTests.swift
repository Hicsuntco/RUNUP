import XCTest
@testable import RunUp

/// Zéro n'est pas au même nombre dans les trois langues de l'app, et c'est ce que `Pluriel` sait.
///
/// La règle était écrite `n > 1` partout — la règle française. Une anglophone qui s'inscrit lisait
/// donc « 0 run », « 0 badge », « 0 day in a row », « 0 follower » le jour même, sur les écrans
/// d'un compte neuf. Ces tests sont là pour que la correction ne reparte pas : ils vérifient les
/// trois langues sans qu'il faille changer celle du simulateur.
final class PlurielTests: XCTestCase {

    // MARK: - Le français met zéro au singulier

    func testFrancaisZeroEtUnAuSingulier() {
        XCTAssertTrue(Pluriel.estSingulier(0, langue: "fr"), "« 0 course », pas « 0 courses »")
        XCTAssertTrue(Pluriel.estSingulier(1, langue: "fr"))
    }

    func testFrancaisDeuxEtPlusAuPluriel() {
        XCTAssertFalse(Pluriel.estSingulier(2, langue: "fr"))
        XCTAssertFalse(Pluriel.estSingulier(12, langue: "fr"))
        XCTAssertFalse(Pluriel.estSingulier(100, langue: "fr"))
    }

    // MARK: - L'anglais et l'espagnol mettent zéro au pluriel

    func testAnglaisZeroAuPluriel() {
        // C'EST LE DÉFAUT CORRIGÉ. Un compte neuf affiche zéro partout.
        XCTAssertFalse(Pluriel.estSingulier(0, langue: "en"), "« 0 runs », pas « 0 run »")
        XCTAssertFalse(Pluriel.estSingulier(0, langue: "es"), "« 0 salidas », pas « 0 salida »")
    }

    func testAnglaisEtEspagnolUnSeulAuSingulier() {
        XCTAssertTrue(Pluriel.estSingulier(1, langue: "en"))
        XCTAssertTrue(Pluriel.estSingulier(1, langue: "es"))
        XCTAssertFalse(Pluriel.estSingulier(2, langue: "en"))
        XCTAssertFalse(Pluriel.estSingulier(2, langue: "es"))
    }

    // MARK: - Ce qui arrive aux cas qu'on n'attendait pas

    func testLangueInconnueSuitLaRegleMajoritaire() {
        // Le `default` n'est pas un hasard : seul UN au singulier est la règle de la très grande
        // majorité des langues, donc la moins fausse pour une langue ajoutée sans y penser.
        XCTAssertFalse(Pluriel.estSingulier(0, langue: "de"))
        XCTAssertTrue(Pluriel.estSingulier(1, langue: "de"))
    }

    func testUnNombreNegatifSuitSaValeurAbsolue() {
        // `bars.count - 1 - i` peut passer sous zéro si l'appelant se trompe d'index : mieux vaut
        // « Il y a 1 semaine » que de choisir le pluriel sur un signe.
        XCTAssertTrue(Pluriel.estSingulier(-1, langue: "en"))
        XCTAssertFalse(Pluriel.estSingulier(-2, langue: "en"))
    }

    // MARK: - Le choix des deux formes

    func testChoisirRendLaFormeAttendue() {
        XCTAssertEqual(Pluriel.choisir(1, "sortie", "sorties"), "sortie")
        XCTAssertEqual(Pluriel.choisir(3, "sortie", "sorties"), "sorties")
    }

    func testLaLangueAfficheeEstUnCodeDeDeuxLettres() {
        // « pt-BR », « es-419 » : c'est la langue qui porte la règle, pas la région.
        let langue = Pluriel.langueAffichee
        XCTAssertEqual(langue.count, 2, "« \(langue) » n'est pas un code de langue à deux lettres")
        XCTAssertEqual(langue, langue.lowercased())
    }
}
