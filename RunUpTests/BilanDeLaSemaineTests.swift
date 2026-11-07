import XCTest
@testable import RunUp

/// Verrouille les cinq définitions de « la semaine » que l'écran de bilan portait, et qui se
/// contredisaient deux à deux.
///
/// Elles vivaient dans des propriétés privées d'une vue SwiftUI : rien ne les vérifiait, et rien
/// ne pouvait les vérifier. Ce fichier existe parce que `BilanDeLaSemaine` les a sorties de là.
///
/// La règle que chaque cas applique : **les kilomètres ne s'additionnent pas entre disciplines, le
/// temps si.** Vingt kilomètres à vélo ne sont pas vingt kilomètres en courant ; une heure est une
/// heure.
final class BilanDeLaSemaineTests: XCTestCase {

    private var calendrier: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    /// Le lundi de la semaine en cours — le même que celui du moteur.
    private var lundi: Date {
        calendrier.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private var semaine: Range<Date> { AdaptivePlanEngine.currentWeekRange() }

    /// Une séance, posée sur un jour de la semaine en cours ou sur un nombre de jours en arrière.
    private func seance(_ discipline: Discipline, km: Double, secParKm: Double,
                        jourDeLaSemaine: Int? = nil, ilYANJours: Int? = nil) -> RunRecord {
        let date: Date
        if let jourDeLaSemaine {
            // Midi, pour qu'aucun décalage d'heure ne fasse glisser la séance d'un jour.
            let jour = calendrier.date(byAdding: .day, value: jourDeLaSemaine, to: lundi) ?? lundi
            date = calendrier.date(bySettingHour: 12, minute: 0, second: 0, of: jour) ?? jour
        } else {
            date = calendrier.date(byAdding: .day, value: -(ilYANJours ?? 30), to: Date()) ?? Date()
        }
        return RunRecord(
            date: date,
            title: "Séance",
            distanceKm: km,
            durationSeconds: Int(km * secParKm),
            avgPace: PaceModel.paceText(secParKm),
            avgHeartRate: 0,
            kcal: 0,
            elevationGainM: 0,
            discipline: discipline
        )
    }

    // MARK: - Le défaut le plus grave : un record d'allure venu du vélo

    /// UNE SORTIE À VÉLO NE BAT PAS UN RECORD D'ALLURE DE COURSE.
    ///
    /// `avgPace` est stocké en secondes au kilomètre pour TOUTES les disciplines. Une sortie à
    /// 20 km/h vaut donc 180 s/km, ce qui bat n'importe quelle allure de course à pied. L'écran
    /// annonçait « Nouveau record d'allure · 3:00/km sur 20,0 km » après une sortie à vélo : un
    /// record de course inventé par une discipline qui n'en est pas une.
    func testUneSortieAVeloNeBatPasUnRecordDAllureDeCourse() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 10, secParKm: 300, ilYANJours: 30),   // 5:00/km, le record d'avant
            seance(.bike, km: 20, secParKm: 180, jourDeLaSemaine: 1),  // 20 km/h cette semaine
        ], semaine: semaine)
        XCTAssertNil(bilan.record, "le vélo a produit un record d'allure de course")
    }

    /// Et une vraie course plus rapide le bat, elle.
    func testUneCoursePlusRapideBatLeRecordDAllure() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 10, secParKm: 300, ilYANJours: 30),
            seance(.run, km: 8, secParKm: 282, jourDeLaSemaine: 2),   // 4:42/km
        ], semaine: semaine)
        guard case .allure(let secParKm, let km)? = bilan.record else {
            return XCTFail("aucun record alors que l'allure a progressé : \(String(describing: bilan.record))")
        }
        XCTAssertEqual(secParKm, 282, accuracy: 1)
        XCTAssertEqual(km, 8, accuracy: 0.01)
    }

    // MARK: - Le graphique et le total racontent la même semaine

    /// La somme des barres est EXACTEMENT le total affiché au-dessus.
    ///
    /// « Parcourus » comptait à pied, « Volume par jour (km) » comptait tout : la somme des barres
    /// pouvait dépasser le total, sur le même écran.
    func testLaSommeDesBarresEstLeTotalAffiche() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 8.1, secParKm: 318, jourDeLaSemaine: 0),
            seance(.trail, km: 12.0, secParKm: 360, jourDeLaSemaine: 3),
            seance(.bike, km: 45.0, secParKm: 120, jourDeLaSemaine: 4),
            seance(.swim, km: 1.5, secParKm: 1500, jourDeLaSemaine: 5),
        ], semaine: semaine)
        XCTAssertEqual(bilan.kilometresParJour.reduce(0, +), bilan.kilometres, accuracy: 0.0001)
        // Et ce total est bien celui des deux séances à pied, pas des quatre.
        XCTAssertEqual(bilan.kilometres, 20.1, accuracy: 0.0001)
    }

    // MARK: - Les kilomètres ne s'additionnent pas, le temps si

    func testLeTempsCompteToutesLesDisciplinesEtLesKilometresNon() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 10, secParKm: 300, jourDeLaSemaine: 0),   // 50 min
            seance(.bike, km: 30, secParKm: 120, jourDeLaSemaine: 2),  // 60 min
        ], semaine: semaine)
        XCTAssertEqual(bilan.kilometres, 10, accuracy: 0.0001, "le vélo est entré dans les kilomètres")
        XCTAssertEqual(bilan.secondesActives, 3000 + 3600, "le vélo n'est pas entré dans le temps actif")
        XCTAssertEqual(bilan.nombreDeSeances, 2, "une séance est une séance")
    }

    // MARK: - « Ta meilleure semaine »

    /// LE TITRE NE DOIT PAS DÉPENDRE DU VÉLO D'UNE AUTRE SEMAINE.
    ///
    /// Il comparait les kilomètres à pied de cette semaine à la somme TOUTES DISCIPLINES des
    /// autres : une semaine de soixante kilomètres de vélo battait une semaine de course, et le
    /// titre ne paraissait jamais chez quelqu'un qui roule.
    func testLeTitreDeMeilleureSemaineIgnoreLeVeloDesAutresSemaines() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.bike, km: 120, secParKm: 110, ilYANJours: 20),   // une grosse semaine de vélo
            seance(.run, km: 15, secParKm: 310, ilYANJours: 20),     // 15 km à pied cette semaine-là
            seance(.run, km: 18, secParKm: 310, jourDeLaSemaine: 1), // 18 km à pied cette semaine
        ], semaine: semaine)
        XCTAssertTrue(bilan.estLaMeilleureSemaine,
                      "120 km de vélo d'une autre semaine ont empêché le titre")
    }

    /// Et une semaine à pied vraiment plus faible ne le prend pas.
    func testUneSemaineMoinsFournieNEstPasLaMeilleure() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 40, secParKm: 310, ilYANJours: 20),
            seance(.run, km: 18, secParKm: 310, jourDeLaSemaine: 1),
        ], semaine: semaine)
        XCTAssertFalse(bilan.estLaMeilleureSemaine)
    }

    /// Une semaine vide n'est pas la meilleure, même quand c'est la seule.
    func testUneSemaineVideNEstPasLaMeilleure() {
        XCTAssertFalse(BilanDeLaSemaine(historique: [], semaine: semaine).estLaMeilleureSemaine)
    }

    // MARK: - L'allure moyenne

    /// Elle ne moyenne QUE la course sur route : une allure de vélo ou de bassin y entrerait
    /// comme un nombre de secondes au kilomètre, sans aucun sens.
    func testLAllureMoyenneNeMoyenneQueLaCourseSurRoute() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 10, secParKm: 300, jourDeLaSemaine: 0),
            seance(.run, km: 10, secParKm: 320, jourDeLaSemaine: 2),
            seance(.bike, km: 30, secParKm: 120, jourDeLaSemaine: 3),
        ], semaine: semaine)
        XCTAssertEqual(bilan.allureMoyenneSecParKm ?? 0, 310, accuracy: 1)
    }

    func testPasDeCourseAPiedPasDAllureMoyenne() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.bike, km: 30, secParKm: 120, jourDeLaSemaine: 3),
        ], semaine: semaine)
        XCTAssertNil(bilan.allureMoyenneSecParKm)
    }

    // MARK: - Un record de distance

    func testUnRecordDeDistanceCompteLeTrailCommeLaRoute() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 15, secParKm: 310, ilYANJours: 30),
            seance(.trail, km: 22, secParKm: 400, jourDeLaSemaine: 5),
        ], semaine: semaine)
        guard case .distance(let km)? = bilan.record else {
            return XCTFail("le trail n'a pas compté comme une distance à pied")
        }
        XCTAssertEqual(km, 22, accuracy: 0.01)
    }

    /// Rien de battu, rien d'annoncé. Un record fabriqué vaut moins que pas de record.
    func testAucunRecordQuandRienNEstBattu() {
        let bilan = BilanDeLaSemaine(historique: [
            seance(.run, km: 20, secParKm: 280, ilYANJours: 30),
            seance(.run, km: 8, secParKm: 330, jourDeLaSemaine: 1),
        ], semaine: semaine)
        XCTAssertNil(bilan.record)
    }
}
