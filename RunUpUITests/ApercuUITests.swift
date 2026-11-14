import XCTest

/// L'APERÇU VIDÉO DE LA FICHE, FILMÉ PAR LA MACHINE.
///
/// # CE QUE REMPLACE CE TEST
///
/// `appstore/APERCU.md` décrit la façon de faire d'avant : activer l'enregistrement d'écran sur
/// un iPhone, filmer six plans d'une seule traite, raccourcir dans Photos pour tenir sous les
/// 25 Mo que GitHub accepte depuis un navigateur, déposer le fichier, lancer le workflow. À
/// refaire pour chaque langue, et à refaire en entier dès qu'un écran change.
///
/// En pratique, ce qui se refait à la main ne se refait pas : c'est exactement ce qui était
/// arrivé aux captures, en ligne depuis le 30 août dans l'ancien rose, avant que la machine ne
/// les reprenne. Un aperçu qui montre une version de l'app qui n'existe plus est pire que pas
/// d'aperçu.
///
/// Le simulateur sait s'enregistrer (`xcrun simctl io … recordVideo`), et ce test le pilote
/// pendant ce temps-là. Le chemin manuel reste décrit et reste valable — c'est lui qu'il faudra
/// reprendre le jour où l'aperçu devra montrer une vraie course dehors, que le simulateur ne
/// sait pas jouer.
///
/// # POURQUOI DES COORDONNÉES ET PAS DES ÉLÉMENTS
///
/// Même raison que pour les captures, et elle a coûté un premier essai : demander un élément à
/// XCTest exige un instantané de l'arbre d'accessibilité, ce qui a tué l'app sur les écrans
/// SwiftUI denses. Un appui à une coordonnée normalisée ne consulte rien.
///
/// Les cinq onglets sont relevés sur une capture réelle : la barre flottante occupe la bande
/// 0,894 → 0,949 en hauteur, et les cinq pastilles sont centrées sur 0,141 / 0,320 / 0,500 /
/// 0,679 / 0,858. Un changement de la barre les décale : c'est le genre de constante qu'il faut
/// revérifier sur une capture, pas deviner.
///
/// # LE DÉCOUPAGE, VINGT-SIX SECONDES
///
/// Apple en exige quinze au minimum et trente au maximum. Quatre plans, dans l'ordre de ce que
/// chacun PROUVE plutôt que dans l'ordre de l'app :
///
///   l'accueil, puis il défile      — voilà ta journée, en un écran
///   le coach, puis il défile       — il a lu tes séances, il répond dessus
///   les stats, puis elles défilent — tes records, sur tes vraies sorties
///   le profil, puis il défile      — ce que tu as construit
///   retour à l'accueil             — on finit là où on commence
///
/// Les durées ne sont pas écrites ici parce qu'elles ne s'écrivent pas : le premier essai visait
/// vingt-six secondes et en a duré plus de trente-six. Un glissement lent dure ce qu'il dure, une
/// transition d'onglet aussi, et les deux varient avec la charge de la machine. Le test dit donc
/// quand il commence et quand il finit, et `apercu.py` coupe sur ces deux marques.
final class ApercuUITests: XCTestCase {

    /// Les cinq onglets, en fraction de la largeur. Relevés sur une capture (voir l'en-tête).
    private enum Onglet: CGFloat {
        case prog = 0.141, coach = 0.320, run = 0.500, stats = 0.679, profil = 0.858
    }
    /// Le milieu de la barre flottante, en fraction de la hauteur.
    private static let barre: CGFloat = 0.921

    func testApercu() throws {
        // CE TEST NE TOURNE QUE QUAND ON LE DEMANDE. La cible est la même que celle des
        // captures, et le workflow la lance quatre fois par langue : sans ce garde-fou, chaque
        // passe paierait vingt-six secondes pour un enregistrement que personne ne filme.
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNUP_APERCU"] != nil,
                          "Aperçu non demandé.")

        let app = XCUIApplication()
        // `--film` : les animations jouent. Sans lui, l'app les fige — c'est ce qu'il faut
        // pour une photo, et exactement ce qu'il ne faut pas pour un film. Voir
        // `Demonstration.animationsFigees`.
        app.launchArguments = ["--captures", "--film", "--ecran=prog", "--clair"]
        if let langue = ProcessInfo.processInfo.environment["RUNUP_LANG"] {
            app.launchArguments += ["-AppleLanguages", "(\(langue))", "-AppleLocale", langue]
        }
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 60)
        Thread.sleep(forTimeInterval: 1.5)

        // L'HORODATAGE DU DÉPART, ÉCRIT SUR L'HÔTE, ET IL COUVRE AUSSI LE PRÉCHAUFFAGE.
        //
        // L'enregistrement commence avant que `xcodebuild` n'ait installé et lancé l'app : la
        // vidéo s'ouvre donc sur plusieurs secondes d'écran d'accueil du simulateur, et leur
        // durée varie d'une exécution à l'autre. Les deviner, c'est publier un aperçu qui
        // commence sur du vide ou qui coupe la première seconde de l'app.
        //
        // Le test dit donc l'heure qu'il est au moment où l'app paraît. Le workflow connaît
        // celle où l'enregistrement a commencé ; la soustraction donne exactement ce qu'il faut
        // couper. Une seule horloge pour tout ce qui suit : le préchauffage comme la prise s'y
        // repèrent, ce qui permet de mesurer le premier dans l'enregistrement.
        depart = Date().timeIntervalSince1970
        ecrire("\(depart)", sous: "debut.txt")

        // UNE PASSE À BLANC AVANT LA PRISE, ET ELLE CORRIGE QUELQUE CHOSE DE VISIBLE.
        //
        // Le premier essai montre, au moment où l'on passe sur le Coach, UN DEMI-SECONDE D'ÉCRAN
        // VIDE : la barre d'onglets est là, le contenu n'y est pas encore. C'est la construction
        // de la vue, qui est la plus lourde de l'app — une conversation et ses longs textes. Les
        // deux autres onglets n'ont pas ce trou : Stats paraît d'un coup, Profil arrive en fondu.
        //
        // On touche donc les quatre onglets une fois avant de commencer à compter. Ce n'est pas
        // du maquillage : ce que montre l'aperçu est ce que voit quelqu'un qui a déjà ouvert
        // l'onglet une fois, c'est-à-dire tout le monde sauf à la toute première seconde.
        //
        // ET CETTE PASSE EST MAINTENANT RELEVÉE, parce qu'elle est le seul endroit où le défaut
        // se voit. Elle ouvre chaque onglet pour la PREMIÈRE fois ; la prise, elle, ne montre
        // que des onglets déjà ouverts. Mesurer la prise seule reviendrait à mesurer l'app une
        // fois le défaut passé, et à conclure qu'il n'y en a pas.
        //
        // Les repères partent donc dans `prechauffage.json`, que `ci_scripts/bascules.py`
        // relit : d'un côté combien d'images vides à la toute première ouverture, de l'autre
        // combien à la deuxième. Deux nombres au lieu d'une impression.
        //
        // 1,4 s de pose et non 0,7 : la mesure prend sa référence un demi-seconde après
        // l'arrivée de l'écran, et il lui faut de la marge avant l'appui suivant.
        //
        // PUIS 2,0 s, ET C'EST LA PREMIÈRE BASCULE QUI L'A DEMANDÉ. Le 13 novembre, la campagne
        // espagnole a refusé son film : au plan « première-coach », l'image montrait le Profil.
        // `bascules.py` donne la mesure plutôt que l'impression — « changement d'écran à 0,13 s
        // avant le plan (attendu 0,60) ». La bascule avait bien eu lieu, mais trop tard pour que
        // l'écran soit posé quand la mesure l'a regardé ; les trois suivantes tenaient leurs
        // 0,60 s. C'est la PREMIÈRE de la campagne qui est lente, celle qui suit le lancement,
        // et le français comme l'anglais l'avaient passée de justesse.
        //
        // Six dixièmes de plus par onglet, quatre onglets, trois langues : sept secondes sur une
        // campagne d'une heure. Le garde, lui, a fait exactement son travail — un film coupé sur
        // le mauvais écran serait parti sur l'App Store.
        // Le type est écrit plutôt que déduit : un littéral de tuples mêlant une valeur nommée
        // et des formes abrégées compile ou non selon l'humeur de l'inférence, et ici une erreur
        // de compilation ne se découvre qu'au bout de quarante minutes de machine.
        let passeAblanc: [(String, Onglet)] = [("coach", .coach), ("stats", .stats),
                                               ("profil", .profil), ("accueil", .prog)]
        for (nom, onglet) in passeAblanc {
            plan(app, "première-\(nom)", onglet: onglet, pose: 2.0, defilements: 0, prise: false)
        }
        Thread.sleep(forTimeInterval: 0.8)

        // HUIT PLANS PLUTÔT QUE CINQ, ET DES PLANS PLUS COURTS.
        //
        // « Un peu long », signalé sur le premier montage. Le film durait vingt-quatre secondes
        // et Apple en exige quinze au minimum : ce n'est donc pas la durée totale qu'il fallait
        // réduire, c'est la fréquence des coupes. Un plan de trois secondes et demie sur un
        // écran qui ne bouge pas, c'est long ; le même écran en deux plans de deux secondes,
        // non.
        //
        // Chaque onglet se découpe donc en deux : l'écran tel qu'il s'ouvre, puis l'écran une
        // fois descendu. Deux titres, deux choses à dire, deux coupes.
        //
        // DEUX DÉFILEMENTS ET NON TROIS, parce qu'un défilement coûte ce que la machine veut
        // bien. Mesuré sur deux exécutions du harnais : 3,17 s, 3,20 s, 3,40 s, et une fois
        // 4,67 s pour le même geste — et changer la vitesse demandée n'y a rien fait. C'est la
        // charge d'une machine qu'on ne voit pas, pas le réglage. Trois plans de défilement
        // poussaient le film à vingt-huit secondes, à deux du plafond d'Apple ; deux le gardent
        // sous vingt même dans le pire des cas mesurés. Le Coach perd le sien : son texte est
        // long, et le défiler n'apprend rien de plus que le lire.
        plan(app, "accueil", onglet: nil, pose: 2.0, defilements: 0)
        plan(app, "accueil-bas", onglet: nil, pose: 1.0, defilements: 1)
        plan(app, "coach", onglet: .coach, pose: 2.0, defilements: 0)
        plan(app, "stats", onglet: .stats, pose: 2.0, defilements: 0)
        plan(app, "stats-bas", onglet: nil, pose: 1.0, defilements: 1)
        plan(app, "profil", onglet: .profil, pose: 2.0, defilements: 0)
        plan(app, "retour", onglet: .prog, pose: 2.0, defilements: 0)

        // LE DÉCOUPAGE VIENT D'ICI, parce que c'est ici qu'on le connaît.
        //
        // Le montage a besoin de savoir où commence et où finit chaque plan. Les deviner depuis
        // les durées écrites plus haut serait faux : un glissement lent dure ce qu'il dure, une
        // transition d'onglet aussi, et les deux varient avec la charge de la machine — le
        // premier essai visait vingt-six secondes et en a duré trente-six.
        //
        // Le test relève donc l'heure à chaque bascule, et rend des décalages depuis le début de
        // la prise. `ci_scripts/montage.py` y accroche les titres.
        func decoupage(_ liste: [(nom: String, debut: TimeInterval, fin: TimeInterval,
                                  bascule: Bool)]) -> String {
            "[" + liste.map {
                "{\"nom\":\"\($0.nom)\",\"debut\":\($0.debut - depart),"
                + "\"fin\":\($0.fin - depart),\"bascule\":\($0.bascule)}"
            }.joined(separator: ",") + "]"
        }
        ecrire(decoupage(bornes), sous: "temps.json")
        ecrire(decoupage(prechauffage), sous: "prechauffage.json")

        // L'HEURE DE LA FIN, pour que la vidéo s'arrête sur l'accueil.
        //
        // Le premier essai durait exactement trente secondes : le plafond d'Apple, atteint parce
        // que la caméra tournait encore pendant le démontage du test. Le dernier plan — le retour
        // à l'accueil, celui sur lequel on veut finir — était hors champ, et la vidéo s'achevait
        // sur ce qui traînait après. Dire quand ça s'arrête vaut mieux que laisser un plafond le
        // décider.
        ecrire("\(Date().timeIntervalSince1970)", sous: "fin.txt")
    }

    private var depart: TimeInterval = 0
    private var bornes: [(nom: String, debut: TimeInterval, fin: TimeInterval, bascule: Bool)] = []
    /// Les mêmes repères pour la passe à blanc. Ils ne vont pas au montage — ils ne sont pas des
    /// plans du film — mais à la mesure, qui y lit la PREMIÈRE ouverture de chaque onglet.
    private var prechauffage: [(nom: String, debut: TimeInterval, fin: TimeInterval,
                                bascule: Bool)] = []

    /// Un plan : on y va, on laisse voir, on défile une fois, on laisse voir encore.
    ///
    /// La bascule d'onglet est HORS du plan : elle appartient à la coupe, pas à l'image. Le plan
    /// commence quand l'écran est en place, ce qui évite au montage de garder une transition.
    private func plan(_ app: XCUIApplication, _ nom: String, onglet: Onglet?,
                      pose: TimeInterval, defilements: Int, prise: Bool = true) {
        if let onglet {
            app.coordinate(withNormalizedOffset: CGVector(dx: onglet.rawValue, dy: Self.barre)).tap()
            // Les transitions d'onglet de `RootTabView` durent moins d'une demi-seconde ; on
            // laisse une marge pour que le plan ne commence pas pendant le fondu.
            Thread.sleep(forTimeInterval: 0.6)
        }
        let debut = Date().timeIntervalSince1970
        Thread.sleep(forTimeInterval: pose)
        for _ in 0..<defilements {
            // LA VITESSE DU GESTE, TROISIÈME RÉGLAGE — ET C'EST LA MACHINE QUI A TRANCHÉ.
            //
            // `.slow` prenait près de deux secondes : le geste durait plus que le plan. `.default`
            // paraissait raisonnable en local ; sur la machine du harnais, il a donné des plans de
            // 3,4 s, et le film entier est monté à vingt-huit secondes — à deux du plafond
            // d'Apple, et bien au-delà du « un peu long » qu'on corrigeait.
            //
            // C'est le genre de durée qu'on ne peut pas estimer : elle dépend de la charge d'une
            // machine qu'on ne voit pas. `.fast` est un coup de pouce, ce que fait une vraie
            // personne pour descendre dans une page, et ça se lit à trente images par seconde.
            let depart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
            let arrivee = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
            depart.press(forDuration: 0.06, thenDragTo: arrivee,
                         withVelocity: .fast, thenHoldForDuration: 0.05)
            Thread.sleep(forTimeInterval: 0.8)
        }
        // Les étiquettes sont écrites : un tuple nu se convertit parfois en tuple étiqueté et
        // parfois non, selon le contexte, et ce genre d'implicite se paie à la compilation —
        // c'est-à-dire ici, quinze minutes plus tard.
        let borne = (nom: nom, debut: debut, fin: Date().timeIntervalSince1970,
                     bascule: onglet != nil)
        if prise { bornes.append(borne) } else { prechauffage.append(borne) }
    }

    private func ecrire(_ texte: String, sous nom: String) {
        guard let dossier = ProcessInfo.processInfo.environment["RUNUP_APERCU_DIR"] else { return }
        let url = URL(fileURLWithPath: dossier).appendingPathComponent(nom)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? texte.write(to: url, atomically: true, encoding: .utf8)
    }
}
