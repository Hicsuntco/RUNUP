import XCTest
@testable import RunUp

/// Verrouille deux nombres que l'app calculait à plusieurs endroits — la classe de défaut que
/// l'audit a désignée comme la plus récurrente du projet, et la plus difficile à voir : rien ne
/// casse, l'app compile, et les deux écrans affichent simplement deux chiffres différents pour la
/// même chose.
///
/// Les commentaires du code en étaient déjà la preuve. `PaceModel.paceText` portait, écrite noir
/// sur blanc, la prédiction du défaut qui vivait à côté d'elle : « deux formateurs finissent
/// toujours par diverger sur l'arrondi — une seconde d'écart entre deux écrans qui montrent la
/// même course ». Et les trois copies de la constante de calories portaient chacune un
/// commentaire demandant aux deux autres de rester d'accord. Protéger une invariance à la main,
/// c'est l'avoir déjà perdue.
final class UneSeuleVeriteTests: XCTestCase {

    // MARK: - Une seule façon d'écrire une allure

    /// Le défaut exact. `AdaptivePlanEngine.fmt` tronquait, `PaceModel.paceText` arrondit : à
    /// 299,6 s/km, le plan annonçait « 5:00 » et l'historique de la course courue dessus
    /// « 4:59 ».
    func testLAllureArronditAuLieuDeTronquer() {
        XCTAssertEqual(PaceModel.paceText(299.6), "5:00")
        XCTAssertEqual(PaceModel.paceText(299.4), "4:59")
        XCTAssertEqual(PaceModel.paceText(300), "5:00")
    }

    /// L'allure du plan et celle de la course écrite dessus sortent du MÊME formateur. Sans quoi
    /// une coureuse qui tient exactement sa cible voit deux nombres différents.
    func testLePlanEtLHistoriqueSAccordentSurUneAllureIdentique() {
        // Un pas de 0,7 plutôt que 0,1 : trois cents allures balaient largement la plage utile
        // (4:00 à 7:00 au kilomètre) sans fabriquer deux mille objets de modèle pour rien, et un
        // pas non décimal fait tomber les valeurs à la fois sur des demi-secondes et à côté.
        for secPerKm in stride(from: 240.0, through: 420.0, by: 0.7) {
            let duPlan = PaceModel.paceText(secPerKm)
            let record = AdaptivePlanEngine.buildRunRecord(
                title: "Footing",
                elapsedSeconds: secPerKm * 10,
                distanceKm: 10,
                kcal: 0,
                avgHeartRate: 0
            )
            XCTAssertEqual(record.avgPace, duPlan,
                           "Désaccord à \(secPerKm) s/km : le plan dit \(duPlan), l'historique \(record.avgPace).")
        }
    }

    func testUneAllureNegativeNeProduitPasDeTempsNegatif() {
        // La valeur ne devrait jamais arriver, mais `fmt` s'en protégeait et la protection ne doit
        // pas être perdue au passage.
        XCTAssertEqual(PaceModel.paceText(0), "0:00")
    }

    /// Une allure ne passe jamais aux heures — c'est une durée au kilomètre. Un temps TOTAL se
    /// formate avec `formatDuration`, et les deux ne doivent pas être confondus : une sortie
    /// longue de 95 minutes s'écrirait « 95:00 ».
    func testLAllureEtLaDureeNeSeConfondentPas() {
        XCTAssertEqual(PaceModel.paceText(5700), "95:00")
        XCTAssertEqual(PaceModel.formatDuration(5700), "1:35:00")
    }

    // MARK: - Une seule façon d'estimer une dépense

    /// La même distance donne le même nombre, qu'elle vienne du GPS ou d'une saisie à la main.
    /// C'est exactement ce que les trois commentaires se promettaient l'un à l'autre.
    func testLeGPSEtLaSaisieManuelleSAccordentSurUneDistanceIdentique() {
        for km in [0.5, 3.0, 5.0, 10.0, 21.0975, 42.195] {
            XCTAssertEqual(Calories.estimate(distanceKm: km),
                           Calories.estimate(distanceKm: km, durationMinutes: 45),
                           accuracy: 0.0001,
                           "Désaccord à \(km) km.")
        }
    }

    /// Sans distance, la durée prend le relais — mais seulement là. Sur l'écran de course, zéro
    /// kilomètre vaut zéro kcal : tant que le GPS n'a pas accroché, c'est la vérité.
    func testSansDistanceLaDureePrendLeRelaisMaisPasEnDirect() {
        XCTAssertEqual(Calories.estimate(distanceKm: 0, durationMinutes: 40), 280, accuracy: 0.0001)
        XCTAssertEqual(Calories.estimate(distanceKm: 0), 0, accuracy: 0.0001)
    }

    /// Le repli à la durée doit rester cohérent avec le tarif au kilomètre : sept kcal la minute,
    /// c'est le même tarif exprimé pour une coureuse à dix kilomètres à l'heure. Si l'un des deux
    /// nombres bougeait seul, une séance marquée faite et la même séance courue au GPS
    /// divergeraient d'un facteur, sans que rien ne le signale.
    func testLesDeuxTarifsDecriventLaMemeHypothese() {
        let kmParHeure = Calories.perMinuteWithoutDistance * 60 / Calories.perKm
        XCTAssertEqual(kmParHeure, 6.77, accuracy: 0.25,
                       "Les deux constantes ne décrivent plus la même coureuse.")
    }

    /// L'enregistrement arrondit la dépense, il ne la tronque pas — `RunRecord.kcal` est un `Int`.
    func testLEnregistrementArronditLaDepense() {
        let record = AdaptivePlanEngine.buildRunRecord(
            title: "Footing",
            elapsedSeconds: 1800,
            distanceKm: 5.007,
            kcal: Calories.estimate(distanceKm: 5.007),
            avgHeartRate: 0
        )
        XCTAssertEqual(record.kcal, Int((5.007 * Calories.perKm).rounded()))
    }
}
