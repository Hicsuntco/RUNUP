import XCTest
@testable import RunUp

/// Verrouille ce qui sépare une sortie vélo d'une course — c'est-à-dire tout ce qui, sans ça,
/// deviendrait faux en silence le jour du premier coup de pédale.
///
/// L'app n'a longtemps su faire qu'une chose, donc aucune agrégation n'avait à préciser ce
/// qu'elle comptait. Treize sommaient des kilomètres, d'autres cherchaient la meilleure allure
/// ou la plus longue sortie, les chaussures accumulaient leur usure, le plan cochait la séance
/// du jour. Toutes avaient raison faute de concurrence. Quarante kilomètres de vélo les rendent
/// toutes fausses sans qu'une seule ligne ne casse.
final class DisciplineTests: XCTestCase {

    private func releve(_ d: Discipline, km: Double, secondes: Int, allure: String) -> RunRecord {
        RunRecord(title: "Sortie", distanceKm: km, durationSeconds: secondes,
                  avgPace: allure, avgHeartRate: 0, kcal: 0, discipline: d)
    }

    // MARK: - Ce que la discipline décide

    func testUneSortieVeloNUsePasLesChaussures() {
        XCTAssertTrue(Discipline.run.wearsShoes)
        XCTAssertFalse(Discipline.bike.wearsShoes)
    }

    /// Tant qu'il n'y a pas de plan triathlon, le plan est un plan de course : rouler le mardi
    /// ne doit pas valider le fractionné du mardi, sinon le moteur adapte la semaine suivante
    /// sur une séance qui n'a jamais eu lieu.
    func testRoulerNeCochePasLaSeanceDeCourse() {
        XCTAssertTrue(Discipline.run.completesRunningPlan)
        XCTAssertFalse(Discipline.bike.completesRunningPlan)
    }

    /// La série mesure l'assiduité, pas le kilométrage : une heure de vélo n'est pas un jour sans
    /// rien faire.
    func testLesDeuxDisciplinesComptentPourLaSerie() {
        XCTAssertTrue(Discipline.allCases.allSatisfy { $0.countsTowardStreak })
    }

    /// Un relevé écrit avant que ce champ n'existe est une course : l'app ne savait rien faire
    /// d'autre. Si ce défaut changeait, toute l'histoire basculerait de discipline d'un coup.
    func testLeDefautEstLaCourse() {
        let ancien = RunRecord(title: "Footing", distanceKm: 5, durationSeconds: 1800,
                               avgPace: "6:00", avgHeartRate: 0, kcal: 0)
        XCTAssertEqual(ancien.discipline, .run)
        XCTAssertEqual(Discipline.legacy, .run)
    }

    // MARK: - Le filtre, et ce qu'il empêche

    func testOnlyNeGardeQueLaDisciplineDemandee() {
        let tout = [releve(.run, km: 5, secondes: 1800, allure: "6:00"),
                    releve(.bike, km: 40, secondes: 5400, allure: "2:15"),
                    releve(.run, km: 7, secondes: 2700, allure: "6:26")]
        XCTAssertEqual(tout.only(.run).count, 2)
        XCTAssertEqual(tout.only(.bike).count, 1)
        XCTAssertEqual(tout.allDisciplines.count, 3)
    }

    /// LE DÉFAUT CENTRAL, en une mesure. Quarante kilomètres de vélo doublaient la distance
    /// courue du mois.
    func testLeVeloNEntrePasDansLaDistanceCourue() {
        let tout = [releve(.run, km: 5, secondes: 1800, allure: "6:00"),
                    releve(.run, km: 7, secondes: 2700, allure: "6:26"),
                    releve(.bike, km: 40, secondes: 5400, allure: "2:15")]
        let courues = tout.only(.run).reduce(0) { $0 + $1.distanceKm }
        XCTAssertEqual(courues, 12, accuracy: 0.001)
        XCTAssertEqual(tout.allDisciplines.reduce(0) { $0 + $1.distanceKm }, 52, accuracy: 0.001)
    }

    /// Et le record d'allure, qu'une seule sortie vélo aurait emporté pour toujours : 2:15 au
    /// kilomètre, c'est 26 km/h, et aucune course ne le reprendra jamais.
    func testLeVeloNEmportePasLeRecordDAllure() throws {
        let tout = [releve(.run, km: 5, secondes: 1800, allure: "6:00"),
                    releve(.bike, km: 40, secondes: 5400, allure: "2:15")]
        let meilleure = tout.only(.run).compactMap { PaceModel.parseSecPerKm($0.avgPace) }.min()
        XCTAssertEqual(try XCTUnwrap(meilleure), 360, accuracy: 0.001)
    }

    // MARK: - Ce qui se lit, et dans quelle unité

    func testLaCourseSeLitEnAllureEtLeVeloEnVitesse() {
        let course = TimeFormat.rythme(.run, secondesParKm: 360)
        XCTAssertEqual(course.valeur, "6:00")
        XCTAssertEqual(course.unite, "/KM")

        let velo = TimeFormat.rythme(.bike, secondesParKm: 150)   // 150 s/km = 24 km/h
        XCTAssertEqual(velo.unite, "KM/H")
        XCTAssertEqual(Double(velo.valeur.replacingOccurrences(of: ",", with: ".")) ?? 0, 24, accuracy: 0.05)
    }

    /// Pas d'allure, pas de vitesse — et surtout pas l'infini qu'une division par zéro donnerait.
    func testSansAllureIlNyAPasDeVitesse() {
        XCTAssertEqual(TimeFormat.vitesse(secondesParKm: 0), "—")
        XCTAssertEqual(TimeFormat.vitesse(secondesParKm: -3), "—")
    }

    // MARK: - Les calories, et les seuils de pause

    /// À vélo la distance ne dit rien : une descente de cinq kilomètres ne coûte rien, les cinq
    /// de la montée coûtent dix fois plus. C'est la durée qui porte l'estimation.
    func testLesCaloriesDuVeloSuiventLaDureePasLaDistance() {
        let plat = Calories.estimate(.bike, distanceKm: 40, durationMinutes: 90)
        let colMemeDuree = Calories.estimate(.bike, distanceKm: 18, durationMinutes: 90)
        XCTAssertEqual(plat, colMemeDuree, accuracy: 0.001)
        XCTAssertEqual(plat, 90 * Calories.perCyclingMinute, accuracy: 0.001)
        // La course, elle, ne change pas de règle.
        XCTAssertEqual(Calories.estimate(.run, distanceKm: 10, durationMinutes: 60),
                       Calories.estimate(distanceKm: 10, durationMinutes: 60), accuracy: 0.001)
    }

    /// Être arrêtée, c'est être arrêtée, à pied comme sur une selle — mais REPARTIR n'a pas le
    /// même seuil : 1,3 m/s, c'est une marche rapide, et une cycliste y repasse au moindre coup
    /// de pédale dans un embouteillage.
    func testLesSeuilsDeRepriseDifferentMaisPasCeluiDePause() {
        let course = AutoPause.Seuils.pour(.run), velo = AutoPause.Seuils.pour(.bike)
        XCTAssertEqual(course.pause, velo.pause)
        XCTAssertGreaterThan(velo.reprise, course.reprise)
        XCTAssertGreaterThan(velo.eloignement, course.eloignement)
    }

    /// Vingt-cinq mètres se parcourent en trois secondes à vingt-cinq à l'heure : la deuxième
    /// preuve de reprise ne prouverait plus rien à vélo.
    func testUnVeloALArretNeRepartPasSurVingtCinqMetres() {
        let velo = AutoPause.Seuils.pour(.bike)
        XCTAssertFalse(AutoPause.shouldResume(speed: 0.2, metersSincePause: 25, seuils: velo))
        XCTAssertTrue(AutoPause.shouldResume(speed: 0.2, metersSincePause: 70, seuils: velo))
        XCTAssertFalse(AutoPause.shouldResume(speed: 1.5, metersSincePause: 0, seuils: velo))
        XCTAssertTrue(AutoPause.shouldResume(speed: 4.0, metersSincePause: 0, seuils: velo))
    }

    /// Et la règle de course n'a pas bougé d'un cran au passage.
    func testLaRegleDeCourseEstInchangee() {
        XCTAssertTrue(AutoPause.shouldResume(speed: 1.5, metersSincePause: 0))
        XCTAssertTrue(AutoPause.shouldResume(speed: nil, metersSincePause: 30))
        XCTAssertFalse(AutoPause.shouldResume(speed: nil, metersSincePause: 10))
    }
}
