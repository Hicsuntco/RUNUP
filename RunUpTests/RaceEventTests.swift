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
///
/// # ET MIDI UTC NE SUFFIT PAS — C'EST CE TEST QUI L'A MONTRÉ
///
/// La première version de `jour` posait l'instant à MIDI UTC, en se disant que douze heures de
/// marge de chaque côté couvraient tous les fuseaux. Faux : les fuseaux habités vont de UTC−12 à
/// UTC+14, soit VINGT-SIX heures d'amplitude. À Kiritimati (+14), midi UTC est déjà le lendemain
/// à deux heures du matin, et ce test-ci lisait le 4 avril comme un 5. Aucun instant n'est le même
/// jour au calendrier partout — la question n'a pas de bonne réponse sous cette forme.
///
/// Le jour est donc FORMATÉ en UTC (`dateLisible`) : la langue et l'ordre des mots suivent le
/// téléphone, le jour ne suit personne. `joursRestants` est le seul endroit où le fuseau de la
/// personne compte, parce que « J-42 » répond à « combien de jours me reste-t-il ».
final class RaceEventTests: XCTestCase {

    private func course(_ date: String, distanceKm: Double? = nil, elevationGainM: Int? = nil,
                        city: String? = nil) -> RaceEvent {
        RaceEvent(id: "1", name: "Marathon de Paris", city: city, raceDate: date,
                  distanceKm: distanceKm, elevationGainM: elevationGainM,
                  discipline: "run", website: nil, followerCount: nil)
    }

    // MARK: - Le jour ne bouge pas

    func testLeJourEstCeluiQuiEstEcrit() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let jour = course("2027-04-04").jour else { return XCTFail("date illisible") }
        let parties = utc.dateComponents([.year, .month, .day], from: jour)
        XCTAssertEqual(parties.year, 2027)
        XCTAssertEqual(parties.month, 4)
        XCTAssertEqual(parties.day, 4)
    }

    func testLeJourAfficheEstCeluiDuDossardOuQueSoitLeTelephone() {
        // LE TEST QUI COMPTE. Pas « l'instant tombe-t-il le bon jour quelque part », mais « la
        // phrase affichée porte-t-elle le bon jour ». `dateLisible` formate en UTC, donc elle ne
        // dépend pas du fuseau de l'appareil : le 4 avril est le 4 avril partout.
        //
        // Le fuseau du simulateur ne se change pas depuis un test, alors on vérifie la propriété
        // directement : le même instant, relu dans le fuseau du formateur, redonne le jour écrit.
        let lisible = course("2027-04-04").dateLisible
        XCTAssertTrue(lisible.contains("4"), "« \(lisible) » ne porte pas le 4")
        XCTAssertTrue(lisible.contains("2027"), "« \(lisible) » ne porte pas 2027")
        // Les deux jours voisins : ce sont EXACTEMENT les deux valeurs qu'un instant mal placé
        // produisait (3 à l'ouest avec minuit, 5 à l'est avec midi).
        XCTAssertFalse(lisible.contains(" 3 ") || lisible.contains(" 5 "),
                       "« \(lisible) » a glissé d'un jour")
    }

    func testRelireLInstantAilleursQuEnUTCFaitGlisserLeJour() {
        // POURQUOI L'AFFICHAGE EST FORMATÉ EN UTC, démontré plutôt qu'affirmé.
        //
        // `jour` vaut minuit UTC. Relu en UTC c'est bien le 4 ; relu à Los Angeles (−7 en avril),
        // c'est le 3 à 17 h. Minuit glisse donc vers l'OUEST, exactement comme midi glissait vers
        // l'EST (Kiritimati, +14, le lisait comme le 5 — c'est l'échec qui a fait réécrire tout
        // ça). Il n'existe pas d'heure qui règle les deux : vingt-six heures d'amplitude de
        // fuseaux contre vingt-quatre dans une journée. D'où un jour FORMATÉ en UTC, et non un
        // instant qu'on espère bien placé.
        guard let jour = course("2027-04-04").jour else { return XCTFail("date illisible") }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(utc.component(.day, from: jour), 4)

        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(losAngeles.component(.day, from: jour), 3,
                       "minuit UTC devrait se lire la veille à l'ouest — c'est tout l'intérêt de ne pas afficher cet instant tel quel")
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
