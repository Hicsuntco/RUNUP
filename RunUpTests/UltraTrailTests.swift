import XCTest
@testable import RunUp

/// Le modèle d'effort qui remplace le kilomètre quand on prépare un ultra.
///
/// Tout le moteur de plan raisonne en kilomètres à allure de route. Appliqué à un 80 km avec
/// 4 000 m de dénivelé, il prescrirait une sortie longue de 30 km « à trois heures » là où ces
/// trente kilomètres en prennent cinq en montagne. Ces tests tiennent la seule mesure qui compte
/// en ultra — le temps passé debout — et les bornes qui empêchent un plan d'être absurde.
final class UltraTrailTests: XCTestCase {

    /// L'allure de footing d'une coureuse ordinaire, en secondes par kilomètre.
    private let allureFacile: Double = 360   // 6:00/km

    private func effort(_ km: Double, _ dplus: Double) -> Double {
        UltraTrail.tempsDeffortSecondes(km: km, denivelePositifM: dplus,
                                        allureFacileSecParKm: allureFacile)
    }

    // MARK: - Le kilomètre-effort

    func testCentMetresDeDenivelePesentUnKilometre() {
        XCTAssertEqual(UltraTrail.kilometresEffort(km: 10, denivelePositifM: 0), 10, accuracy: 0.001)
        XCTAssertEqual(UltraTrail.kilometresEffort(km: 10, denivelePositifM: 100), 11, accuracy: 0.001)
        XCTAssertEqual(UltraTrail.kilometresEffort(km: 80, denivelePositifM: 4000), 120, accuracy: 0.001)
    }

    /// Le modèle doit rendre des durées qu'une coureuse reconnaîtrait. Si ces chiffres-là sont
    /// faux, tout ce qui en descend l'est aussi — et rien d'autre dans le plan ne le signalerait.
    func testLeTempsDeffortEstPlausibleSurDeVraiesCourses() {
        // UTMB : 171 km, 10 000 m. Les finisseurs mettent entre 20 et 46 heures.
        let utmb = effort(171, 10_000) / 3600
        XCTAssertGreaterThan(utmb, 20)
        XCTAssertLessThan(utmb, 46)

        // CCC : 100 km, 6 100 m. Entre 14 et 26 heures.
        let ccc = effort(100, 6_100) / 3600
        XCTAssertGreaterThan(ccc, 14)
        XCTAssertLessThan(ccc, 26)
    }

    /// Le même nombre de kilomètres coûte plus cher en montagne. Évident, et c'est exactement ce
    /// que le moteur ignorait.
    func testLeDeniveleAllongeLeTempsDeffort() {
        XCTAssertGreaterThan(effort(50, 2_500), effort(50, 0) * 1.4)
    }

    // MARK: - La sortie longue

    /// L'INVARIANT DE STRUCTURE : l'affûtage allège toujours, le spécifique charge toujours plus
    /// que la base. Jamais l'inverse, pour aucune course.
    ///
    /// La première version avait un plancher COMMUN aux trois blocs, et sur une course courte la
    /// fraction d'affûtage passait dessous puis remontait à la valeur du bloc de base : l'affûtage
    /// prescrivait la même sortie longue que le bloc qu'il est censé alléger. Ce test balaie tout
    /// le domaine plausible, de la course de 15 km à l'UTMB.
    func testLAffutageAllegeToujoursEtLeSpecifiqueChargeToujoursPlus() {
        for km in stride(from: 15.0, through: 180.0, by: 5.0) {
            for densite in [0.0, 10.0, 25.0, 50.0, 60.0] {
                let t = effort(km, km * densite)
                let base = UltraTrail.cibleSortieLongueSecondes(tempsDeffortCourseSecondes: t, bloc: .base)
                let spec = UltraTrail.cibleSortieLongueSecondes(tempsDeffortCourseSecondes: t, bloc: .specifique)
                let affutage = UltraTrail.cibleSortieLongueSecondes(tempsDeffortCourseSecondes: t, bloc: .affutage)
                XCTAssertLessThan(affutage, base, "\(km) km à \(densite) m/km : l'affûtage doit alléger")
                XCTAssertLessThanOrEqual(base, spec, "\(km) km à \(densite) m/km : le spécifique charge plus")
            }
        }
    }

    /// Aucun plan ne prescrit une sortie de plus de six heures. Sans ce plafond, l'UTMB donnerait
    /// une « sortie longue » de quinze heures — une séance que personne ne fait, et la façon la
    /// plus sûre de faire abandonner un plan.
    func testAucuneSortieLongueNeDepasseSixHeures() {
        for km in stride(from: 15.0, through: 300.0, by: 5.0) {
            let t = effort(km, km * 60)
            for bloc in [UltraTrail.Bloc.base, .specifique, .affutage] {
                XCTAssertLessThanOrEqual(
                    UltraTrail.cibleSortieLongueSecondes(tempsDeffortCourseSecondes: t, bloc: bloc),
                    6 * 3600, "\(km) km, bloc \(bloc)")
            }
        }
    }

    /// Et une petite course garde tout de même une vraie sortie longue : sans plancher, un trail
    /// de 25 km donnerait une « sortie longue » de quarante minutes dans le bloc de base.
    func testUnePetiteCourseGardeUneVraieSortieLongue() {
        let t = effort(25, 1_000)
        let base = UltraTrail.cibleSortieLongueSecondes(tempsDeffortCourseSecondes: t, bloc: .base)
        XCTAssertGreaterThanOrEqual(base, 70 * 60)
    }

    func testUneCourseAbsurdeNeCassePasLeCalcul() {
        for t in [0.0, -1.0, 1_000_000.0] {
            for bloc in [UltraTrail.Bloc.base, .specifique, .affutage] {
                let cible = UltraTrail.cibleSortieLongueSecondes(tempsDeffortCourseSecondes: t, bloc: bloc)
                XCTAssertGreaterThan(cible, 0)
                XCTAssertLessThanOrEqual(cible, 6 * 3600)
            }
        }
        XCTAssertEqual(UltraTrail.kilometresEffort(km: -5, denivelePositifM: -100), 0, accuracy: 0.001)
    }

    // MARK: - Le dénivelé de la séance

    /// C'est la DENSITÉ qui décide, pas le total : un 80 km avec 4 000 m et un 80 km avec 800 m ne
    /// se préparent pas pareil, et c'est le mètre par kilomètre qui le dit.
    func testLaSeanceReproduitLaDensiteDeLaCourse() {
        let dense = UltraTrail.densite(km: 80, denivelePositifM: 4_000)      // 50 m/km
        let roulant = UltraTrail.densite(km: 80, denivelePositifM: 800)      // 10 m/km
        XCTAssertEqual(dense, 50, accuracy: 0.001)
        XCTAssertEqual(roulant, 10, accuracy: 0.001)

        XCTAssertEqual(UltraTrail.deniveleSortieLongueM(densiteCourseMParKm: dense, kmDeLaSortie: 20),
                       1_000, accuracy: 0.001)
        XCTAssertEqual(UltraTrail.deniveleSortieLongueM(densiteCourseMParKm: roulant, kmDeLaSortie: 20),
                       200, accuracy: 0.001)
    }

    /// Plafonné : au-delà de deux mille mètres on ne trouve plus le terrain, et une séance
    /// introuvable ne se fait pas.
    func testLeDeniveleDeLaSeanceEstPlafonne() {
        XCTAssertEqual(UltraTrail.deniveleSortieLongueM(densiteCourseMParKm: 100, kmDeLaSortie: 40),
                       2_000, accuracy: 0.001)
    }

    func testUneCourseSansDeniveleADesSeancesSansDenivele() {
        XCTAssertEqual(UltraTrail.densite(km: 50, denivelePositifM: 0), 0, accuracy: 0.001)
        XCTAssertEqual(UltraTrail.densite(km: 0, denivelePositifM: 500), 0, accuracy: 0.001,
                       "pas de distance, pas de densité — et surtout pas une division par zéro")
    }

    // MARK: - L'enchaînement du week-end

    /// Le back-to-back est la séance signature de l'ultra : partir le dimanche sur des jambes
    /// déjà entamées reproduit la deuxième moitié de l'épreuve. Le second jour est plus court —
    /// deux sorties égales deux jours de suite est la façon classique de se blesser.
    func testLeSecondJourEstPlusCourtQueLePremier() {
        let premier = 4.0 * 3600
        let second = UltraTrail.secondJourSecondes(premierJourSecondes: premier)
        XCTAssertLessThan(second, premier)
        XCTAssertGreaterThan(second, premier * 0.4, "assez long pour que la fatigue soit le sujet")
    }

    /// Sous quatre heures d'effort, l'épreuve ne demande pas d'apprendre à repartir sur des jambes
    /// mortes. Prescrire un enchaînement à qui n'en a pas besoin coûte un week-end entier pour
    /// rien.
    func testLEnchainementNeSeDemandeQuAuDelaDeQuatreHeures() {
        XCTAssertTrue(UltraTrail.demandeUnEnchainement(tempsDeffortCourseSecondes: effort(80, 4_000)))
        XCTAssertTrue(UltraTrail.demandeUnEnchainement(tempsDeffortCourseSecondes: effort(50, 2_000)))
        XCTAssertFalse(UltraTrail.demandeUnEnchainement(tempsDeffortCourseSecondes: effort(25, 1_000)))
    }

    // MARK: Les temps proposés, et comment ils se relisent

    /// « 13:00 » POUR UN 100 KM EST TREIZE HEURES, PAS TREIZE MINUTES.
    ///
    /// `PaceModel.parseChrono` tranchait sur `parts[0] >= 10` → des minutes, avec en commentaire
    /// « aucun vrai chrono de course ne commence à 10 heures ou plus ». C'était vrai tant que la
    /// liste s'arrêtait au marathon. Depuis les quatre formats d'ultra, les deux tiers des temps
    /// que l'app PROPOSE ELLE-MÊME tombaient du mauvais côté : 13:00, 15:00, 16:00, 18:00, 20:00,
    /// 24:00, 30:00, 36:00, 44:00. Un 100 km en vingt heures se relisait en vingt minutes, soit
    /// douze secondes au kilomètre.
    ///
    /// Le test balaie tous les temps réellement proposés, pour que l'ajout d'un format ne puisse
    /// pas rouvrir le trou en silence.
    func testTousLesTempsDultraSeRelisentEnHeures() {
        for format in [RaceDistance.ultra50, .ultra80, .ultra100, .ultra100M] {
            guard let km = format.km else { return XCTFail("\(format) doit connaître sa distance") }
            for preset in format.chronoPresets {
                guard let secondes = PaceModel.parseChronoSeconds(preset, distance: format) else {
                    return XCTFail("\(format.label) : « \(preset) » est illisible")
                }
                // Un temps d'ultra ne descend pas sous quatre heures et ne dépasse pas deux jours.
                XCTAssertGreaterThanOrEqual(secondes, 4 * 3600,
                                            "\(format.label) : « \(preset) » relu en \(Int(secondes / 60)) min")
                XCTAssertLessThanOrEqual(secondes, 48 * 3600,
                                         "\(format.label) : « \(preset) » relu en \(secondes / 3600) h")
                // Et l'allure moyenne qui en découle doit rester celle d'un humain en montagne.
                let allure = secondes / km
                XCTAssertGreaterThan(allure, 150, "\(format.label) : « \(preset) » donne \(Int(allure)) s/km")
                XCTAssertLessThan(allure, 1200, "\(format.label) : « \(preset) » donne \(Int(allure)) s/km")
            }
        }
    }

    /// Et les formats de route gardent exactement leur lecture d'avant — un semi en « 1:40 » est
    /// une heure quarante, un 10 km en « 42:00 » est quarante-deux minutes.
    func testLesFormatsDeRouteGardentLeurLecture() {
        XCTAssertEqual(PaceModel.parseChronoSeconds("42:00", distance: .k10), 42 * 60)
        XCTAssertEqual(PaceModel.parseChronoSeconds("1:40", distance: .semi), 100 * 60)
        XCTAssertEqual(PaceModel.parseChronoSeconds("3:30", distance: .marathon), 210 * 60)
        XCTAssertEqual(PaceModel.parseChronoSeconds("45:00", distance: .other), 45 * 60)
    }
}
