import XCTest
@testable import RunUp

/// Le budget vertical de l'écran de course de la montre.
///
/// Ce test remplace un regard. L'écran qu'il mesure ne peut être vu par personne — pas de
/// simulateur ici, pas d'Apple Watch chez la personne qui décide — et un écran de course rogné ne
/// se rattrape pas : il se découvre en courant, une fois, au pire moment. Ce qu'on ne peut pas
/// regarder, on le calcule.
///
/// Les hauteurs ci-dessous sont celles que watchOS laisse à la vue : la hauteur d'affichage du
/// boîtier moins ses marges système. Ces marges sont SUPPOSÉES (28 points au total), et c'est
/// justement pourquoi la vue ne les code pas en dur — elle lit la hauteur qu'on lui donne. Le test
/// vérifie donc un intervalle large autour d'elles, pas une valeur unique.
final class WatchRunMetricsTests: XCTestCase {

    /// Les boîtiers que watchOS 10 fait tourner, du plus petit au plus grand.
    private let cases: [(name: String, available: CGFloat)] = [
        ("40 mm", 169),   // Series 4-6 et SE — le cas serré
        ("41 mm", 187),   // Series 7-10
        ("44 mm", 196),   // Series 4-6 et SE
        ("45 mm", 214),   // Series 7-9 — la taille de référence du dessin
        ("49 mm", 223),   // Ultra
    ]

    // MARK: - Ça tient

    func testFitsOnEveryWatchSize() {
        for (name, available) in cases {
            let m = WatchRunMetrics(availableHeight: available)
            XCTAssertLessThanOrEqual(
                m.height(showsProgress: true), available,
                "l'écran de course déborde sur un \(name) : \(m.height(showsProgress: true)) points pour \(available)"
            )
        }
    }

    /// Une course libre n'a pas de barre de progression — un bloc de moins, donc jamais un
    /// problème. Vérifié quand même : c'est l'autre composition réellement affichée.
    func testFitsWithoutTheProgressBar() {
        for (name, available) in cases {
            let m = WatchRunMetrics(availableHeight: available)
            XCTAssertLessThanOrEqual(m.height(showsProgress: false), available, "course libre rognée sur un \(name)")
        }
    }

    /// Le vrai filet : la marge système supposée peut être fausse. Si watchOS en prend dix de plus
    /// que prévu, l'écran doit encore tenir — d'où un balayage plutôt que cinq valeurs.
    func testFitsAcrossTheWholePlausibleRange() {
        for h in stride(from: CGFloat(140), through: 240, by: 1) {
            let m = WatchRunMetrics(availableHeight: h)
            XCTAssertLessThanOrEqual(m.height(showsProgress: true), h, "déborde à \(h) points de hauteur utile")
        }
    }

    // MARK: - Ce qui est sacrifié, et ce qui ne l'est pas

    /// La légende de progression doit survivre partout. C'est le seul élément que le calcul a le
    /// droit de retirer, et le retirer sur les tailles courantes voudrait dire que le dessin est
    /// encore trop haut.
    func testTheProgressCaptionSurvivesOnEverySize() {
        for (name, available) in cases {
            XCTAssertTrue(WatchRunMetrics(availableHeight: available).showsProgressCaption,
                          "la légende disparaît sur un \(name), le dessin est trop haut")
        }
    }

    /// Et elle disparaît bien quand la place manque vraiment — sinon l'arbitrage ne sert à rien.
    func testTheCaptionGoesWhenThereIsNoRoom() {
        XCTAssertFalse(WatchRunMetrics(availableHeight: 130).showsProgressCaption)
    }

    // MARK: - L'échelle

    func testReferenceHeightIsFullScale() {
        XCTAssertEqual(WatchRunMetrics(availableHeight: WatchRunMetrics.referenceHeight).scale, 1, accuracy: 0.001)
    }

    /// Un Ultra ne doit pas gonfler le dessin : il a plus de place, il la laisse vide.
    func testBiggerScreensDoNotInflateTheDesign() {
        let ultra = WatchRunMetrics(availableHeight: 260)
        XCTAssertEqual(ultra.scale, 1, accuracy: 0.001)
        XCTAssertEqual(ultra.hero, WatchRunMetrics(availableHeight: WatchRunMetrics.referenceHeight).hero)
    }

    /// Les petites capitales ne suivent pas l'échelle jusqu'en bas : sous huit points elles
    /// cessent d'être des mots. C'est ce plancher qui empêche « l'écran tient » de vouloir dire
    /// « l'écran est illisible mais entier ».
    func testSmallLabelsStopShrinking() {
        let tiny = WatchRunMetrics(availableHeight: 120)
        XCTAssertGreaterThanOrEqual(tiny.statusText, 8)
        XCTAssertGreaterThanOrEqual(tiny.heroLabel, 8)
        XCTAssertGreaterThanOrEqual(tiny.secondaryUnit, 7)
        XCTAssertGreaterThanOrEqual(tiny.buttonHeight, 28, "les boutons restent une cible qu'on vise en courant")
    }

    /// Le héros, lui, rétrécit franchement — c'est le plus gros objet de l'écran, et c'est sur lui
    /// que la place se reprend.
    func testTheHeroActuallyShrinksOnSmallScreens() {
        let small = WatchRunMetrics(availableHeight: 169)
        let reference = WatchRunMetrics(availableHeight: WatchRunMetrics.referenceHeight)
        XCTAssertLessThan(small.hero, reference.hero)
        XCTAssertGreaterThan(small.hero, reference.hero * 0.7, "mais il reste le grand chiffre")
    }
}
