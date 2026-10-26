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

    // LES CAPTURES DE DIAGNOSTIC — celles qu'on prend pour REGARDER, pas pour publier.
    //
    // CE QU'ELLES RÉSOLVENT. Sans Xcode en local, un écran redessiné ne se juge qu'une fois
    // installé sur un téléphone : un aller-retour d'un quart d'heure pour savoir si deux tuiles
    // tiennent côte à côte. Celles-ci sortent du même harnais que les captures de la fiche, par
    // le même chemin, avec le même état de démonstration — mais dans un sous-dossier que
    // `screenshots.py` ne regarde pas.
    //
    // POURQUOI UN SOUS-DOSSIER. Le composeur de la fiche apparie chaque capture à une accroche
    // par le chiffre de tête de son nom. Une septième image à la racine recevrait une accroche
    // qui n'existe pas. Il ne lit que les FICHIERS d'un dossier, jamais ses sous-dossiers : une
    // capture rangée dans `diagnostic/` est donc invisible pour lui, et visible dans l'artefact.
    func test7ProfilDiagnostic() { prendre(rang: 7, ecran: "profile", nom: "profil", diagnostic: true) }

    /// La page de quelqu'un, ouverte par-dessus l'onglet Club. `--profil=` se combine avec
    /// `--ecran=` au lieu de le remplacer : une page de profil n'est pas un écran de l'app, elle
    /// se présente au-dessus de n'importe lequel.
    func test8ProfilPublicDiagnostic() {
        prendre(rang: 8, ecran: "club", nom: "profil-public", diagnostic: true, profil: "2")
    }

    /// Le fil, ouvert par-dessus l'onglet Club. Comme `--profil=`, `--mur` se combine avec
    /// `--ecran=` : le fil est un mode de l'onglet social, pas un écran de l'app.
    func test9MurDiagnostic() {
        prendre(rang: 9, ecran: "club", nom: "mur", diagnostic: true, mur: true)
    }

    /// La page d'une course — l'écran qui porte le plus de mise en page : des coureurs, un mur,
    /// un avertissement de dossard. Celui qu'on ne veut surtout pas juger de mémoire.
    func test10CourseDiagnostic() {
        prendre(rang: 10, ecran: "club", nom: "course", diagnostic: true, course: true)
    }

    /// La sortie déroulée — l'écran le plus CHIFFRÉ de l'app : six mesures, douze barres de
    /// splits, un profil de terrain. Rien n'y plante quand un chiffre est faux ; il faut le voir.
    func test11SortieDiagnostic() {
        prendre(rang: 11, ecran: "club", nom: "sortie", diagnostic: true, sortie: true)
    }

    /// Les deux onglets du Club que la démonstration n'ouvre jamais : l'aperçu — niveau, semaine
    /// du club, défi, sorties de groupe — et le classement. Le fil, lui, est déjà la capture 4.
    func test12ClubApercuDiagnostic() {
        prendre(rang: 12, ecran: "club", nom: "club-apercu", diagnostic: true, onglet: "apercu")
    }

    func test13ClubClassementDiagnostic() {
        prendre(rang: 13, ecran: "club", nom: "club-classement", diagnostic: true, onglet: "classement")
    }

    private func prendre(rang: Int, ecran: String, nom: String, diagnostic: Bool = false,
                         profil: String? = nil, mur: Bool = false, course: Bool = false,
                         sortie: Bool = false, onglet: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["--captures", "--ecran=\(ecran)"]
        if let profil { app.launchArguments += ["--profil=\(profil)"] }
        if mur { app.launchArguments += ["--mur"] }
        // La page de course s'ouvre depuis l'écran des courses : il faut donc y être.
        if course { app.launchArguments += ["--course", "--courses"] }
        if sortie { app.launchArguments += ["--sortie"] }
        if let onglet { app.launchArguments += ["--onglet=\(onglet)"] }
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
        piece.name = diagnostic ? "diagnostic-\(nom)" : "\(rang)-\(nom)"
        piece.lifetime = .keepAlways
        add(piece)

        ecrire(capture.pngRepresentation,
               sous: diagnostic ? "diagnostic/\(nom).png" : "\(rang)-\(nom).png")
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
