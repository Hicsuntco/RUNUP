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
                     duration: Double = 1800) -> HealthKitService.ImportedRun {
        HealthKitService.ImportedRun(
            id: id,
            start: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-minutesAgo * 60),
            durationSeconds: duration,
            distanceKm: km,
            kcal: 300,
            avgHeartRate: 150
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
                                                 knownIDs: [known], existingDates: [])
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
        let selected = HealthRunImport.selecting([first, duplicate], knownIDs: [], existingDates: [])
        XCTAssertEqual(selected.count, 1, "deux dépôts de la même sortie ne font pas deux courses")
    }

    /// Et la même chose face à ce qui est DÉJÀ dans l'historique — typiquement une sortie faite
    /// avec le bouton RUN, qu'une montre tierce portée en même temps a aussi enregistrée.
    func testARunAlreadyInHistoryIsNotImportedAgain() {
        let existing = run(60)
        let selected = HealthRunImport.selecting([existing], knownIDs: [],
                                                 existingDates: [existing.start.addingTimeInterval(-90)])
        XCTAssertTrue(selected.isEmpty)
    }

    /// Au-delà de la fenêtre, en revanche, ce sont deux vraies courses — un fractionné le matin et
    /// une sortie facile le soir, par exemple.
    func testTwoRunsOnTheSameDayAreBothKept() {
        let morning = run(600)
        let evening = run(60)
        let selected = HealthRunImport.selecting([morning, evening], knownIDs: [], existingDates: [])
        XCTAssertEqual(selected.count, 2)
    }

    func testEmptyWorkoutsAreNotRuns() {
        XCTAssertFalse(HealthRunImport.isARun(run(10, km: 0, duration: 20)))
        XCTAssertFalse(HealthRunImport.isARun(run(10, km: 5, duration: 30)), "trente secondes n'est pas une sortie")
        XCTAssertFalse(HealthRunImport.isARun(run(10, km: 0.1)), "cent mètres non plus")
        XCTAssertTrue(HealthRunImport.isARun(run(10, km: 1.2, duration: 400)), "mais une sortie courte reste une sortie")
    }

    /// L'ordre compte pour le dédoublonnage : c'est la première dans le temps qui est gardée, pas
    /// celle que Santé a rendue en premier.
    func testSelectionIsChronologicalWhateverTheOrderReceived() {
        let a = run(600), b = run(300), c = run(60)
        let selected = HealthRunImport.selecting([c, a, b], knownIDs: [], existingDates: [])
        XCTAssertEqual(selected.map(\.start), [a, b, c].map(\.start))
    }
}
