import XCTest
@testable import RunUp

/// Verrouille quelles semaines le plan baisse LUI-MÊME.
///
/// L'écart hebdomadaire négatif s'affichait en ambre, la couleur d'attention du système — y
/// compris les semaines où l'app venait de prescrire la baisse. Le fil des phases l'annonce
/// pourtant mot pour mot : « en gris, les semaines de décharge : le volume baisse exprès, c'est là
/// que les progrès se fixent ».
///
/// Charlotte a tranché le 13 novembre : l'ambre ne sort que si la baisse n'était pas prévue.
final class BaisseProgrammeeTests: XCTestCase {

    /// Un programme sans date de course : le cycle ouvert, qui décharge toutes les 4 semaines.
    ///
    /// `.progress` et non un objectif écrit au hasard : c'est `periodiseVersUneDate` qui décide de
    /// la branche, et il est faux pour les quatre objectifs sans date. Le cas suivant vérifie que
    /// celui-ci en est bien un, pour qu'un reclassement futur fasse tomber le test plutôt que de
    /// lui faire mesurer silencieusement l'autre branche.
    private var cycleOuvert: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: .progress, raceDate: nil, from: .now)
    }

    func testLObjectifDeReferenceEstBienSansDate() {
        XCTAssertFalse(GoalType.progress.periodiseVersUneDate)
        XCTAssertNil(cycleOuvert.totalWeeks, "le cycle ouvert n'a pas de nombre de semaines")
    }

    func testLeCycleOuvertDechargeUneSemaineSurQuatre() {
        for semaine in 1...12 {
            let baisse = AdaptivePlanEngine.baisseProgrammee(forWeek: semaine, shape: cycleOuvert)
            XCTAssertEqual(baisse, semaine % 4 == 0,
                           "semaine \(semaine) : le cycle ouvert décharge tous les quatre")
        }
    }

    func testUneSemaineDeChargeNEstPasUneBaisse() {
        for semaine in [1, 2, 3, 5, 6, 7] {
            XCTAssertFalse(AdaptivePlanEngine.baisseProgrammee(forWeek: semaine, shape: cycleOuvert))
        }
    }

    func testLesDeuxBlocsQuiBaissentSontDecharteEtAffutage() {
        // La règle est écrite sur le BLOC, pas sur le numéro de semaine : si un troisième bloc
        // venait à délester, il devrait être ajouté ici explicitement plutôt que de passer.
        let baissent: [AdaptivePlanEngine.TrainingBlock] = [.deload, .affutage]
        let chargent: [AdaptivePlanEngine.TrainingBlock] = [.base, .specifique]
        XCTAssertEqual(Set(baissent).intersection(Set(chargent)), [],
                       "un bloc ne peut pas à la fois charger et délester")
        XCTAssertEqual(baissent.count + chargent.count, 4,
                       "les quatre blocs doivent être classés — un bloc oublié prendrait "
                       + "silencieusement le comportement par défaut")
    }

    func testLaCouleurDeLEcartSuitLaBaisseEtPasLeSigne() {
        // Le composant décide : un écart négatif N'EST PAS une alerte quand le plan l'a prévu.
        // Ce cas tient la règle côté modèle ; la couleur elle-même est vérifiée à l'œil sur les
        // captures, puisqu'une couleur ne se teste pas sans rendu.
        let dechargee = AdaptivePlanEngine.baisseProgrammee(forWeek: 4, shape: cycleOuvert)
        let chargee = AdaptivePlanEngine.baisseProgrammee(forWeek: 3, shape: cycleOuvert)
        XCTAssertTrue(dechargee)
        XCTAssertFalse(chargee)
    }
}
