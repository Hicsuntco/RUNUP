import XCTest
@testable import RunUp

/// Les cas de « pourquoi cette séance, aujourd'hui ».
///
/// # LA CONDITION QUE CE BANC DOIT TENIR
///
/// `PHASE2.md` la pose en toutes lettres : « à condition que la phrase vienne du moteur et pas
/// d'un catalogue de phrases. Sinon c'est un texte générique, donc un défaut. »
///
/// Un banc qui vérifierait seulement « il y a une phrase » laisserait passer le catalogue. Ces
/// cas vérifient donc l'inverse : **que la phrase change quand le plan change**, et qu'elle se
/// TAIT quand le moteur n'a rien de chiffré à dire.
final class PourquoiCetteSeanceTests: XCTestCase {

    private func contexte(bloc: AdaptivePlanEngine.TrainingBlock = .base,
                          semaine: Int = 3,
                          total: Int? = 14,
                          jours: Int? = nil,
                          dejaExplique: Bool = false,
                          repos: Bool = false) -> PourquoiCetteSeance.Contexte {
        .init(bloc: bloc, semaine: semaine, semainesEnTout: total,
              joursAvantLaCourse: jours, dejaExplique: dejaExplique, estUnJourDeRepos: repos)
    }

    // MARK: Ce qui doit se taire

    /// LE CAS LE PLUS IMPORTANT. Le moteur a allégé la séance : « Allégée · nuit courte » est une
    /// raison plus précise que n'importe quelle phrase de bloc. Deux explications empilées sur la
    /// même carte, c'est une de trop.
    func testUneSeanceDejaExpliqueeNeReçoitPasUneDeuxiemeRaison() {
        for bloc in [AdaptivePlanEngine.TrainingBlock.base, .specifique, .affutage, .deload] {
            XCTAssertNil(PourquoiCetteSeance.phrase(
                contexte(bloc: bloc, jours: 10, dejaExplique: true)), "\(bloc)")
        }
    }

    func testUnJourDeReposNeReçoitAucunePhrase() {
        for bloc in [AdaptivePlanEngine.TrainingBlock.base, .specifique, .affutage, .deload] {
            XCTAssertNil(PourquoiCetteSeance.phrase(contexte(bloc: bloc, jours: 10, repos: true)))
        }
    }

    /// SANS NOMBRE, ON SE TAIT. Un programme ouvert — « rester en forme » — n'a pas de total de
    /// semaines : la phrase de bloc deviendrait « on construit le volume », c'est-à-dire
    /// exactement le texte générique que l'item interdit.
    func testSansTotalDeSemainesLesBlocsDeConstructionSeTaisent() {
        XCTAssertNil(PourquoiCetteSeance.phrase(contexte(bloc: .base, total: nil)))
        XCTAssertNil(PourquoiCetteSeance.phrase(contexte(bloc: .specifique, total: nil)))
    }

    /// L'affûtage ne se comprend que par rapport à une date. Sans course, ou course passée, il
    /// n'y a pas de « J-X » à dire, donc rien à dire.
    func testLAffutageSansDateOuApresLaCourseSeTait() {
        XCTAssertNil(PourquoiCetteSeance.phrase(contexte(bloc: .affutage, jours: nil)))
        XCTAssertNil(PourquoiCetteSeance.phrase(contexte(bloc: .affutage, jours: 0)))
        XCTAssertNil(PourquoiCetteSeance.phrase(contexte(bloc: .affutage, jours: -3)))
    }

    // MARK: Ce qui doit parler, et avec un nombre de CE plan

    /// UN TEST N'AFFIRME RIEN SUR UNE TRADUCTION, ET CELUI-CI L'A APPRIS EN ÉCHOUANT.
    ///
    /// Sa première version vérifiait que la phrase contient « quatre », pour garder la règle
    /// « une semaine sur quatre ». La machine d'intégration lance les tests en ANGLAIS : elle a
    /// reçu « one week in four », et le cas est tombé. Il n'éprouvait pas le moteur, il éprouvait
    /// la langue du simulateur.
    ///
    /// Ce qui se vérifie sans dépendre d'une langue, c'est le NOMBRE — il est le même dans les
    /// trois. Que la phrase dise quelque chose de spécifique au bloc est tenu par
    /// `testLesQuatreBlocsDisentQuatreChosesDifferentes`, et qu'elle dépende du plan par
    /// `testLaPhraseChangeAvecLaSemaine`. La formulation, elle, se relit ; elle ne s'assert pas.
    func testLaDechargeDitLeNumeroDeSemaine() throws {
        let p = try XCTUnwrap(PourquoiCetteSeance.phrase(contexte(bloc: .deload, semaine: 8)))
        XCTAssertTrue(p.contains("8"), p)
    }

    func testLAffutageDitLesJoursQuiRestent() throws {
        let p = try XCTUnwrap(PourquoiCetteSeance.phrase(contexte(bloc: .affutage, jours: 12)))
        XCTAssertTrue(p.contains("12"), p)
    }

    func testLesBlocsDeConstructionDisentOuOnEnEst() throws {
        let base = try XCTUnwrap(PourquoiCetteSeance.phrase(
            contexte(bloc: .base, semaine: 2, total: 14)))
        XCTAssertTrue(base.contains("2") && base.contains("14"), base)
        let spec = try XCTUnwrap(PourquoiCetteSeance.phrase(
            contexte(bloc: .specifique, semaine: 9, total: 14)))
        XCTAssertTrue(spec.contains("9") && spec.contains("14"), spec)
    }

    // MARK: Et ce qui sépare une phrase d'un catalogue

    /// DEUX COUREUSES DANS LE MÊME BLOC NE LISENT PAS LA MÊME PHRASE.
    ///
    /// C'est toute la différence avec un catalogue : si cette assertion tombe, c'est qu'une
    /// phrase a perdu son nombre et qu'elle s'est mise à décrire le bloc au lieu du plan.
    func testLaPhraseChangeAvecLaSemaine() {
        for bloc in [AdaptivePlanEngine.TrainingBlock.base, .specifique] {
            let a = PourquoiCetteSeance.phrase(contexte(bloc: bloc, semaine: 2, total: 14))
            let b = PourquoiCetteSeance.phrase(contexte(bloc: bloc, semaine: 9, total: 14))
            XCTAssertNotNil(a)
            XCTAssertNotEqual(a, b, "\(bloc) rend la même phrase en semaine 2 et en semaine 9")
        }
        let j5 = PourquoiCetteSeance.phrase(contexte(bloc: .affutage, jours: 5))
        let j15 = PourquoiCetteSeance.phrase(contexte(bloc: .affutage, jours: 15))
        XCTAssertNotEqual(j5, j15)
        let s4 = PourquoiCetteSeance.phrase(contexte(bloc: .deload, semaine: 4))
        let s12 = PourquoiCetteSeance.phrase(contexte(bloc: .deload, semaine: 12))
        XCTAssertNotEqual(s4, s12)
    }

    /// Les quatre blocs ne se confondent pas : si deux rendaient la même chose, l'un des deux
    /// n'expliquerait rien.
    func testLesQuatreBlocsDisentQuatreChosesDifferentes() {
        let phrases = [
            PourquoiCetteSeance.phrase(contexte(bloc: .base, semaine: 3, total: 14)),
            PourquoiCetteSeance.phrase(contexte(bloc: .specifique, semaine: 3, total: 14)),
            PourquoiCetteSeance.phrase(contexte(bloc: .affutage, semaine: 3, jours: 9)),
            PourquoiCetteSeance.phrase(contexte(bloc: .deload, semaine: 3, total: 14)),
        ].compactMap { $0 }
        XCTAssertEqual(phrases.count, 4)
        XCTAssertEqual(Set(phrases).count, 4, "deux blocs rendent la même phrase")
    }
}
