import XCTest
@testable import RunUp

/// Les trois choses qui décident d'un ultra et dont aucune n'est l'entraînement.
///
/// Les fourchettes de `UltraRaceDay` sont des références de pratique, pas des résultats de calcul :
/// les tester reviendrait à recopier les constantes. Ce qui se teste, c'est ce que le fichier
/// CALCULE à partir d'elles — des totaux, un nombre de prises, un verdict sur la nuit — et les
/// invariants sans lesquels l'écran afficherait une absurdité : une fourchette inversée, un total
/// négatif, ou « 0 g de glucides » présenté comme une réponse.
final class UltraRaceDayTests: XCTestCase {

    private let quinzeHeures: Double = 15 * 3600

    // MARK: Les fourchettes elles-mêmes

    /// Une fourchette inversée s'afficherait telle quelle : « 90-60 g de glucides ». Personne ne
    /// relit trois constantes, et l'écran ne les relit pas non plus.
    func testLesTroisFourchettesSontDansLeBonSens() {
        XCTAssertLessThan(UltraRaceDay.glucidesParHeureMin, UltraRaceDay.glucidesParHeureMax)
        XCTAssertLessThan(UltraRaceDay.eauParHeureMinML, UltraRaceDay.eauParHeureMaxML)
        XCTAssertLessThan(UltraRaceDay.sodiumParHeureMinMG, UltraRaceDay.sodiumParHeureMaxMG)
    }

    // MARK: Les totaux

    /// Le total est le produit de la fourchette par la durée, et c'est le nombre qui fait
    /// comprendre qu'un ultra se prépare aussi en faisant les courses.
    func testLeTotalDeGlucidesSuitLaDuree() {
        let g = UltraRaceDay.glucidesTotaux(tempsDeffortSecondes: quinzeHeures)
        XCTAssertEqual(g.bas, 15 * UltraRaceDay.glucidesParHeureMin)
        XCTAssertEqual(g.haut, 15 * UltraRaceDay.glucidesParHeureMax)
        XCTAssertLessThan(g.bas, g.haut)

        // Et il double quand la durée double — l'évidence que seule une régression casse.
        let double = UltraRaceDay.glucidesTotaux(tempsDeffortSecondes: 2 * quinzeHeures)
        XCTAssertEqual(double.bas, 2 * g.bas)
    }

    /// Une prise toutes les trente minutes : quinze heures en font trente. C'est aussi le nombre
    /// qui dit combien de gels acheter, donc il doit être juste et pas « environ ».
    func testLeNombreDePrisesSuitLIntervalle() {
        XCTAssertEqual(UltraRaceDay.nombreDePrises(tempsDeffortSecondes: quinzeHeures), 30)
        XCTAssertEqual(UltraRaceDay.nombreDePrises(tempsDeffortSecondes: 4 * 3600), 8)
        // Jamais zéro : une course très courte demande quand même de manger une fois.
        XCTAssertEqual(UltraRaceDay.nombreDePrises(tempsDeffortSecondes: 0), 1)
    }

    /// Arrondis au demi-litre : « 6,3 litres » serait une précision que personne ne remplit, et
    /// un bidon se compte par demi-litre.
    func testLesLitresSontArrondisAuDemiLitre() {
        let l = UltraRaceDay.litresTotaux(tempsDeffortSecondes: quinzeHeures)
        XCTAssertLessThan(l.bas, l.haut)
        for valeur in [l.bas, l.haut] {
            XCTAssertEqual(valeur * 2, (valeur * 2).rounded(), "\(valeur) n'est pas un multiple de 0,5")
        }
        // 15 h × 400 ml = 6 l, 15 h × 600 ml = 9 l.
        XCTAssertEqual(l.bas, 6.0, accuracy: 0.01)
        XCTAssertEqual(l.haut, 9.0, accuracy: 0.01)
    }

    // MARK: La nuit

    /// On ne connaît pas l'heure de départ — aucune app ne la connaît avant que le dossard
    /// n'existe — donc le verdict se tire de la DURÉE, et les deux seuils doivent être ordonnés.
    func testLeVerdictDeLaNuitSuitLesDeuxSeuils() {
        XCTAssertLessThan(UltraRaceDay.seuilNuitPossibleSecondes, UltraRaceDay.seuilNuitCertaineSecondes)

        XCTAssertEqual(UltraRaceDay.nuit(tempsDeffortSecondes: 4 * 3600), UltraRaceDay.Nuit.aucune)
        XCTAssertEqual(UltraRaceDay.nuit(tempsDeffortSecondes: 6 * 3600), UltraRaceDay.Nuit.possible)
        XCTAssertEqual(UltraRaceDay.nuit(tempsDeffortSecondes: 8 * 3600), UltraRaceDay.Nuit.possible)
        XCTAssertEqual(UltraRaceDay.nuit(tempsDeffortSecondes: 10 * 3600), UltraRaceDay.Nuit.certaine)
        XCTAssertEqual(UltraRaceDay.nuit(tempsDeffortSecondes: 30 * 3600), UltraRaceDay.Nuit.certaine)
    }

    /// Deux frontales dès que la nuit est possible : la plupart des grands trails l'exigent au
    /// contrôle du sac, et une frontale qui s'éteint en descente technique arrête la course.
    func testDeuxFrontalesDesQueLaNuitEstPossible() {
        XCTAssertEqual(UltraRaceDay.frontales(tempsDeffortSecondes: 4 * 3600), 0)
        XCTAssertEqual(UltraRaceDay.frontales(tempsDeffortSecondes: 6 * 3600), 2)
        XCTAssertEqual(UltraRaceDay.frontales(tempsDeffortSecondes: 20 * 3600), 2)
    }

    // MARK: Les entrées absurdes

    /// Le temps d'effort vaut zéro quand la course ne déclare ni distance ni dénivelé. L'écran
    /// tait alors ses totaux, mais le modèle ne doit en aucun cas rendre un nombre négatif — qui
    /// s'afficherait, lui, comme « -1 200 g de glucides ».
    func testUneEntreeNulleOuNegativeNeProduitRienDeNegatif() {
        for entree in [0.0, -1.0, -100000.0] {
            XCTAssertEqual(UltraRaceDay.heures(entree), 0)
            let g = UltraRaceDay.glucidesTotaux(tempsDeffortSecondes: entree)
            XCTAssertEqual(g.bas, 0)
            XCTAssertEqual(g.haut, 0)
            let l = UltraRaceDay.litresTotaux(tempsDeffortSecondes: entree)
            XCTAssertEqual(l.bas, 0)
            XCTAssertEqual(l.haut, 0)
            XCTAssertEqual(UltraRaceDay.nuit(tempsDeffortSecondes: entree), UltraRaceDay.Nuit.aucune)
            XCTAssertEqual(UltraRaceDay.frontales(tempsDeffortSecondes: entree), 0)
        }
    }

    // MARK: Le raccord avec le modèle d'effort

    /// Et le tout branché sur une vraie course : un 100 km avec 6 000 m de D+, à l'allure de
    /// footing d'une coureuse ordinaire. Les nombres doivent rester dans ce qu'un sac transporte
    /// et ce qu'un estomac encaisse — sinon l'écran prescrit l'impossible, qui est la façon la
    /// plus sûre de faire refermer un écran.
    func testSurUnCentKilometresLesNombresRestentPlausibles() {
        let effort = UltraTrail.tempsDeffortSecondes(km: 100, denivelePositifM: 6000,
                                                     allureFacileSecParKm: 342)
        XCTAssertEqual(UltraRaceDay.nuit(tempsDeffortSecondes: effort), UltraRaceDay.Nuit.certaine,
                       "Un 100 km de montagne se finit de nuit")

        let g = UltraRaceDay.glucidesTotaux(tempsDeffortSecondes: effort)
        XCTAssertGreaterThan(g.bas, 700, "Moins de 700 g sur un 100 km, c'est sous-alimenté")
        XCTAssertLessThan(g.haut, 1800, "Plus de 1,8 kg de glucides, personne ne le porte ni ne le digère")

        let l = UltraRaceDay.litresTotaux(tempsDeffortSecondes: effort)
        XCTAssertGreaterThan(l.bas, 4, "Moins de quatre litres sur quinze heures d'effort")
        XCTAssertLessThan(l.haut, 16, "Au-delà, ce n'est plus une course mais un déménagement")

        let prises = UltraRaceDay.nombreDePrises(tempsDeffortSecondes: effort)
        XCTAssertGreaterThan(prises, 20)
        XCTAssertLessThan(prises, 60)
    }
}
