import XCTest
@testable import RunUp

/// Verrouille le rang du jour dans la bande du widget, lundi = 0.
///
/// # LE DÉFAUT QUE CES TESTS REMPLACENT
///
/// Le widget d'accueil écrit son titre à partir de la date que le système lui donne, et lisait sa
/// pastille de jour dans `isToday`, écrit par l'app au dernier instantané publié. Sur un vrai
/// téléphone un mardi matin, le titre disait « Mardi » pendant que la pastille cerclée était sur
/// lundi : deux parties du même widget, deux jours différents, parce que l'une sait l'heure et
/// l'autre récite ce qu'on lui a dit la veille.
///
/// Le rang se calcule désormais, et ce calcul est un décalage modulo 7 — exactement le genre
/// d'arithmétique qu'on croit juste sans la vérifier. Les sept jours y passent, un par un.
final class WidgetWeekStripTests: XCTestCase {

    /// Lundi 2 novembre 2026, à midi pour ne dépendre d'aucun fuseau.
    private func jour(_ day: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = day; c.hour = 12
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "UTC")!
        return calendrier.date(from: c)!
    }

    private func rang(_ day: Int) -> Int {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "UTC")!
        return WidgetWeekDay.rangDuJour(jour(day), calendrier: calendrier)
    }

    func testLesSeptJoursDeLaSemaineTombentDansLOrdreDeLaBande() {
        // 2 novembre 2026 est un lundi. La bande va de lundi à dimanche.
        XCTAssertEqual(rang(2), 0, "lundi")
        XCTAssertEqual(rang(3), 1, "mardi")
        XCTAssertEqual(rang(4), 2, "mercredi")
        XCTAssertEqual(rang(5), 3, "jeudi")
        XCTAssertEqual(rang(6), 4, "vendredi")
        XCTAssertEqual(rang(7), 5, "samedi")
        XCTAssertEqual(rang(8), 6, "dimanche")
    }

    /// Dimanche est le piège : `Calendar` lui donne 1, donc une conversion naïve le place en
    /// tête de bande, là où l'app le met en dernier.
    func testDimancheEstEnFinDeBandeEtPasEnTete() {
        XCTAssertEqual(rang(8), 6)
        XCTAssertNotEqual(rang(8), 0)
    }

    func testLeRangResteDansLesBornesDeLaBande() {
        for d in 2...8 {
            let r = rang(d)
            XCTAssertTrue((0...6).contains(r), "rang \(r) hors de la bande pour le \(d)")
        }
    }

    /// L'instantané ne porte plus l'objectif à zéro : sans lui, le widget ne pouvait écrire que
    /// le reste, et il l'écrivait avec un signe moins.
    func testLesObjectifsVoyagentDansLInstantane() {
        let s = DailyGoalsSnapshot(progress: [0, 0, 0], streak: 1, accentThemeID: "rose",
                                   isLightMode: true, dailyGoalsDone: 0, dailyGoalsTotal: 3,
                                   activeCaloriesRemaining: 360, stepsRemaining: 9000,
                                   weekStrip: [], isRestDay: false,
                                   activeCaloriesGoal: 600, stepsGoal: 15000)
        let encode = try! JSONEncoder().encode(s)
        let relu = try! JSONDecoder().decode(DailyGoalsSnapshot.self, from: encode)
        XCTAssertEqual(relu.activeCaloriesGoal, 600)
        XCTAssertEqual(relu.stepsGoal, 15000)
    }

    /// Et un instantané écrit par une version précédente, qui ne les portait pas, reste lisible :
    /// sans ça le widget retomberait sur ses données d'exemple jusqu'à la publication suivante.
    func testUnInstantaneSansObjectifsResteLisible() throws {
        let ancien = """
        {"progress":[0,0,0],"streak":1,"accentThemeID":"rose","isLightMode":true,
         "dailyGoalsDone":0,"dailyGoalsTotal":3,"activeCaloriesRemaining":360,
         "stepsRemaining":9000,"weekStrip":[],"isRestDay":false}
        """.data(using: .utf8)!
        let relu = try JSONDecoder().decode(DailyGoalsSnapshot.self, from: ancien)
        XCTAssertEqual(relu.activeCaloriesGoal, 0)
        XCTAssertEqual(relu.stepsGoal, 0)
        XCTAssertEqual(relu.activeCaloriesRemaining, 360)
    }
}
