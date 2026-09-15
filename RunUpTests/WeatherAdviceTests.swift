import XCTest
@testable import RunUp

/// La règle qui décide d'envoyer « il va pleuvoir, cours plutôt à tel moment ».
///
/// Ce qu'on teste surtout ici, c'est le SILENCE. Une notification météo n'a qu'une seule façon
/// d'échouer vraiment : crier au loup. Deux annonces de pluie suivies d'une journée sèche, et
/// l'interrupteur est coupé pour toujours. La moitié de ces tests vérifie donc qu'on se tait.
final class WeatherAdviceTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private let jour = Date(timeIntervalSince1970: 1_757_000_000) // un jour quelconque, fixe

    private func heure(_ h: Int, pluie: Double, mm: Double = 1.0) -> WeatherAdvice.Hour {
        WeatherAdvice.Hour(date: cal.date(bySettingHour: h, minute: 0, second: 0, of: jour)!,
                           precipitationChance: pluie, precipitationIntensity: mm)
    }

    /// Une journée : sec partout sauf aux heures nommées.
    private func journee(pluvieuses: [Int], probabilite: Double = 0.9,
                         mm: Double = 2.0) -> [WeatherAdvice.Hour] {
        (6...21).map { h in
            pluvieuses.contains(h) ? heure(h, pluie: probabilite, mm: mm) : heure(h, pluie: 0.05)
        }
    }

    private func a(_ h: Int) -> Date { cal.date(bySettingHour: h, minute: 0, second: 0, of: jour)! }

    // MARK: Le cas qu'elle a décrit

    func testPluieLeSoirEnvoieCourirLeMidi() {
        let conseil = WeatherAdvice.advise(hours: journee(pluvieuses: Array(16...21)),
                                           usual: .evening, now: a(8), calendrier: cal)
        XCTAssertEqual(conseil, WeatherAdvice.Advice(avoid: .evening, prefer: .noon))
    }

    func testPluieLeMatinEnvoieCourirLeSoir() {
        let conseil = WeatherAdvice.advise(hours: journee(pluvieuses: Array(6...11)),
                                           usual: .morning, now: a(5), calendrier: cal)
        XCTAssertEqual(conseil?.prefer, .noon, "le midi est sec ET plus proche que le soir")
    }

    // MARK: Les silences

    func testIlPleutToutLeJourDoncOnSeTait() {
        // Elle courra sous la pluie ou pas du tout. Lui écrire ne change que son humeur.
        XCTAssertNil(WeatherAdvice.advise(hours: journee(pluvieuses: Array(6...21)),
                                          usual: .evening, now: a(8), calendrier: cal))
    }

    func testUnEcartMinceNeJustifiePasUnMessage() {
        // 61 % contre 59 % : ce n'est pas un conseil, c'est du bruit.
        let hours = (6...21).map { h in
            heure(h, pluie: WeatherAdvice.Slot.evening.heures.contains(h) ? 0.61 : 0.59)
        }
        XCTAssertNil(WeatherAdvice.advise(hours: hours, usual: .evening, now: a(8), calendrier: cal))
    }

    func testUneMenaceSansUneGoutteNeSuffitPas() {
        // Probabilité haute, intensité nulle : un ciel menaçant, pas une averse. Retenue à
        // moitié, elle passe sous le seuil.
        let hours = journee(pluvieuses: Array(16...21), probabilite: 0.9, mm: 0)
        XCTAssertNil(WeatherAdvice.advise(hours: hours, usual: .evening, now: a(8), calendrier: cal))
    }

    func testTropTardPourChangerSesPlans() {
        // 16 h : le midi est passé, le matin aussi. Il ne reste rien à proposer.
        XCTAssertNil(WeatherAdvice.advise(hours: journee(pluvieuses: Array(16...21)),
                                          usual: .evening, now: a(16), calendrier: cal))
    }

    func testLeCreneauHabituelDejaPasseNeSeConseillePas() {
        XCTAssertNil(WeatherAdvice.advise(hours: journee(pluvieuses: Array(6...11)),
                                          usual: .morning, now: a(12), calendrier: cal),
                     "à midi, la séance du matin est derrière elle")
    }

    func testSansPrevisionsOnNePrometPasLeBeauTemps() {
        XCTAssertNil(WeatherAdvice.advise(hours: [], usual: .evening, now: a(8), calendrier: cal))
    }

    /// Des prévisions qui s'arrêtent avant le soir ne rendent pas le soir sec.
    func testPrevisionsIncompletesNeValentPasBeauTemps() {
        let matinSeul = (6...11).map { heure($0, pluie: 0.9, mm: 2) }
        XCTAssertNil(WeatherAdvice.advise(hours: matinSeul, usual: .morning, now: a(5), calendrier: cal),
                     "aucun créneau de repli n'est couvert : on ne peut rien conseiller")
    }

    func testJourneeSecheNeDitRien() {
        XCTAssertNil(WeatherAdvice.advise(hours: journee(pluvieuses: []),
                                          usual: .evening, now: a(8), calendrier: cal))
    }

    // MARK: Les détails de la règle

    func testLaPireHeureDecideEtNonLaMoyenne() {
        // Une seule heure d'averse au milieu du créneau le gâche : on court une fois, pas en
        // continu. Une moyenne l'aurait diluée jusqu'à la faire disparaître.
        let hours = journee(pluvieuses: [18])
        XCTAssertEqual(WeatherAdvice.pluie(surLe: .evening, hours, jour: jour, calendrier: cal), 0.9)
    }

    func testCaVarieEstTraiteCommeLeSoir() {
        XCTAssertEqual(WeatherAdvice.Slot.from("varies"), .evening)
        XCTAssertEqual(WeatherAdvice.Slot.from(nil), .evening)
        XCTAssertEqual(WeatherAdvice.Slot.from("morning"), .morning)
        XCTAssertEqual(WeatherAdvice.Slot.from("noon"), .noon)
    }

    func testAEgaliteLeCreneauLePlusProcheGagne() {
        // Matin et midi également secs, séance du soir gâchée, il est 5 h : le matin est plus
        // proche, donc plus facile à suivre.
        let hours = journee(pluvieuses: Array(16...21))
        let conseil = WeatherAdvice.advise(hours: hours, usual: .evening, now: a(5), calendrier: cal)
        XCTAssertEqual(conseil?.prefer, .morning)
    }
}
