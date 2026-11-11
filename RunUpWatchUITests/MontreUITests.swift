import XCTest

/// LE PREMIER TEST QUI PILOTE LA MONTRE.
///
/// # POURQUOI IL N'EXISTAIT PAS
///
/// Il n'y avait aucune cible de test d'interface watchOS. La chaîne sait PHOTOGRAPHIER la montre
/// depuis le chantier 33 — on construit, on installe, `simctl io screenshot` — mais photographier
/// n'est pas piloter : une image dit à quoi l'écran ressemble, pas qu'on peut s'en servir.
///
/// La montre était donc la seule partie du produit qu'aucun test ne touchait. Et c'est celle qui
/// vient de passer des mois à parler français à tout le monde.
///
/// # CE QUE XCUITEST SAIT FAIRE SUR WATCHOS, ET CE QU'IL NE SAIT PAS
///
/// Le support existe depuis Xcode 12.5, et il est PARTIEL : pas d'enregistrement, et les retours
/// publics décrivent des éléments qui n'apparaissent dans l'arbre d'accessibilité qu'après un
/// défilement. Les délais sont donc généreux et les assertions portent sur du texte visible dès
/// l'ouverture, pas sur des éléments qu'il faudrait aller chercher.
///
/// Le premier test ne lance pas de séance : `workout.start()` ouvre une session HealthKit, et la
/// construction des tests n'est pas signée. Piloter un démarrage de course demandera de traiter
/// ce cas-là ; ce n'est pas la première chose à écrire.
final class MontreUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `-AppleLanguages` en argument de LANCEMENT, comme pour les captures de l'iPhone : il
    /// remplace la langue pour ce processus-là seulement, sans toucher au simulateur.
    private func lancer(langue: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(langue))", "-AppleLocale", langue]
        app.launch()
        return app
    }

    /// Le test de fumée : l'app s'ouvre, et son écran porte ce qu'il doit porter.
    ///
    /// Vingt secondes d'attente, et ce n'est pas de la prudence gratuite : un premier lancement
    /// sur un simulateur watchOS neuf est lent, et un échec par impatience ressemble exactement à
    /// un échec par défaut.
    func testLEcranDAccueilSOuvreEtPorteSonBouton() {
        let app = lancer(langue: "fr")
        XCTAssertTrue(app.staticTexts["Aujourd'hui"].waitForExistence(timeout: 20),
                      "l'écran d'accueil de la montre ne s'est pas affiché")
        XCTAssertTrue(app.descendants(matching: .any)["Courir"].exists,
                      "le bouton « Courir » n'est pas là")
    }

    /// LE DÉFAUT QUI A VÉCU DES MOIS.
    ///
    /// La montre et le widget disaient « Aujourd'hui » à tout le monde, quelle que soit la langue
    /// du téléphone — leurs cibles ne portaient pas le catalogue de traductions. Corrigé au
    /// chantier 18, et jamais gardé par autre chose qu'une relecture.
    ///
    /// Rien dans la chaîne ne l'aurait revu : les captures de montre ne sont prises qu'en
    /// français, et un test unitaire ne lance pas l'app. C'est précisément ce que cette cible
    /// existe pour attraper.
    func testLaMontreParleLaLangueDuTelephoneEtPasLaNotre() {
        let app = lancer(langue: "en")
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 20),
                      "lancée en anglais, la montre n'affiche pas « Today »")
        XCTAssertFalse(app.staticTexts["Aujourd'hui"].exists,
                       "lancée en anglais, la montre affiche encore le français")
    }

    /// Et en espagnol, parce que deux langues qui s'accordent ne font pas trois.
    func testEtEnEspagnol() {
        let app = lancer(langue: "es")
        XCTAssertTrue(app.staticTexts["Hoy"].waitForExistence(timeout: 20),
                      "lancée en espagnol, la montre n'affiche pas « Hoy »")
    }
}
