import XCTest
@testable import RunUp

/// La date d'une course ne doit pas changer selon l'endroit d'où on la regarde.
///
/// # LE DÉFAUT QUE CES TESTS EMPÊCHENT DE REVENIR
///
/// `races.race_date` est une colonne `DATE` : un jour, sans heure. Une colonne DATE traverse le
/// pilote Postgres en objet `Date` JavaScript, donc en ISO complet avec un fuseau — et le 4 avril
/// devient « 2027-04-03T22:00:00.000Z » pour un serveur en heure de Paris. Décodée telle quelle,
/// la course du Marathon de Paris s'affichait le 3 avril à qui lisait en UTC.
///
/// La route rend donc le jour en CLAIR (`to_char`), et c'est cette chaîne que `RaceEvent` garde.
/// `jour` la reconvertit à MIDI UTC, précisément pour qu'aucun décalage de fuseau — jusqu'à
/// quatorze heures — ne puisse la faire basculer sur la veille ou le lendemain à l'affichage.
final class RaceEventTests: XCTestCase {

    private func course(_ date: String, distanceKm: Double? = nil, elevationGainM: Int? = nil,
                        city: String? = nil) -> RaceEvent {
        RaceEvent(id: "1", name: "Marathon de Paris", city: city, raceDate: date,
                  distanceKm: distanceKm, elevationGainM: elevationGainM,
                  discipline: "run", website: nil, followerCount: nil)
    }

    // MARK: - Le jour ne bouge pas

    func testLeJourEstCeluiQuiEstEcrit() {
        let calendrier = Calendar(identifier: .gregorian)
        guard let jour = course("2027-04-04").jour else { return XCTFail("date illisible") }
        var utc = calendrier
        utc.timeZone = TimeZone(identifier: "UTC")!
        let parties = utc.dateComponents([.year, .month, .day], from: jour)
        XCTAssertEqual(parties.year, 2027)
        XCTAssertEqual(parties.month, 4)
        XCTAssertEqual(parties.day, 4)
    }

    func testMidiEtPasMinuit() {
        // Minuit UTC lu à Los Angeles (−8) est la VEILLE à 16 h. Midi laisse douze heures de
        // marge de chaque côté, soit plus que n'importe quel décalage réel.
        guard let jour = course("2027-04-04").jour else { return XCTFail("date illisible") }
        for fuseau in ["Pacific/Kiritimati", "America/Los_Angeles", "Pacific/Niue", "Asia/Tokyo"] {
            var calendrier = Calendar(identifier: .gregorian)
            calendrier.timeZone = TimeZone(identifier: fuseau)!
            XCTAssertEqual(calendrier.component(.day, from: jour), 4,
                           "le 4 avril n'est plus le 4 à \(fuseau)")
        }
    }

    func testUneDateIllisibleNeFaitPasTomberLAffichage() {
        // Le serveur ne devrait jamais rendre ça. Si ça arrive, la page doit afficher quelque
        // chose plutôt que rien : `dateLisible` retombe sur la chaîne brute.
        let abimee = course("pas-une-date")
        XCTAssertNil(abimee.jour)
        XCTAssertNil(abimee.joursRestants)
        XCTAssertEqual(abimee.dateLisible, "pas-une-date")
    }

    // MARK: - Le compte à rebours

    func testCeMatinLaCourseDuJourEstAZero() {
        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        formateur.dateFormat = "yyyy-MM-dd"
        // Le jour COURANT de l'appareil : `joursRestants` compare des minuits locaux, donc une
        // date construite en UTC ferait échouer le test la moitié de la journée.
        let aujourdhui = formateur.string(from: Date())
        XCTAssertEqual(course(aujourdhui).joursRestants, 0)
    }

    func testDemainEstAUn() {
        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        formateur.dateFormat = "yyyy-MM-dd"
        let demain = formateur.string(from: Date().addingTimeInterval(86400))
        XCTAssertEqual(course(demain).joursRestants, 1)
    }

    // MARK: - Le sous-titre

    func testLeSousTitreGardeLOrdreEtOmetLeVide() {
        XCTAssertEqual(course("2027-04-04", distanceKm: 42.195, elevationGainM: 120, city: "Paris").sousTitre,
                       "Paris · \(Distances.km(42.195)) · 120 m D+")
        // Pas de ville, pas de dénivelé : aucun point médian orphelin.
        XCTAssertEqual(course("2027-04-04", distanceKm: 10).sousTitre, Distances.km(10))
        XCTAssertEqual(course("2027-04-04").sousTitre, "")
    }

    func testUnDeniveleNulNEstPasAffiche() {
        // Un marathon sur route porte 0 m D+ en base : « 0 m D+ » n'apprend rien et prend la
        // place de la distance.
        XCTAssertEqual(course("2027-04-04", distanceKm: 42.195, elevationGainM: 0).sousTitre,
                       Distances.km(42.195))
    }

    func testLaDistanceSuitLaLangueEtPasLePointAnglais() {
        // La raison d'être de `Distances` : `String(format:)` sans `locale:` écrit un POINT dans
        // les trois langues, et « 42.2 km » en français est faux.
        let attendu = (42.2 as Double).formatted(.number.precision(.fractionLength(1)).locale(.current))
        XCTAssertTrue(Distances.km(42.195).hasPrefix(attendu),
                      "« \(Distances.km(42.195)) » ne commence pas par « \(attendu) »")
    }

    func testUnNombreRondPerdSaDecimale() {
        XCTAssertEqual(Distances.km(10), "10 km")
        XCTAssertEqual(Distances.km(10.04), "10 km")
    }

    // MARK: - Le pictogramme

    func testChaqueDisciplineAUnPictogramme() {
        for discipline in ["run", "trail", "hyrox", "triathlon", "duathlon", "inconnue"] {
            let course = RaceEvent(id: "1", name: "X", city: nil, raceDate: "2027-04-04",
                                   distanceKm: nil, elevationGainM: nil, discipline: discipline,
                                   website: nil, followerCount: nil)
            XCTAssertFalse(course.disciplineSymbole.isEmpty, "rien pour « \(discipline) »")
        }
    }
}
