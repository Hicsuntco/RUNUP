import XCTest
@testable import RunUp

/// Ce que l'inscription annonce de ce qu'il lui reste à demander.
///
/// # POURQUOI CE TEST EXISTE
///
/// Les huit vidéos qui vendent l'app montrent TROIS écrans — « pourquoi tu cours ? », l'écran de
/// l'objectif, et le plan — et le bouton du troisième dit « BUILD MY PLAN ». Dans l'app, ce
/// bouton-là est le troisième de neuf : après lui viennent le point de départ, un mot sur toi,
/// les jours, le niveau et la montre. Ces cinq écrans sont exactement ceux qui rendent le plan
/// sur mesure — mais quelqu'un qui installe après avoir vu la vidéo croit avoir fini.
///
/// La phrase répare l'écart. Et son arithmétique dépend de trois bornes qu'une étape insérée au
/// milieu de l'inscription rend fausses sans rien casser — le genre de nombre recopié que
/// `check_etapes.py` traque déjà entre les trois `switch`.
final class ResteALireTests: XCTestCase {

    // MARK: - Où la phrase paraît, et où elle se tait

    func testRienAvantLEcranDeLObjectif() {
        // Dire « encore huit écrans » à quelqu'un qui n'a rien demandé, c'est décourager pour
        // rassurer. La phrase ne sert qu'à qui vient de croire qu'il avait fini.
        for etape in 0..<OnboardingViewModel.premierEcranAvecLeReste {
            XCTAssertNil(OnboardingViewModel.resteALire(apres: etape),
                         "l'écran \(etape) annonce ce qu'il reste alors qu'il est trop tôt")
        }
    }

    func testRienApresLaDerniereQuestion() {
        // L'écran de construction ne demande rien : il n'a pas de reste à annoncer.
        XCTAssertNil(OnboardingViewModel.resteALire(apres: OnboardingViewModel.totalSteps - 1))
    }

    func testLaPhraseParaitSurChaqueEcranEntreLesDeux() {
        for etape in OnboardingViewModel.premierEcranAvecLeReste...OnboardingViewModel.dernierEcranDeQuestions {
            XCTAssertNotNil(OnboardingViewModel.resteALire(apres: etape),
                            "l'écran \(etape) ne dit pas ce qu'il reste")
        }
    }

    // MARK: - Ce qu'elle dit

    func testLeDernierEcranSAnnonceCommeTel() {
        let phrase = OnboardingViewModel.resteALire(apres: OnboardingViewModel.dernierEcranDeQuestions)
        XCTAssertEqual(phrase, String(localized: "Dernier écran — ton plan arrive juste après."))
    }

    func testLAvantDernierParleAuSingulier() {
        // Le piège de toute cette famille de phrases : « Plus que 1 écrans ».
        let phrase = OnboardingViewModel.resteALire(apres: OnboardingViewModel.dernierEcranDeQuestions - 1)
        XCTAssertEqual(phrase, String(localized: "Plus qu'un écran, et ton plan est prêt."))
    }

    func testLePremierEcranConcerneCompteLesQuatreQuiRestent() {
        // Point de départ (4) : restent un mot sur toi, les jours, le niveau, la montre.
        let restants = OnboardingViewModel.dernierEcranDeQuestions
            - OnboardingViewModel.premierEcranAvecLeReste
        XCTAssertEqual(restants, 4, "l'inscription a changé de longueur — relis la phrase")
        let phrase = OnboardingViewModel.resteALire(apres: OnboardingViewModel.premierEcranAvecLeReste)
        XCTAssertEqual(phrase, String(localized: "Plus que \(restants) écrans, et ton plan est prêt."))
    }

    // MARK: - Les bornes elles-mêmes

    func testLesBornesDecriventBienNeufEcransDeQuestions() {
        // Si ça tombe en rouge, c'est qu'une étape a été ajoutée ou retirée : vérifie que la
        // dernière reste bien l'écran de construction, puis mets ce nombre à jour.
        XCTAssertEqual(OnboardingViewModel.totalEcransDeQuestions, 9)
        XCTAssertEqual(OnboardingViewModel.dernierEcranDeQuestions,
                       OnboardingViewModel.totalSteps - 2,
                       "le dernier écran de questions doit précéder celui de la construction")
    }

    // MARK: - Le duathlon, retiré de la liste et pas démonté

    func testLeDuathlonNEstPlusProposeALInscription() {
        // Retiré le 17 octobre 2026 : les vidéos vendent sept objectifs, il n'en fait pas partie.
        // `DuathlonTests` vérifie en face que tout ce qu'il faut pour le rouvrir tient debout.
        XCTAssertFalse(GoalType.allCases.filter(\.estProposable).contains(.duathlon))
        XCTAssertEqual(GoalType.allCases.filter(\.estProposable).count, 8)
    }
}
