import XCTest
@testable import RunUp

/// Ce que le widget de l'écran d'accueil sait d'une course en cours — et surtout, quand il cesse
/// d'y croire.
///
/// Le chrono du widget avance TOUT SEUL : c'est le système qui le fait tourner, sans rechargement
/// et sans réveiller l'app. C'est ce qui le rend juste malgré le rationnement de WidgetKit, et
/// c'est aussi ce qui le rend dangereux — une app tuée en pleine sortie laisserait un chrono
/// tourner indéfiniment sur l'écran d'accueil, affichant une course qui n'a plus lieu. La
/// péremption est la seule chose qui l'en empêche.
final class LiveRunWidgetSnapshotTests: XCTestCase {

    private let instant = Date(timeIntervalSince1970: 1_757_000_000)

    private func course(publiee: Date, pause: Bool = false,
                        discipline: Discipline? = .run) -> LiveRunWidgetSnapshot {
        LiveRunWidgetSnapshot(startedAt: publiee.addingTimeInterval(-600),
                              elapsedSeconds: 600, isPaused: pause, distanceKm: 2.4,
                              rythmeValeur: "5:12", sessionTitle: "Footing",
                              disciplineRaw: discipline?.rawValue, publishedAt: publiee)
    }

    // MARK: - La péremption

    func testUneCourseFraichementPublieeEstCrue() {
        XCTAssertTrue(course(publiee: instant).estFraiche(a: instant.addingTimeInterval(60)))
    }

    func testPasseLeQuartDHeureOnNyCroitPlus() {
        let c = course(publiee: instant)
        XCTAssertFalse(c.estFraiche(a: instant.addingTimeInterval(
            LiveRunWidgetSnapshot.fraicheurMaximale + 1)))
    }

    /// La date de péremption est CALCULABLE à l'avance, et c'est tout l'intérêt : le widget pose
    /// d'emblée une entrée à cet instant-là, donc l'anneau revient même si plus aucun
    /// rechargement n'est accordé. Sans ça, la péremption aurait eu besoin — pour s'appliquer —
    /// de la chose même dont son absence est le symptôme.
    func testLaPeremptionSeCalculeAlAvance() {
        let c = course(publiee: instant)
        XCTAssertEqual(c.perimeeA, instant.addingTimeInterval(LiveRunWidgetSnapshot.fraicheurMaximale))
        XCTAssertFalse(c.estFraiche(a: c.perimeeA), "à la seconde de péremption, c'est fini")
        XCTAssertTrue(c.estFraiche(a: c.perimeeA.addingTimeInterval(-1)))
    }

    /// Un quart d'heure : assez pour couvrir un trou de republication, assez court pour qu'une app
    /// tuée ne laisse pas une fausse course tourner tout un après-midi. Et nécessairement plus
    /// long que l'intervalle de republication, sinon le widget se périmerait entre deux écritures
    /// parfaitement normales.
    func testLaFraicheurCouvreLargementLIntervalleDeRepublication() {
        XCTAssertGreaterThan(LiveRunWidgetSnapshot.fraicheurMaximale, 90 * 3,
                             "au moins trois republications de marge")
    }

    // MARK: - La discipline

    func testLaDisciplineSeRelitEtRetombeSurLaCourse() {
        XCTAssertEqual(course(publiee: instant, discipline: .bike).discipline, .bike)
        XCTAssertEqual(course(publiee: instant, discipline: .trail).discipline, .trail)
        XCTAssertEqual(course(publiee: instant, discipline: nil).discipline, .run,
                       "un instantané écrit par la version précédente n'a pas la clé")
    }

    /// C'est elle qui décide de l'unité sous le chiffre. L'écran verrouillé écrivait « /km » en
    /// dur, et annonçait donc des kilomètres-heure par kilomètre.
    func testLUniteDuWidgetSuitLaDiscipline() {
        XCTAssertEqual(course(publiee: instant, discipline: .bike).discipline.rythmeUnite, "km/h")
        XCTAssertEqual(course(publiee: instant, discipline: .trail).discipline.rythmeUnite, "/km")
    }

    // MARK: - Le codage

    /// Il traverse un conteneur de groupe d'app, donc il doit survivre à un aller-retour JSON —
    /// et un instantané écrit par une version plus ancienne, sans discipline, doit se décoder
    /// quand même.
    func testIlSurvitAUnAllerRetourJSON() throws {
        let c = course(publiee: instant, pause: true, discipline: .trail)
        let relu = try JSONDecoder().decode(LiveRunWidgetSnapshot.self,
                                            from: try JSONEncoder().encode(c))
        XCTAssertEqual(relu, c)
        XCTAssertTrue(relu.isPaused)
    }

    // MARK: - Le formatage partagé

    /// `TimeFormat.distance` existe parce que la même ligne était écrite trois fois : deux dans la
    /// Live Activity, une dans le widget d'accueil.
    ///
    /// Les assertions ne comparent PAS à « 7,42 » : le séparateur décimal suit la langue de
    /// l'appareil, et la machine d'intégration continue tourne en anglais. Deux tests ont déjà
    /// été écrits depuis un seul pays dans ce dépôt ; celui-ci vérifie la forme, pas la virgule.
    func testLaDistanceSeFormateADeuxDecimales() {
        let d = TimeFormat.distance(km: 7.42)
        XCTAssertTrue(d.hasPrefix("7"))
        XCTAssertEqual(d.count, 4, "un chiffre, un séparateur, deux décimales")
        XCTAssertNotEqual(TimeFormat.distance(km: 7.42), TimeFormat.distance(km: 7.43))
    }

    func testUneDistanceNegativeNexistePas() {
        XCTAssertEqual(TimeFormat.distance(km: -3), TimeFormat.distance(km: 0))
    }
}
