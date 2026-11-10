import XCTest
@testable import RunUp

/// Verrouille les deux lectures d'un histogramme de durées.
///
/// # CE QU'ELLES SERVENT À DIRE
///
/// « Premier écran en moins de 2 secondes », phase 4 du brief. iOS mesure ce temps sur chaque
/// appareil réel et le livre par MetricKit sous forme de PALIERS — « 12 lancements avant 250 ms »
/// — jamais de durées. Toute statistique qu'on en tire est donc une approximation, et c'est la
/// DIRECTION de l'approximation qui compte : les deux lectures se trompent vers le pessimisme,
/// parce qu'une promesse qu'on arrondirait vers le bas s'annoncerait tenue sans l'être.
///
/// Ces cas-là sont tout ce qui se vérifie sans appareil : MetricKit ne livre rien dans un
/// simulateur, et la traduction de son histogramme tient en huit lignes isolées dans
/// `Diagnostics`. Toute la décision est ici.
final class HistogrammeTests: XCTestCase {

    private func h(_ paires: [(Double, Int)]) -> Histogramme {
        Histogramme(paliers: paires.map { .init(finMs: $0.0, compte: $0.1) })
    }

    // MARK: - Le total et le tri

    func testLeTotalEstLaSommeDesComptes() {
        XCTAssertEqual(h([(250, 12), (500, 3), (1000, 1)]).total, 16)
    }

    /// L'ORDRE D'ÉNUMÉRATION DE METRICKIT N'EST GARANTI NULLE PART. Un histogramme reçu à
    /// l'envers donnerait des percentiles faux sans que rien ne le signale, donc `init` trie.
    func testLesPaliersSontTriesQuelQueSoitLOrdreRecu() {
        let desordre = h([(1000, 1), (250, 12), (500, 3)])
        XCTAssertEqual(desordre.paliers.map(\.finMs), [250, 500, 1000])
        XCTAssertEqual(desordre.percentile(0.5), 250)
    }

    /// Un palier vide ou de borne nulle ne dit rien et décalerait les cumuls.
    func testLesPaliersVidesSontEcartes() {
        let avec = h([(250, 12), (400, 0), (0, 5), (500, 3)])
        XCTAssertEqual(avec.paliers.count, 2)
        XCTAssertEqual(avec.total, 15)
    }

    func testUnHistogrammeSansRienEstVide() {
        XCTAssertTrue(h([]).estVide)
        XCTAssertTrue(h([(250, 0)]).estVide)
        XCTAssertNil(h([]).percentile(0.5))
        XCTAssertNil(h([]).partAuDessusDe(ms: 2000))
    }

    // MARK: - Les percentiles, calculés à la main

    /// Dix observations : 5 avant 250 ms, 4 avant 1 000, 1 avant 3 000.
    ///
    /// p50 → rang 5 → le cumul l'atteint au premier palier → 250.
    /// p90 → rang 9 → cumul 5 puis 9 → 1 000.
    /// p100 → rang 10 → 3 000.
    func testLesPercentilesSurUnExempleCalculeALaMain() {
        let dix = h([(250, 5), (1000, 4), (3000, 1)])
        XCTAssertEqual(dix.percentile(0.5), 250)
        XCTAssertEqual(dix.percentile(0.9), 1000)
        XCTAssertEqual(dix.percentile(1.0), 3000)
    }

    /// `ceil` ET PAS `round`. À dix observations, le p50 est la cinquième, pas la cinq-et-demie.
    /// Avec `round`, un rang de 5,5 tombait à 6 et le p50 sautait au palier suivant — soit
    /// quatre fois plus de millisecondes annoncées, sur un exemple de dix lancements.
    func testLeRangArrondiVersLeHaut() {
        let trois = h([(250, 1), (1000, 1), (3000, 1)])
        // 3 × 0,5 = 1,5 → rang 2 → le deuxième palier.
        XCTAssertEqual(trois.percentile(0.5), 1000)
        // 3 × 0,34 = 1,02 → rang 2 aussi, et non 1 : on ne descend jamais sous l'observation.
        XCTAssertEqual(trois.percentile(0.34), 1000)
        // 3 × 0,33 = 0,99 → rang 1.
        XCTAssertEqual(trois.percentile(0.33), 250)
    }

    /// Une part minuscule garde un rang valide au lieu de rendre zéro.
    func testUnePartMinusculeRendLePremierPalier() {
        XCTAssertEqual(h([(250, 1000)]).percentile(0.0001), 250)
    }

    /// Hors de ]0, 1], on rend `nil` : quelqu'un qui passe 90 au lieu de 0,9 doit s'en apercevoir
    /// tout de suite, pas découvrir un p90 égal au dernier palier.
    func testUnePartHorsBornesNinventeRien() {
        let dix = h([(250, 5), (1000, 5)])
        XCTAssertNil(dix.percentile(0))
        XCTAssertNil(dix.percentile(-0.5))
        XCTAssertNil(dix.percentile(90))
        XCTAssertNil(dix.percentile(1.0001))
    }

    /// Le percentile est une BORNE HAUTE, et ce cas le dit : avec un seul palier, toutes les
    /// observations rendent la même valeur, parce que c'est tout ce que l'histogramme sait.
    func testAvecUnSeulPalierTousLesPercentilesSontCePalier() {
        let un = h([(1500, 42)])
        for part in [0.01, 0.5, 0.9, 1.0] {
            XCTAssertEqual(un.percentile(part), 1500, "part \(part)")
        }
    }

    // MARK: - La promesse des deux secondes

    /// Quatre lancements sur cinq finissent avant 2 s, le cinquième non.
    func testLaPartAuDessusDeDeuxSecondes() throws {
        let cinq = h([(500, 3), (1500, 1), (4000, 1)])
        XCTAssertEqual(try XCTUnwrap(cinq.partAuDessusDe(ms: 2000)), 0.2, accuracy: 0.0001)
    }

    /// UN PALIER À CHEVAL COMPTE COMME AU-DESSUS, et c'est voulu.
    ///
    /// Un palier qui finit à 2 500 ms contient peut-être des lancements de 1 900. On ne le sait
    /// pas, et on ne le saura jamais : la seule décision honnête pour une promesse est de les
    /// compter du mauvais côté. L'inverse annoncerait la promesse tenue sur une ignorance.
    func testUnPalierACheValCompteAuDessus() throws {
        let deux = h([(2500, 1), (1000, 1)])
        XCTAssertEqual(try XCTUnwrap(deux.partAuDessusDe(ms: 2000)), 0.5, accuracy: 0.0001)
    }

    /// Le seuil lui-même n'est pas « au-dessus » : un lancement qui finit pile à 2 000 ms tient
    /// la promesse de « moins de 2 secondes » à la milliseconde près, et la stricte inégalité est
    /// ce que dit la phrase.
    func testLeSeuilExactNEstPasAuDessus() throws {
        XCTAssertEqual(try XCTUnwrap(h([(2000, 4)]).partAuDessusDe(ms: 2000)), 0, accuracy: 0.0001)
    }

    func testToutAuDessusEtToutEnDessous() throws {
        XCTAssertEqual(try XCTUnwrap(h([(5000, 7)]).partAuDessusDe(ms: 2000)), 1, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(h([(300, 7)]).partAuDessusDe(ms: 2000)), 0, accuracy: 0.0001)
    }

    // MARK: - La ligne envoyée au serveur

    /// Compacte à dessein : le sac de propriétés est plafonné à 2 000 caractères côté serveur.
    func testLaLigneEstCompacteEtOrdonnee() {
        XCTAssertEqual(h([(1000, 1), (250, 12), (500, 3)]).ligne, "250:12,500:3,1000:1")
    }

    func testUneLigneVideResteVide() {
        XCTAssertEqual(h([]).ligne, "")
    }

    /// Un histogramme réaliste doit tenir très largement sous le plafond du serveur — sans quoi
    /// la ligne serait jetée en silence et l'événement arriverait sans ses paliers.
    func testUnHistogrammeRealisteTientSousLePlafondDuServeur() {
        // Vingt paliers, des comptes à quatre chiffres : plus large que tout ce que MetricKit
        // livre pour un seul appareil sur vingt-quatre heures.
        let large = h((1...20).map { (Double($0) * 250, 1000 + $0) })
        XCTAssertLessThan(large.ligne.count, 400, "la ligne : \(large.ligne)")
    }
}
