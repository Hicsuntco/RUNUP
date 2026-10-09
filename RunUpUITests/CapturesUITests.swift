import XCTest

/// Les captures de la fiche App Store, prises par la machine.
///
/// # CE QUE CE FICHIER REMPLACE
///
/// Dix-huit captures prises à la main sur un téléphone — six écrans, trois langues — à refaire
/// à chaque changement d'accent, de police ou de mise en page. En pratique ça veut dire qu'on ne
/// les refait pas : les six en ligne dataient du 30 août, portaient l'ancien rose, et seules
/// quatre des six existaient, en français seulement.
///
/// # COMMENT IL S'Y PREND
///
/// UNE CAPTURE PAR LANCEMENT, et pas une navigation à travers l'app. Naviguer veut dire trouver
/// un onglet, attendre une transition, deviner quand elle est finie — six fois, et la première
/// qui bronche emporte les cinq suivantes. Le drapeau `--ecran=` dit à l'app où s'ouvrir, elle
/// s'y ouvre, on photographie. Six lancements de quelques secondes, indépendants : si l'un
/// échoue, les cinq autres sortent quand même.
///
/// L'ÉTAT VIENT DE L'APP, pas du test. `CaptureSeed` le pose par le vrai chemin d'inscription,
/// donc la capture montre un état dans lequel l'app peut réellement se trouver.
///
/// LES FICHIERS SONT ÉCRITS SUR LA MACHINE HÔTE. Un processus de simulateur voit le disque du
/// Mac : le chemin arrive par `RUNUP_CAPTURES_DIR`, et les PNG atterrissent directement là où
/// `screenshots.py` les attend. Sans cette variable, le test se contente d'attacher les images
/// au rapport — utile en local, inexploitable par un script.
final class CapturesUITests: XCTestCase {

    /// L'ordre EST celui des accroches de `appstore/captions.json`, et les noms portent leur
    /// rang : `screenshots.py` apparie par le chiffre de tête, pas par la position dans le
    /// dossier. Un écran qui manque ne décale donc pas les cinq autres.
    private static let ecrans: [(rang: Int, ecran: String, nom: String)] = [
        (1, "prog", "accueil"),
        (2, "plan", "plan"),
        (3, "coach", "coach"),
        (4, "club", "club"),
        (5, "rings", "journee"),
        (6, "stats", "stats"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCaptures() throws {
        for (rang, ecran, nom) in Self.ecrans {
            prendre(rang: rang, ecran: ecran, nom: nom)
        }
    }

    private func prendre(rang: Int, ecran: String, nom: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--captures", "--ecran=\(ecran)"]
        // La langue et la région viennent de l'extérieur : le même test tourne trois fois, une
        // par langue, et c'est le workflow qui dit laquelle. `-AppleLanguages` est la seule
        // façon de forcer la langue d'un lancement sans toucher aux réglages du simulateur.
        if let langue = ProcessInfo.processInfo.environment["RUNUP_LANG"] {
            app.launchArguments += ["-AppleLanguages", "(\(langue))", "-AppleLocale", langue]
        }
        app.launch()

        // Une attente sur un élément plutôt qu'un `sleep` : l'app est prête quand elle a dessiné
        // quelque chose, et ce moment-là n'a pas de durée fixe. Le repli au bout de huit secondes
        // photographie quand même — une capture ratée se voit, une capture absente ne se voit pas.
        _ = app.wait(for: .runningForeground, timeout: 8)
        let dessine = app.descendants(matching: .any).firstMatch.waitForExistence(timeout: 8)
        if !dessine {
            XCTFail("\(nom) : l'app n'a rien dessiné en huit secondes")
        }
        // Les animations d'entrée de `ContentRouterView` durent moins d'une demi-seconde ; une
        // seconde laisse la marge sans allonger les dix-huit lancements de façon sensible.
        Thread.sleep(forTimeInterval: 1.0)

        let capture = XCUIScreen.main.screenshot()
        let piece = XCTAttachment(screenshot: capture)
        piece.name = "\(rang)-\(nom)"
        piece.lifetime = .keepAlways
        add(piece)

        ecrire(capture.pngRepresentation, sous: "\(rang)-\(nom).png")
        app.terminate()
    }

    /// Écrit le PNG sur le disque de la machine hôte, quand elle a dit où.
    private func ecrire(_ donnees: Data, sous nom: String) {
        guard let dossier = ProcessInfo.processInfo.environment["RUNUP_CAPTURES_DIR"] else { return }
        let url = URL(fileURLWithPath: dossier).appendingPathComponent(nom)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try donnees.write(to: url)
        } catch {
            // Pas un échec de test : les images sont déjà attachées au rapport, et l'écriture
            // sur l'hôte n'est qu'un raccourci pour le script qui les compose.
            print("capture non écrite sur l'hôte : \(error)")
        }
    }
}
