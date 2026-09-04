import XCTest
@testable import RunUp

/// Verrouille la disposition de l'écran de course de la montre.
///
/// Ce réglage a la particularité de traverser deux appareils : il est pris sur le téléphone,
/// sérialisé en une chaîne, poussé par WatchConnectivity, puis relu par une version de l'app
/// montre qui n'est pas forcément la même. Chacune de ces étapes peut rendre une sélection
/// incohérente, et la montre n'a personne pour la corriger — d'où une normalisation qui doit
/// tenir sur n'importe quelle entrée, pas seulement sur celles que l'écran de réglages produit.
final class WatchRunLayoutTests: XCTestCase {

    // MARK: - Normalisation

    /// Le défaut est la disposition choisie sur maquette. S'il dérive, c'est l'écran de tous ceux
    /// qui n'ont jamais ouvert les réglages qui dérive avec.
    func testStandardIsTimeThenDistancePaceHeartRate() {
        XCTAssertEqual(WatchRunLayout.standard.hero, .time)
        XCTAssertEqual(WatchRunLayout.standard.secondary, [.distance, .pace, .heartRate])
    }

    /// Le héros ne doit jamais réapparaître en bas : on lirait deux fois le même nombre sur un
    /// écran de 198 points, et le second passerait pour une autre mesure.
    func testHeroIsNeverRepeatedBelow() {
        let layout = WatchRunLayout.sanitized(hero: .distance, secondary: [.distance, .pace, .heartRate])
        XCTAssertFalse(layout.secondary.contains(.distance))
        XCTAssertEqual(layout.secondary.count, WatchRunLayout.secondaryCount)
    }

    func testDuplicatesAreDropped() {
        let layout = WatchRunLayout.sanitized(hero: .time, secondary: [.pace, .pace, .pace])
        XCTAssertEqual(layout.secondary.count, WatchRunLayout.secondaryCount)
        XCTAssertEqual(Set(layout.secondary).count, WatchRunLayout.secondaryCount)
        XCTAssertEqual(layout.secondary.first, .pace, "le choix explicite garde sa place")
    }

    /// Une sélection trop courte est complétée, jamais laissée telle quelle : deux chiffres
    /// laissent un trou dans la rangée, et zéro laisse un écran à moitié construit.
    func testShortSelectionIsFilledDeterministically() {
        let once = WatchRunLayout.sanitized(hero: .time, secondary: [.pace])
        let twice = WatchRunLayout.sanitized(hero: .time, secondary: [.pace])
        XCTAssertEqual(once.secondary.count, WatchRunLayout.secondaryCount)
        XCTAssertEqual(once.secondary, twice.secondary, "un même réglage tronqué doit donner le même écran")
        XCTAssertEqual(once.secondary.first, .pace)
    }

    func testEmptySelectionFallsBackToAFullRow() {
        let layout = WatchRunLayout.sanitized(hero: .calories, secondary: [])
        XCTAssertEqual(layout.secondary.count, WatchRunLayout.secondaryCount)
        XCTAssertFalse(layout.secondary.contains(.calories))
    }

    /// Plus de trois, c'est la rangée encombrée qu'on vient justement de quitter.
    func testMoreThanThreeIsTruncated() {
        let layout = WatchRunLayout.sanitized(hero: .time, secondary: [.distance, .pace, .heartRate, .calories])
        XCTAssertEqual(layout.secondary, [.distance, .pace, .heartRate])
    }

    // MARK: - Le transport

    func testWireRoundTrip() {
        for hero in RunMetric.allCases {
            let original = WatchRunLayout.sanitized(hero: hero, secondary: [.calories, .distance, .pace])
            let decoded = WatchRunLayout(wireValue: original.wireValue)
            XCTAssertEqual(decoded, original, "aller-retour perdu pour \(hero.rawValue)")
        }
    }

    func testWireValueIsReadable() {
        XCTAssertEqual(WatchRunLayout.standard.wireValue, "time|distance,pace,heartRate")
    }

    /// Une chaîne illisible doit rendre `nil`, pour que l'appelant retombe sur le défaut plutôt
    /// que d'afficher un écran construit à moitié.
    func testUnusableWireValuesAreRefused() {
        for bad in ["", "time", "|", "poids|distance,pace", "  "] {
            XCTAssertNil(WatchRunLayout(wireValue: bad), "« \(bad) » ne doit pas produire de disposition")
        }
    }

    /// Le cas qui arrivera pour de vrai : une montre à jour lit un réglage écrit par une version
    /// du téléphone qui connaît une métrique de plus. L'inconnue est ignorée, et la rangée est
    /// complétée — plutôt que de refuser tout le réglage pour un mot.
    func testUnknownMetricInAKnownShapeIsIgnoredNotFatal() {
        let layout = WatchRunLayout(wireValue: "time|distance,cadence,pace")
        XCTAssertNotNil(layout)
        XCTAssertEqual(layout?.hero, .time)
        XCTAssertEqual(layout?.secondary.count, WatchRunLayout.secondaryCount)
        XCTAssertEqual(layout?.secondary.prefix(2).map { $0 }, [.distance, .pace])
    }

    /// Un héros inconnu, en revanche, n'est pas rattrapable : c'est le chiffre principal, et lui
    /// en substituer un autre en silence donnerait un écran qui ne correspond à aucun réglage.
    func testUnknownHeroIsRefused() {
        XCTAssertNil(WatchRunLayout(wireValue: "cadence|distance,pace,heartRate"))
    }
}
