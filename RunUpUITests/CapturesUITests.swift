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

    // L'ordre EST celui des accroches de `appstore/captions.json`, et les noms portent leur
    // rang : `screenshots.py` apparie par le chiffre de tête, pas par la position dans le
    // dossier. Un écran qui manque ne décale donc pas les cinq autres.

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    // UNE MÉTHODE PAR ÉCRAN, ET C'EST UNE CORRECTION.
    //
    // La première version les prenait dans une boucle, à l'intérieur d'un seul `testCaptures`.
    // Le commentaire d'en-tête promettait « six lancements indépendants : si l'un échoue, les
    // cinq autres sortent quand même » — c'était faux. Une seule méthode est un seul cas de
    // test : l'app a planté sur le premier écran, et les cinq suivants n'ont jamais été tentés.
    //
    // XCTest, lui, isole vraiment deux méthodes : il relance l'app, repart à zéro, et rapporte
    // les échecs séparément. La promesse est maintenant tenue par la structure plutôt que par le
    // commentaire — et un plantage sur le club n'empêche plus d'avoir les statistiques.

    func test1Accueil() { prendre(rang: 1, ecran: "prog", nom: "accueil") }
    func test2Plan() { prendre(rang: 2, ecran: "plan", nom: "plan") }
    func test3Coach() { prendre(rang: 3, ecran: "coach", nom: "coach") }
    func test4Club() { prendre(rang: 4, ecran: "club", nom: "club") }
    func test5Journee() { prendre(rang: 5, ecran: "rings", nom: "journee") }
    func test6Stats() { prendre(rang: 6, ecran: "stats", nom: "stats") }

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

        // ON NE DEMANDE PAS L'ARBRE D'ACCESSIBILITÉ. C'est ce qui a tué le premier essai.
        //
        // La version précédente attendait `app.descendants(matching: .any).firstMatch`, pour ne
        // pas photographier trop tôt. Cette requête-là exige un INSTANTANÉ COMPLET de tous les
        // éléments de l'écran : sur une vue SwiftUI dense — l'accueil, ses anneaux, sa bande de
        // semaine et ses cartes — elle a fait perdre la connexion à l'app, qui est morte sans
        // même laisser de rapport de plantage. Quarante secondes de lancement pour un écran
        // qu'on ne photographiera jamais.
        //
        // Or `XCUIScreen.main.screenshot()` photographie L'ÉCRAN, pas l'app : il n'a besoin
        // d'aucun élément, d'aucun arbre, et il marche même si l'app vient de mourir. La seule
        // chose à attendre est donc que l'app soit au premier plan, ce que le système sait dire
        // sans rien inspecter.
        _ = app.wait(for: .runningForeground, timeout: 30)
        // Puis on laisse la première image se poser. Les animations d'entrée de
        // `ContentRouterView` durent moins d'une demi-seconde ; deux secondes laissent la marge
        // sur une machine chargée sans peser sur les dix-huit lancements.
        Thread.sleep(forTimeInterval: 2.0)

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
