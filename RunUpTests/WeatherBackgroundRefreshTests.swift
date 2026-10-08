import XCTest
@testable import RunUp

/// Les deux décisions pures du réveil météo en arrière-plan : quand le demander, et s'il y a une
/// séance ce jour-là.
///
/// Tout le reste de `WeatherBackgroundRefresh` est invérifiable sans appareil — iOS décide seul
/// s'il accorde un réveil, et aucun simulateur ne le reproduit honnêtement. La frontière est posée
/// exactement là : ce qui se calcule est testé ici, ce qui dépend du système est aussi mince que
/// possible et se mesure en production par `source=background` sur `weather_advice_sent`.
@MainActor
final class WeatherBackgroundRefreshTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private let jour = Date(timeIntervalSince1970: 1_757_000_000)
    private func a(_ h: Int) -> Date { cal.date(bySettingHour: h, minute: 0, second: 0, of: jour)! }

    // MARK: - Quand demander le réveil

    /// Deux heures après le début du créneau habituel — c'est le moment où
    /// `WeatherAdvice.jourAConseiller` bascule sur demain, donc le premier instant où le conseil
    /// a quelque chose de nouveau à dire.
    func testLeReveilEstDemandeApresLeCreneauHabituel() {
        let cible = WeatherBackgroundRefresh.prochainReveil(pour: .evening, maintenant: a(8),
                                                             calendrier: cal)
        XCTAssertEqual(cible, a(19), "17 h + 2 h")
    }

    /// Une heure fixe aurait été fausse pour la moitié des gens : celle qui court le matin veut
    /// être réveillée à 9 h, pas à 19 h.
    func testLHeureDemandeeSuitLeCreneau() {
        XCTAssertEqual(WeatherBackgroundRefresh.prochainReveil(pour: .morning, maintenant: a(4),
                                                                calendrier: cal), a(9))
        XCTAssertEqual(WeatherBackgroundRefresh.prochainReveil(pour: .noon, maintenant: a(4),
                                                                calendrier: cal), a(14))
    }

    /// Passé l'heure, c'est celle de demain qu'on demande — et jamais une date dans le passé, qui
    /// ferait exécuter la tâche immédiatement pour ne rien dire de nouveau.
    func testPasseLHeureLeReveilViseLeLendemain() {
        let cible = WeatherBackgroundRefresh.prochainReveil(pour: .evening, maintenant: a(21),
                                                             calendrier: cal)
        let demain = cal.date(byAdding: .day, value: 1, to: jour)!
        XCTAssertEqual(cible, cal.date(bySettingHour: 19, minute: 0, second: 0, of: demain)!)
        XCTAssertGreaterThan(cible, a(21))
    }

    func testLeReveilNEstJamaisDansLePasse() {
        for heure in 0...23 {
            for creneau in WeatherAdvice.Slot.allCases {
                let maintenant = a(heure)
                let cible = WeatherBackgroundRefresh.prochainReveil(pour: creneau,
                                                                     maintenant: maintenant,
                                                                     calendrier: cal)
                XCTAssertGreaterThan(cible, maintenant,
                                     "\(creneau) à \(heure) h donne un réveil déjà passé")
            }
        }
    }

    // MARK: - Court-elle ce jour-là

    private func profil(joursDeCourse: [Int], dureeDuJour: Int) -> UserProfile {
        let p = UserProfile(name: "Test")
        p.runningDays = joursDeCourse
        var seance = WorkoutSession.reprise
        seance.durationMinutes = dureeDuJour
        p.todaySession = seance
        p.weekSessions = (0..<7).map { PlannedDay(weekday: $0, session: nil) }
        return p
    }

    /// Aujourd'hui, c'est `todaySession` qui répond : la séance réellement posée, décalages
    /// compris, et non le plan théorique de la semaine.
    func testAujourdhuiCEstLaSeanceDuJourQuiRepond() {
        let courante = profil(joursDeCourse: [], dureeDuJour: 45)
        XCTAssertTrue(WeatherAdviceService.courtElle(le: jour, courante, maintenant: jour,
                                                      calendrier: cal))

        let repos = profil(joursDeCourse: [0, 1, 2, 3, 4, 5, 6], dureeDuJour: 0)
        XCTAssertFalse(WeatherAdviceService.courtElle(le: jour, repos, maintenant: jour,
                                                       calendrier: cal),
                       "un jour de repos ne devient pas un jour de course parce que "
                       + "`runningDays` le contient")
    }

    /// LE CAS DU DIMANCHE SOIR. Le jour visé appartient à la semaine SUIVANTE, qui n'est pas
    /// encore générée : le chercher dans `weekSessions` rendrait le lundi PASSÉ, c'est-à-dire la
    /// séance d'il y a six jours. C'est l'intention déclarée qui doit répondre.
    ///
    /// Tout en UTC, `weekdayIndex` compris : ce test a d'abord été écrit avec `Calendar.current`
    /// et il a échoué en intégration continue. La machine n'est pas en français, la semaine y
    /// commence le dimanche, et `isDate(equalTo:toGranularity: .weekOfYear)` déclarait donc le
    /// dimanche et le lundi suivant dans la même semaine. L'échec était réel : c'est le code de
    /// production qui se trompait, pas le test — voir `memeSemaineDePlan`.
    func testUnJourDeLaSemaineSuivanteSeLitDansLesJoursDeCourse() {
        let courant = cal
        // Un dimanche, et le lendemain est donc un lundi de la semaine d'après.
        var dimanche = courant.date(bySettingHour: 20, minute: 0, second: 0, of: jour)!
        while AdaptivePlanEngine.weekdayIndex(for: dimanche, calendrier: cal) != 6 {
            dimanche = courant.date(byAdding: .day, value: 1, to: dimanche)!
        }
        let lundi = courant.date(byAdding: .day, value: 1, to: dimanche)!
        XCTAssertEqual(AdaptivePlanEngine.weekdayIndex(for: lundi, calendrier: cal), 0)

        // Le plan de la semaine en cours est VIDE partout : s'il était consulté, la réponse
        // serait « non » et le conseil du dimanche soir ne partirait jamais.
        let qui = profil(joursDeCourse: [0, 2, 4], dureeDuJour: 0)
        XCTAssertTrue(WeatherAdviceService.courtElle(le: lundi, qui, maintenant: dimanche,
                                                      calendrier: courant))

        let quiNePasPas = profil(joursDeCourse: [1, 3, 5], dureeDuJour: 0)
        XCTAssertFalse(WeatherAdviceService.courtElle(le: lundi, quiNePasPas, maintenant: dimanche,
                                                       calendrier: courant))
    }

    /// Un autre jour de la MÊME semaine, lui, se lit dans le plan généré — c'est la séance qui
    /// sera réellement proposée, décalages de la semaine compris.
    func testUnAutreJourDeLaMemeSemaineSeLitDansLePlan() {
        let courant = cal
        // Un lundi, pour que mardi soit sûrement dans la même semaine.
        var lundi = courant.date(bySettingHour: 8, minute: 0, second: 0, of: jour)!
        while AdaptivePlanEngine.weekdayIndex(for: lundi, calendrier: cal) != 0 {
            lundi = courant.date(byAdding: .day, value: 1, to: lundi)!
        }
        let mardi = courant.date(byAdding: .day, value: 1, to: lundi)!

        let qui = profil(joursDeCourse: [], dureeDuJour: 0)
        var seance = WorkoutSession.reprise
        seance.durationMinutes = 50
        qui.weekSessions = (0..<7).map { PlannedDay(weekday: $0, session: $0 == 1 ? seance : nil) }

        XCTAssertTrue(WeatherAdviceService.courtElle(le: mardi, qui, maintenant: lundi,
                                                      calendrier: courant),
                      "mardi porte une séance de 50 minutes dans le plan de la semaine")

        let mercredi = courant.date(byAdding: .day, value: 2, to: lundi)!
        XCTAssertFalse(WeatherAdviceService.courtElle(le: mercredi, qui, maintenant: lundi,
                                                       calendrier: courant))
    }

    // MARK: - La semaine du plan ne dépend pas de la langue

    /// LE DÉFAUT QUE LA CI A ATTRAPÉ, isolé ici.
    ///
    /// `isDate(_:equalTo:toGranularity: .weekOfYear)` suit `Calendar.firstWeekday`, qui dépend de
    /// la langue de l'appareil. En français la semaine commence le lundi et la réponse tombait
    /// juste ; en anglais américain elle commence le dimanche, et un dimanche se retrouvait dans
    /// la même semaine que le lundi SUIVANT. Le conseil du dimanche soir allait alors chercher le
    /// lundi dans le plan de la semaine en cours, c'est-à-dire la séance d'il y a six jours.
    ///
    /// Ce test tourne les deux semaines, dimanche-first et lundi-first, et exige la même réponse.
    func testLaSemaineDuPlanVaTonjoursDuLundiAuDimanche() {
        for premierJour in [1, 2] {   // 1 = dimanche, 2 = lundi
            var calendrier = Calendar(identifier: .gregorian)
            calendrier.timeZone = TimeZone(secondsFromGMT: 0)!
            calendrier.firstWeekday = premierJour

            var dimanche = calendrier.date(bySettingHour: 20, minute: 0, second: 0, of: jour)!
            while AdaptivePlanEngine.weekdayIndex(for: dimanche, calendrier: calendrier) != 6 {
                dimanche = calendrier.date(byAdding: .day, value: 1, to: dimanche)!
            }
            let lundiSuivant = calendrier.date(byAdding: .day, value: 1, to: dimanche)!
            let samediAvant = calendrier.date(byAdding: .day, value: -1, to: dimanche)!

            XCTAssertFalse(
                WeatherAdviceService.memeSemaineDePlan(dimanche, lundiSuivant, calendrier),
                "premierJour=\(premierJour) : un dimanche et le lundi SUIVANT sont deux semaines")
            XCTAssertTrue(
                WeatherAdviceService.memeSemaineDePlan(dimanche, samediAvant, calendrier),
                "premierJour=\(premierJour) : un samedi et le dimanche suivant sont la même")
        }
    }

    // MARK: - La mémoire, relue depuis le profil

    func testLeConseilSeRelitDepuisSesDeuxCreneaux() {
        let qui = profil(joursDeCourse: [], dureeDuJour: 0)
        XCTAssertNil(WeatherAdviceService.conseilEnMemoire(qui))

        WeatherAdviceService.enregistrer(
            WeatherAdvice.DejaDit(jour: jour,
                                  conseil: WeatherAdvice.Advice(avoid: .evening, prefer: .noon),
                                  rectifiee: true),
            dans: qui)
        XCTAssertEqual(qui.weatherAdviceAvoidRaw, "evening")
        XCTAssertEqual(qui.weatherAdvicePreferRaw, "noon")
        XCTAssertTrue(qui.weatherAdviceAmended)
        XCTAssertEqual(WeatherAdviceService.conseilEnMemoire(qui),
                       WeatherAdvice.Advice(avoid: .evening, prefer: .noon))
    }

    /// Un seul créneau ne décrit pas un conseil — un conseil est toujours un déplacement de l'un
    /// vers l'autre. Une moitié de mémoire se lit comme une absence, pas comme un demi-conseil.
    func testUneMoitieDeMemoireNeDecritAucunConseil() {
        let qui = profil(joursDeCourse: [], dureeDuJour: 0)
        qui.weatherAdviceAvoidRaw = "evening"
        XCTAssertNil(WeatherAdviceService.conseilEnMemoire(qui))
    }

    func testUnCreneauInconnuNeSeRelitPas() {
        let qui = profil(joursDeCourse: [], dureeDuJour: 0)
        qui.weatherAdviceAvoidRaw = "nuit"
        qui.weatherAdvicePreferRaw = "noon"
        XCTAssertNil(WeatherAdviceService.conseilEnMemoire(qui))
    }
}
