import XCTest
@testable import RunUp

/// La règle de l'import depuis Apple Santé.
///
/// Les deux façons de se tromper ici ne ressemblent pas à des bugs quand on les voit. Trop
/// importer donne un historique où la même sortie figure deux ou trois fois — ça ressemble à une
/// grosse semaine. Trop peu importer laisse une semaine à « 1/4 séances » alors que les quatre ont
/// été courues — ça ressemble à une semaine ratée. Ni l'une ni l'autre ne fait planter quoi que ce
/// soit, et personne ne pense à ouvrir un ticket pour une semaine qui a l'air d'être la sienne.
final class HealthRunImportTests: XCTestCase {

    private func run(_ minutesAgo: Double, km: Double = 5, id: UUID = UUID(),
                     duration: Double = 1800,
                     discipline: Discipline = .run) -> HealthKitService.ImportedRun {
        HealthKitService.ImportedRun(
            id: id,
            start: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-minutesAgo * 60),
            durationSeconds: duration,
            distanceKm: km,
            kcal: 300,
            avgHeartRate: 150,
            discipline: discipline
        )
    }

    // MARK: - La fenêtre

    /// Le premier passage ne doit pas déverser des années d'historique : ce serait cent demandes
    /// de ressenti à l'ouverture, donc zéro validée.
    func testFirstImportOnlyLooksBackAWeek() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let since = HealthRunImport.window(lastImport: nil, now: now)
        XCTAssertEqual(now.timeIntervalSince(since), 7 * 86_400, accuracy: 1)
    }

    /// Et les suivants gardent un jour de recouvrement : une montre dépose parfois sa séance dans
    /// Santé bien après l'avoir enregistrée, et repartir pile de la dernière fenêtre la perdrait
    /// pour toujours.
    func testLaterImportsOverlapByADay() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let last = now.addingTimeInterval(-3600)
        let since = HealthRunImport.window(lastImport: last, now: now)
        XCTAssertEqual(last.timeIntervalSince(since), 86_400, accuracy: 1)
        XCTAssertLessThan(since, last, "sans recouvrement, une arrivée tardive est perdue")
    }

    // MARK: - Ce qu'on écarte

    func testAlreadyImportedRunsAreSkipped() {
        let known = UUID()
        let selected = HealthRunImport.selecting([run(60, id: known), run(30)],
                                                 knownIDs: [known], deja: [])
        XCTAssertEqual(selected.count, 1)
        XCTAssertNotEqual(selected.first?.id, known)
    }

    /// Le cas qui produit les doublons : la même sortie déposée par la montre ET par
    /// l'application du fabricant, à deux minutes d'écart. Deux identifiants, une seule course.
    func testTheSameRunFromTwoSourcesIsKeptOnce() {
        let first = run(60)
        let duplicate = HealthKitService.ImportedRun(
            id: UUID(), start: first.start.addingTimeInterval(120),
            durationSeconds: first.durationSeconds, distanceKm: first.distanceKm,
            kcal: first.kcal, avgHeartRate: first.avgHeartRate
        )
        let selected = HealthRunImport.selecting([first, duplicate], knownIDs: [], deja: [])
        XCTAssertEqual(selected.count, 1, "deux dépôts de la même sortie ne font pas deux courses")
    }

    /// Et la même chose face à ce qui est DÉJÀ dans l'historique — typiquement une sortie faite
    /// avec le bouton RUN, qu'une montre tierce portée en même temps a aussi enregistrée.
    func testARunAlreadyInHistoryIsNotImportedAgain() {
        let existing = run(60)
        let selected = HealthRunImport.selecting([existing], knownIDs: [],
                                                 deja: [.init(date: existing.start.addingTimeInterval(-90))])
        XCTAssertTrue(selected.isEmpty)
    }

    // MARK: - La natation

    /// LE SEUIL DE « VRAIE SÉANCE » N'EST PAS LE MÊME EN BASSIN.
    ///
    /// Trois cents mètres ne sont rien à pied — c'est une manipulation. En natation, c'est un
    /// échauffement, et une séance de 300 m compte.
    ///
    /// Surtout, UNE NAGE PEUT NE PORTER AUCUNE DISTANCE : une montre qui ne connaît pas la
    /// longueur du bassin, ou une traversée en eau libre sans GPS, et Santé rend zéro mètre pour
    /// quarante minutes d'effort. La règle de la course la jetterait, et pour un plan de
    /// triathlon c'est précisément la séance qu'il faut compter.
    func testUneNageSansDistanceEstUneNage() {
        let quaranteMinutes = run(10, km: 0, duration: 2400, discipline: .swim)
        XCTAssertTrue(HealthRunImport.estUneSeance(quaranteMinutes),
                      "quarante minutes sans un mètre mesuré restent une séance")

        // La même durée en COURSE, sans distance : écartée. C'est un entraînement ouvert puis
        // refermé, ou une mesure qui n'a rien donné.
        XCTAssertFalse(HealthRunImport.estUneSeance(run(10, km: 0, duration: 2400)))

        // Trois cents mètres nagés en dix minutes : une vraie séance courte.
        XCTAssertTrue(HealthRunImport.estUneSeance(run(10, km: 0.3, duration: 600, discipline: .swim)))
        // Les mêmes trois cents mètres à pied : une manipulation.
        XCTAssertFalse(HealthRunImport.estUneSeance(run(10, km: 0.3, duration: 600)))

        // Et une nage d'une minute à cinquante mètres reste une manipulation.
        XCTAssertFalse(HealthRunImport.estUneSeance(run(10, km: 0.05, duration: 90, discipline: .swim)))
    }

    /// LE DÉFAUT QUE LE TRIATHLON A RÉVÉLÉ, ET IL AURAIT COMPTÉ UNE SÉANCE SUR TROIS.
    ///
    /// Le dédoublonnage comparait les horaires sans regarder ce qui avait été fait. Juste tant que
    /// l'import ne ramenait que des courses : deux courses à cinq minutes d'intervalle SONT la
    /// même course, écrite deux fois par deux sources.
    ///
    /// Deux disciplines différentes à cinq minutes d'intervalle, non — c'est un enchaînement, la
    /// séance qui définit le triathlon. L'ancienne règle n'en gardait qu'une et jetait l'autre
    /// sans rien dire : l'entraînement le plus dur de la semaine aurait été celui qui compte le
    /// moins.
    func testUnEnchainementNEstPasUnDoublon() {
        let nage = run(60, km: 1.5, duration: 1800, discipline: .swim)
        // Deux minutes après la sortie de l'eau : la transition.
        let course = run(58, km: 5, duration: 1500, discipline: .run)
        XCTAssertLessThan(abs(nage.start.timeIntervalSince(course.start)), HealthRunImport.sameRunWindow,
                          "le banc n'a de sens que si les deux sont dans la fenêtre de doublon")

        let gardees = HealthRunImport.selecting([nage, course], knownIDs: [], deja: [])
        XCTAssertEqual(gardees.count, 2, "une nage et une course enchaînées sont deux séances")
        XCTAssertEqual(Set(gardees.map(\.discipline)), [.swim, .run])

        // Et dans la même discipline, la règle du doublon s'applique toujours : deux nages à deux
        // minutes d'intervalle sont la même nage, écrite par la montre ET par l'app du fabricant.
        let memeNage = run(59, km: 1.5, duration: 1800, discipline: .swim)
        let dedoublonnees = HealthRunImport.selecting([nage, memeNage], knownIDs: [], deja: [])
        XCTAssertEqual(dedoublonnees.count, 1)
    }

    /// Et une nage déjà dans l'historique n'est pas réimportée — mais une course au même horaire
    /// l'est, parce que ce n'est pas la même séance.
    func testLHistoriqueEstComparePardiscipline() {
        let nage = run(60, km: 1.5, duration: 1800, discipline: .swim)
        let dejaNagee = [HealthRunImport.Deja(date: nage.start.addingTimeInterval(-60),
                                              discipline: .swim)]
        XCTAssertTrue(HealthRunImport.selecting([nage], knownIDs: [], deja: dejaNagee).isEmpty)

        let course = run(60, km: 5, discipline: .run)
        XCTAssertEqual(HealthRunImport.selecting([course], knownIDs: [], deja: dejaNagee).count, 1,
                       "une nage dans l'historique n'empêche pas d'importer une course")
    }

    /// Au-delà de la fenêtre, en revanche, ce sont deux vraies courses — un fractionné le matin et
    /// une sortie facile le soir, par exemple.
    func testTwoRunsOnTheSameDayAreBothKept() {
        let morning = run(600)
        let evening = run(60)
        let selected = HealthRunImport.selecting([morning, evening], knownIDs: [], deja: [])
        XCTAssertEqual(selected.count, 2)
    }

    func testEmptyWorkoutsAreNotRuns() {
        XCTAssertFalse(HealthRunImport.estUneSeance(run(10, km: 0, duration: 20)))
        XCTAssertFalse(HealthRunImport.estUneSeance(run(10, km: 5, duration: 30)), "trente secondes n'est pas une sortie")
        XCTAssertFalse(HealthRunImport.estUneSeance(run(10, km: 0.1)), "cent mètres non plus")
        XCTAssertTrue(HealthRunImport.estUneSeance(run(10, km: 1.2, duration: 400)), "mais une sortie courte reste une sortie")
    }

    /// L'ordre compte pour le dédoublonnage : c'est la première dans le temps qui est gardée, pas
    /// celle que Santé a rendue en premier.
    func testSelectionIsChronologicalWhateverTheOrderReceived() {
        let a = run(600), b = run(300), c = run(60)
        let selected = HealthRunImport.selecting([c, a, b], knownIDs: [], deja: [])
        XCTAssertEqual(selected.map(\.start), [a, b, c].map(\.start))
    }
    /// Le tracé traverse la sélection sans être touché. C'est lui qui fait la différence entre une
    /// carte de fil avec une image et une carte sans — et c'est le champ dont l'ajout a cassé ce
    /// fichier, faute d'être couvert par quoi que ce soit.
    func testTheRouteSurvivesSelection() {
        var withRoute = run(60)
        withRoute.route = [
            RunRecord.RoutePoint(lat: 45.76, lng: 4.83),
            RunRecord.RoutePoint(lat: 45.77, lng: 4.84),
        ]
        let selected = HealthRunImport.selecting([withRoute], knownIDs: [], deja: [])
        XCTAssertEqual(selected.first?.route.count, 2)
    }

    /// Et une sortie sans parcours reste une sortie : un tapis de course ou une montre sans GPS
    /// n'a pas de tracé, et ça ne doit rien empêcher.
    func testARunWithoutARouteIsStillImported() {
        let selected = HealthRunImport.selecting([run(60)], knownIDs: [], deja: [])
        XCTAssertEqual(selected.count, 1)
        XCTAssertTrue(selected.first?.route.isEmpty ?? false)
    }
}
