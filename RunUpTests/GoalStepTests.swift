import XCTest
@testable import RunUp

/// L'étape qui suit le choix de l'objectif appartient à cet objectif.
///
/// # LE DÉFAUT QUE CES TESTS EMPÊCHENT DE REVENIR
///
/// Trois objectifs sur sept avaient leur propre écran d'étape 3 — surtitre, question, promesse.
/// Les quatre autres partageaient un seul en-tête générique : « Étape 3 · sur mesure », et le
/// sous-titre « Plus on en sait, plus le plan colle à ta réalité », une phrase vraie de
/// n'importe quelle question de n'importe quelle app.
///
/// L'étape 3 est la première chose qu'on voit APRÈS avoir dit ce qu'on veut. C'est elle qui
/// répond « j'ai compris », et elle répondait « sur mesure » à quelqu'un qui venait de choisir
/// « reprendre sans se blesser ». Rien ne cassait, et c'est bien le problème : un en-tête
/// générique ne lève aucune alerte, il déçoit juste un peu, huit fois sur huit.
final class GoalStepTests: XCTestCase {

    /// Chaque objectif a son en-tête complet — aucun ne retombe sur le vide.
    func testChaqueObjectifAUnEnTeteComplet() {
        for objectif in GoalType.allCases {
            XCTAssertFalse(objectif.etapeEyebrow.isEmpty, "\(objectif) : pas de surtitre")
            XCTAssertFalse(objectif.etapeTitre.isEmpty, "\(objectif) : pas de titre")
            XCTAssertFalse(objectif.etapePromesse.isEmpty, "\(objectif) : pas de promesse")
        }
    }

    /// ET AUCUN NE PARTAGE SA PROMESSE AVEC UN AUTRE.
    ///
    /// C'est le test qui porte tout le correctif. Quatre objectifs partageaient exactement la
    /// même phrase, et aucune assertion de non-vide ne l'aurait dit — les quatre étaient bien
    /// remplies. Seule l'unicité le voit.
    func testAucunObjectifNePartageSaPromesseAvecUnAutre() {
        let promesses = GoalType.allCases.map(\.etapePromesse)
        XCTAssertEqual(Set(promesses).count, promesses.count,
                       "deux objectifs annoncent la même chose : \(promesses)")
        let surtitres = GoalType.allCases.map(\.etapeEyebrow)
        XCTAssertEqual(Set(surtitres).count, surtitres.count, "deux surtitres identiques")
        let titres = GoalType.allCases.map(\.etapeTitre)
        XCTAssertEqual(Set(titres).count, titres.count, "deux titres identiques")
    }

    /// La promesse dit ce que le plan FERA, pas ce que l'app est.
    ///
    /// Un test de forme et non de goût : une promesse est une phrase, donc elle se termine. Le
    /// critère attrape le retour du « sur mesure » — un bout de phrase nominale qui décrit
    /// l'app au lieu de répondre à la personne.
    func testChaquePromesseEstUnePhrase() {
        for objectif in GoalType.allCases {
            let p = objectif.etapePromesse
            XCTAssertGreaterThan(p.count, 25, "\(objectif) : promesse trop courte pour en être une")
            XCTAssertTrue(p.hasSuffix(".") || p.hasSuffix("?"), "\(objectif) : « \(p) »")
        }
    }

    /// Le surtitre nomme l'étape ET l'objectif, pour qu'on sache où on en est.
    func testChaqueSurtitreNommeLEtape() {
        for objectif in GoalType.allCases {
            XCTAssertTrue(objectif.etapeEyebrow.contains("3"),
                          "\(objectif) : « \(objectif.etapeEyebrow) » ne dit pas l'étape")
        }
    }

    /// LA TAILLE N'EST PLUS EXIGÉE POUR AVANCER.
    ///
    /// Elle bloquait l'étape au même titre que les deux poids, alors qu'elle n'enrichit qu'une
    /// phrase du contexte envoyé au coach — lequel sait déjà écrire « ? » quand elle manque.
    /// Exiger une troisième mesure corporelle pour avancer, sur l'objectif dont l'étape est
    /// déjà la plus intime, était de la friction sans contrepartie.
    @MainActor
    func testLaTailleNEstPlusExigeePourAvancer() {
        let vm = OnboardingViewModel()
        vm.goal = .weight
        vm.weightNow = "72"
        vm.weightTarget = "66"
        vm.height = ""
        XCTAssertTrue(vm.canProceed(fromStep: 3), "la taille bloque encore l'étape")
        // Les deux poids, eux, restent nécessaires : c'est d'eux que l'objectif est fait.
        vm.weightTarget = ""
        XCTAssertFalse(vm.canProceed(fromStep: 3), "le poids visé ne bloque plus")
    }

    /// Un ultra exige toujours son dénivelé — et c'est maintenant DIT à l'écran.
    ///
    /// Le champ bloquait « Continuer » sans un mot : le bouton restait gris au milieu d'un écran
    /// dont tout le reste était rempli. La pastille « requis » répare l'écran ; ce test garde la
    /// règle qu'elle annonce.
    @MainActor
    func testUnUltraExigeToujoursSonDenivele() {
        let vm = OnboardingViewModel()
        vm.goal = .ultraTrail
        vm.distance = .ultra80
        vm.chrono = "12:00"
        vm.raceDate = Calendar.current.date(byAdding: .day, value: 90, to: .now)
        vm.raceElevationGain = ""
        XCTAssertFalse(vm.canProceed(fromStep: 3), "l'ultra passe sans dénivelé")
        vm.raceElevationGain = "4200"
        XCTAssertTrue(vm.canProceed(fromStep: 3), "l'ultra bloque avec son dénivelé")
        XCTAssertEqual(vm.raceElevationGainM, 4200)
    }
}
