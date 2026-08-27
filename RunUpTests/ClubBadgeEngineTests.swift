import XCTest
@testable import RunUp

/// Verrouille la dérivation des badges, maintenant qu'elle est partagée par deux écrans.
///
/// Elle vivait dans une propriété privée de `ClubView` ; le profil l'affiche désormais aussi, donc
/// elle est passée dans `ClubBadgeEngine`. Un badge qui cesse de se débloquer ne casse rien et ne
/// s'affiche nulle part comme une erreur : la tuile reste simplement grise pour toujours. C'est
/// déjà arrivé une fois — le badge « Fractionné pro » se comptait en cherchant le mot
/// « Fractionné » dans `RunRecord.title`, qui porte le texte AFFICHÉ ; le jour où ce titre a été
/// traduit, le badge est devenu impossible à obtenir en anglais et en espagnol, en silence.
///
/// Ces tests couvrent donc les seuils et, surtout, ce cas-là.
final class ClubBadgeEngineTests: XCTestCase {

    private func run(km: Double = 5,
                     hour: Int = 12,
                     elevation: Int = 0,
                     daysAgo: Int = 0,
                     kind: SessionKind? = nil,
                     title: String = "Sortie") -> RunRecord {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 4 + daysAgo; comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? .now
        let record = RunRecord(date: date, title: title, distanceKm: km, durationSeconds: Int(km * 330),
                               avgPace: "5:30", avgHeartRate: 150, kcal: Int(km * 62),
                               elevationGainM: elevation)
        record.sessionKind = kind
        return record
    }

    private func earnedKeys(_ runs: [RunRecord], streak: Int = 0) -> Set<String> {
        let profile = UserProfile(name: "Test")
        profile.streak = streak
        return Set(ClubBadgeEngine.badges(runs: runs, profile: profile).filter(\.earned).map(\.key))
    }

    // MARK: - Le cas qui est déjà passé en production

    /// Le badge fractionné doit se compter sur `sessionKind`, jamais sur le titre affiché. Un
    /// titre anglais avec le bon `kind` doit le débloquer ; c'est exactement ce que la version
    /// qui cherchait « Fractionné » dans le texte ne faisait pas.
    func testIntervalBadgeCountsOnKindNotOnDisplayedTitle() {
        let english = (0..<3).map { run(daysAgo: $0, kind: .vo2maxIntervals, title: "Intervals") }
        XCTAssertTrue(earnedKeys(english).contains("interval3"),
                      "Trois séances de fractionné avec un titre anglais doivent débloquer le badge")
    }

    /// Les sorties antérieures au champ `sessionKind` n'ont que leur titre, resté français : la
    /// recherche de texte reste le repli correct pour elles seules.
    func testIntervalBadgeStillCountsLegacyFrenchTitles() {
        let legacy = (0..<3).map { run(daysAgo: $0, kind: nil, title: "Fractionné 8 × 400 m") }
        XCTAssertTrue(earnedKeys(legacy).contains("interval3"),
                      "Les anciennes sorties sans `kind` doivent encore compter par leur titre")
    }

    // MARK: - Seuils

    func testNoBadgesWithoutHistory() {
        XCTAssertTrue(earnedKeys([]).isEmpty, "Un compte vierge ne doit débloquer aucun badge")
    }

    func testFirstRunUnlocksOnASingleRun() {
        XCTAssertTrue(earnedKeys([run()]).contains("firstRun"))
    }

    func testDistanceThresholdsAreCumulativeAndInclusive() {
        let fifty = (0..<5).map { run(km: 10, daysAgo: $0) }
        let keys = earnedKeys(fifty)
        XCTAssertTrue(keys.contains("distance50"), "50 km pile doivent compter")
        XCTAssertFalse(keys.contains("distance250"))
    }

    func testLongestRunDrivesRaceDistanceBadges() {
        let keys = earnedKeys([run(km: 21)])
        XCTAssertTrue(keys.contains("halfMarathonDistance"), "21 km en une sortie")
        XCTAssertFalse(keys.contains("marathonDistance"))
    }

    /// Les paliers de course se lisent sur la PLUS LONGUE sortie, pas sur le cumul — sans quoi
    /// dix sorties de 5 km décerneraient un badge de demi-marathon.
    func testCumulativeDistanceDoesNotUnlockRaceDistances() {
        let many = (0..<10).map { run(km: 5, daysAgo: $0) }
        XCTAssertFalse(earnedKeys(many).contains("halfMarathonDistance"))
    }

    func testTimeOfDayBadges() {
        XCTAssertTrue(earnedKeys([run(hour: 6)]).contains("earlyRun"))
        XCTAssertTrue(earnedKeys([run(hour: 21)]).contains("nightRun"))
        XCTAssertFalse(earnedKeys([run(hour: 12)]).contains("earlyRun"))
        XCTAssertFalse(earnedKeys([run(hour: 12)]).contains("nightRun"))
    }

    func testStreakBadgesFollowTheProfileStreak() {
        XCTAssertTrue(earnedKeys([run()], streak: 3).contains("streak3"))
        XCTAssertFalse(earnedKeys([run()], streak: 3).contains("streak7"))
        XCTAssertTrue(earnedKeys([run()], streak: 30).contains("streak30"))
    }

    // MARK: - Forme du résultat

    /// La bande de badges du profil affiche TOUT le catalogue, gagné ou non : elle a besoin que
    /// la dérivation renvoie une entrée par définition, pas seulement les débloquées.
    func testEveryCatalogEntryIsReturnedEarnedOrNot() {
        let badges = ClubBadgeEngine.badges(runs: [], profile: UserProfile(name: "Test"))
        XCTAssertEqual(badges.count, ClubBadgeCatalog.all.count)
        XCTAssertEqual(Set(badges.map(\.key)), Set(ClubBadgeCatalog.all.map(\.key)))
    }
}
