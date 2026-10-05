import XCTest
@testable import RunUp

/// Verrouille la fenêtre d'allure récente, et surtout le défaut qu'elle répare : l'écran de
/// course et la voix du coach ne lisaient pas la même allure.
///
/// Le chiffre affiché sous ALLURE était la moyenne de toute la sortie. La voix, elle, comparait
/// une fenêtre de trente secondes à la cible du jour. Les deux sont justes séparément ; ensemble
/// ils donnent un coach qui dit « accélère un peu » pendant que le seul nombre à l'écran ne bouge
/// pas d'un cran — sur l'unique écran qu'on regarde en courant.
///
/// La fenêtre de l'alerte avait par ailleurs un défaut propre, invisible tant qu'elle restait
/// muette entre deux paliers : elle repartait de zéro toutes les trente secondes, et juste après
/// la remise à zéro l'allure calculée dessus valait n'importe quoi. Inaffichable. D'où une
/// fenêtre qui GLISSE, testée ici seconde par seconde.
final class PaceWindowTests: XCTestCase {

    /// Fait courir `seconds` secondes à `secPerKm` constantes, en échantillonnant chaque seconde.
    private func run(_ seconds: Int, secPerKm: Double,
                     state: inout PaceWindow.State, from elapsed: Double = 0, km: Double = 0) {
        var t = elapsed, d = km
        for _ in 0..<seconds {
            t += 1
            d += 1 / secPerKm
            PaceWindow.record(&state, elapsed: t, km: d)
        }
    }

    // MARK: - Ce que la fenêtre refuse de dire

    func testUneFenetreVideNeDonneAucuneAllure() {
        let state = PaceWindow.State()
        XCTAssertNil(PaceWindow.secPerKm(state, minimumSeconds: PaceWindow.displayMinimumSeconds))
    }

    func testUneFenetreTropCourteNeDonneAucuneAllure() {
        var state = PaceWindow.State()
        run(5, secPerKm: 300, state: &state)
        XCTAssertNil(PaceWindow.secPerKm(state, minimumSeconds: PaceWindow.displayMinimumSeconds),
                     "Cinq secondes donnent un nombre, pas une allure.")
    }

    /// Le tapis de course, la piste couverte, le GPS qui n'a pas encore accroché : le temps passe
    /// et la distance non. Il n'y a pas d'allure, et surtout pas une allure infinie.
    func testUneDistanceNulleNeDonneAucuneAllure() {
        var state = PaceWindow.State()
        for t in 1...40 { PaceWindow.record(&state, elapsed: Double(t), km: 0) }
        XCTAssertNil(PaceWindow.secPerKm(state, minimumSeconds: PaceWindow.displayMinimumSeconds))
    }

    // MARK: - Ce qu'elle mesure

    func testAllureConstanteEstRendueTelleQuelle() throws {
        var state = PaceWindow.State()
        run(60, secPerKm: 300, state: &state)
        let allure = PaceWindow.secPerKm(state, minimumSeconds: PaceWindow.displayMinimumSeconds)
        XCTAssertEqual(try XCTUnwrap(allure), 300, accuracy: 1)
    }

    /// LE DÉFAUT CENTRAL, en une mesure.
    ///
    /// Trente minutes à 5:00/km puis trente secondes à 4:00/km. La moyenne de la sortie n'a
    /// bougé que de trois secondes au kilomètre — invisible à l'écran. La fenêtre, elle, dit
    /// 4:00, c'est-à-dire ce que la coureuse est en train de faire.
    func testLaFenetreVoitLeChangementDeRythmeQueLaMoyenneNoie() throws {
        var state = PaceWindow.State()
        run(1800, secPerKm: 300, state: &state)
        let kmApres30Minutes = 1800.0 / 300
        run(30, secPerKm: 240, state: &state, from: 1800, km: kmApres30Minutes)

        let fenetre = try XCTUnwrap(PaceWindow.secPerKm(state, minimumSeconds: PaceWindow.displayMinimumSeconds))
        XCTAssertEqual(fenetre, 240, accuracy: 6)

        let totalKm = kmApres30Minutes + 30 / 240
        let moyenne = 1830 / totalKm
        XCTAssertLessThan(abs(moyenne - 300), 4, "La moyenne de la sortie ne bronche pas…")
        XCTAssertGreaterThan(abs(moyenne - fenetre), 50, "…alors que l'allure réelle a changé d'une minute au kilomètre.")
    }

    /// Ce que la fenêtre à paliers ne savait pas faire : donner une allure lisible à CHAQUE
    /// seconde. La fenêtre glissante est interrogée une fois par seconde sur une heure de course
    /// à allure constante, et ne doit jamais s'absenter ni dériver.
    func testLaFenetreResteLisibleASecondeApresLaDixieme() throws {
        var state = PaceWindow.State()
        var t = 0.0, d = 0.0
        for seconde in 1...3600 {
            t += 1
            d += 1 / 300.0
            PaceWindow.record(&state, elapsed: t, km: d)
            let allure = PaceWindow.secPerKm(state, minimumSeconds: PaceWindow.displayMinimumSeconds)
            if Double(seconde) >= PaceWindow.displayMinimumSeconds + 1 {
                XCTAssertEqual(try XCTUnwrap(allure), 300, accuracy: 2,
                               "Trou ou dérive à la seconde \(seconde).")
            }
        }
    }

    /// Une heure de course ne doit pas faire grossir l'état : la fenêtre garde trente secondes,
    /// pas la sortie entière.
    func testLaFenetreNeGrossitPas() {
        var state = PaceWindow.State()
        run(3600, secPerKm: 300, state: &state)
        XCTAssertLessThanOrEqual(state.samples.count, Int(PaceWindow.spanSeconds) + 3)
    }

    /// Et elle garde bien trente secondes, pas trois : rognée trop court, elle redeviendrait le
    /// bruit de foulée à foulée qu'on cherche justement à effacer.
    func testLaFenetreCouvreBienSaDuree() throws {
        var state = PaceWindow.State()
        run(600, secPerKm: 300, state: &state)
        let premier = try XCTUnwrap(state.samples.first)
        let dernier = try XCTUnwrap(state.samples.last)
        XCTAssertGreaterThanOrEqual(dernier.elapsed - premier.elapsed, PaceWindow.spanSeconds)
        XCTAssertLessThan(dernier.elapsed - premier.elapsed, PaceWindow.spanSeconds + 3)
    }

    // MARK: - La comparaison à la cible, règle unique de l'écran ET de la voix

    func testSansCibleIlNyARienAComparer() {
        XCTAssertEqual(PaceWindow.standing(secPerKm: 300, target: nil), .unknown)
    }

    func testSansAllureIlNyARienAComparer() {
        XCTAssertEqual(PaceWindow.standing(secPerKm: nil, target: 300), .unknown)
    }

    func testDansLaToleranceElleTientSaCible() {
        let marge = PaceWindow.toleranceSecPerKm - 1
        XCTAssertEqual(PaceWindow.standing(secPerKm: 300 + marge, target: 300), .onTarget)
        XCTAssertEqual(PaceWindow.standing(secPerKm: 300 - marge, target: 300), .onTarget)
    }

    func testAuDelaDeLaToleranceLeSensEstLeBon() {
        let delta = PaceWindow.toleranceSecPerKm + 1
        // Plus de secondes au kilomètre = plus LENTE. C'est le sens qu'on inverse sans y penser.
        XCTAssertEqual(PaceWindow.standing(secPerKm: 300 + delta, target: 300), .tooSlow)
        XCTAssertEqual(PaceWindow.standing(secPerKm: 300 - delta, target: 300), .tooFast)
    }

    func testLaToleranceEstStrictementFranchie() {
        XCTAssertEqual(PaceWindow.standing(secPerKm: 300 + PaceWindow.toleranceSecPerKm, target: 300), .onTarget,
                       "Pile sur la tolérance n'est pas au-delà — même règle que l'alerte vocale d'avant.")
    }

    /// Parler coûte plus cher que colorer un chiffre : la voix exige une fenêtre plus longue que
    /// l'écran. Si un jour les deux seuils se croisaient, le coach pourrait commenter une allure
    /// que l'écran refuse encore d'afficher.
    func testLaVoixEstPlusExigeanteQueLEcran() {
        XCTAssertGreaterThan(PaceWindow.alertMinimumSeconds, PaceWindow.displayMinimumSeconds)
        XCTAssertLessThan(PaceWindow.alertMinimumSeconds, PaceWindow.spanSeconds,
                          "La fenêtre n'atteint jamais sa durée pile : les échantillons arrivent à la seconde.")
    }
}
