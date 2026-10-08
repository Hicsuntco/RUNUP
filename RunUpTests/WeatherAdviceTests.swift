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

    // MARK: - De quel jour parle-t-on

    private var demain: Date { cal.date(byAdding: .day, value: 1, to: jour)! }

    private func heure(_ h: Int, le j: Date, pluie: Double, mm: Double = 1.0) -> WeatherAdvice.Hour {
        WeatherAdvice.Hour(date: cal.date(bySettingHour: h, minute: 0, second: 0, of: j)!,
                           precipitationChance: pluie, precipitationIntensity: mm)
    }

    /// Une journée donnée : sèche partout sauf aux heures nommées.
    private func journee(_ j: Date, pluvieuses: [Int], probabilite: Double = 0.9,
                         mm: Double = 2.0) -> [WeatherAdvice.Hour] {
        (6...21).map { h in
            pluvieuses.contains(h) ? heure(h, le: j, pluie: probabilite, mm: mm)
                                   : heure(h, le: j, pluie: 0.05)
        }
    }

    /// Le repère n'est pas l'heure qu'il est, c'est l'heure à laquelle ELLE court. Pour une
    /// coureuse du soir, le basculement vers demain a lieu à 17 h.
    func testLeConseilPasseADemainQuandLeCreneauDuJourEstEntame() {
        let avant = WeatherAdvice.jourAConseiller(usual: .evening, now: a(8), calendrier: cal)
        XCTAssertTrue(cal.isDate(avant, inSameDayAs: jour), "à 8 h, le soir est encore devant")

        let apres = WeatherAdvice.jourAConseiller(usual: .evening, now: a(19), calendrier: cal)
        XCTAssertTrue(cal.isDate(apres, inSameDayAs: demain), "à 19 h, c'est de demain soir qu'il faut parler")
    }

    /// Et pour une coureuse du matin il a lieu à 7 h — donc elle apprend la météo de demain matin
    /// dès la fin de sa séance, soit près de vingt-quatre heures de préavis. Une heure butoir fixe
    /// aurait été fausse pour l'une comme pour l'autre.
    func testLeBasculementSuitLHeureALaquelleElleCourt() {
        XCTAssertTrue(cal.isDate(WeatherAdvice.jourAConseiller(usual: .morning, now: a(6), calendrier: cal),
                                 inSameDayAs: jour))
        XCTAssertTrue(cal.isDate(WeatherAdvice.jourAConseiller(usual: .morning, now: a(11), calendrier: cal),
                                 inSameDayAs: demain))
    }

    // MARK: - Conseiller demain

    /// LE CAS QU'ELLE A DEMANDÉ : à 20 h, savoir qu'il pleuvra demain soir et qu'il faut viser
    /// demain midi.
    func testOnPeutConseillerDemainDepuisCeSoir() {
        let previsions = journee(demain, pluvieuses: Array(6...10) + Array(16...21))
        let conseil = WeatherAdvice.advise(hours: previsions, usual: .evening,
                                           now: a(20), jour: demain, calendrier: cal)
        XCTAssertEqual(conseil, WeatherAdvice.Advice(avoid: .evening, prefer: .noon))
    }

    /// Le préavis se mesure depuis maintenant, donc un conseil pour demain le satisfait d'office —
    /// même pour un créneau qui, aujourd'hui, serait déjà trop proche.
    func testLePreavisNeBloqueJamaisUnConseilPourDemain() {
        let previsions = journee(demain, pluvieuses: Array(6...10) + Array(16...21))
        XCTAssertNotNil(WeatherAdvice.advise(hours: previsions, usual: .evening,
                                             now: a(23), jour: demain, calendrier: cal))
    }

    /// Une pluie AUJOURD'HUI ne dit rien de demain. Sans le jour en paramètre, les heures des deux
    /// journées se mélangeaient et la réponse aurait été fausse.
    func testLaPluieDAujourdhuiNeConcernePasDemain() {
        let previsions = journee(jour, pluvieuses: Array(16...21)) + journee(demain, pluvieuses: [])
        XCTAssertNil(WeatherAdvice.advise(hours: previsions, usual: .evening,
                                          now: a(8), jour: demain, calendrier: cal))
    }

    // MARK: - Rectifier ce qu'on a annoncé

    private let pluieDuSoir = WeatherAdvice.Advice(avoid: .evening, prefer: .noon)
    private let pluieDuSoirVersLeMatin = WeatherAdvice.Advice(avoid: .evening, prefer: .morning)

    private func annonce(_ previsions: [WeatherAdvice.Hour],
                         dejaDit: WeatherAdvice.DejaDit,
                         a heure: Int = 8) -> WeatherAdvice.Annonce? {
        WeatherAdvice.annonce(pour: jour, hours: previsions, usual: .evening,
                              dejaDit: dejaDit, now: a(heure), calendrier: cal)
    }

    func testRienDitEncoreEtIlPleutDoncOnConseille() {
        let resultat = annonce(journee(jour, pluvieuses: Array(6...10) + Array(16...21)),
                               dejaDit: WeatherAdvice.DejaDit())
        XCTAssertEqual(resultat, .conseil(pluieDuSoir))
    }

    /// Le même conseil deux fois est exactement le bruit qui fait couper l'interrupteur.
    func testLeMemeConseilNeSeRepetePas() {
        let resultat = annonce(journee(jour, pluvieuses: Array(6...10) + Array(16...21)),
                               dejaDit: .init(jour: jour, conseil: pluieDuSoir))
        XCTAssertNil(resultat)
    }

    /// LA RECTIFICATION, qui est tout l'intérêt d'un conseil donné la veille : on avait envoyé à
    /// midi, midi est devenu mauvais, il faut le dire.
    ///
    /// Interrogé à 4 h et non à 8 h, et la raison vaut d'être notée : à 8 h, le créneau du matin
    /// commence à 7 h, donc il est DÉJÀ PASSÉ et le préavis l'écarte. Le seul candidat restant
    /// serait midi — devenu pluvieux — et la règle se tairait, à juste titre. Pour qu'une
    /// rectification ait un sens, il faut qu'il reste un créneau vers lequel rectifier.
    func testUnConseilQuiNEstPlusLeBonSeRectifie() {
        let resultat = annonce(journee(jour, pluvieuses: Array(12...21)),
                               dejaDit: .init(jour: jour, conseil: pluieDuSoir), a: 4)
        XCTAssertEqual(resultat, .rectification(pluieDuSoirVersLeMatin))
    }

    /// Et la pluie annoncée qui n'arrive pas se dément. C'est le message qui protège
    /// l'interrupteur : elle apprend que l'app sait aussi dire qu'elle s'était trompée.
    func testUnePluieQuiDisparaitSeDement() {
        let resultat = annonce(journee(jour, pluvieuses: []),
                               dejaDit: .init(jour: jour, conseil: pluieDuSoir))
        XCTAssertEqual(resultat, .annulation(.evening))
    }

    /// Une seule rectification par jour. Une prévision à vingt heures d'échéance hésite, et quatre
    /// messages contradictoires valent moins que zéro.
    func testOnNeRectifieQuUneFoisParJour() {
        let dejaDit = WeatherAdvice.DejaDit(jour: jour, conseil: pluieDuSoir, rectifiee: true)
        XCTAssertNil(annonce(journee(jour, pluvieuses: Array(12...21)), dejaDit: dejaDit, a: 4))
        XCTAssertNil(annonce(journee(jour, pluvieuses: []), dejaDit: dejaDit))
    }

    /// « On a regardé, il n'y avait rien à dire » n'est pas la même chose que « on n'a rien
    /// regardé » : si la pluie arrive ensuite, c'est un premier conseil, pas une rectification —
    /// et ça ne consomme donc pas l'unique rectification du jour.
    func testAvoirRegardeSansRienTrouverNEmpechePasDeConseillerEnsuite() {
        let dejaDit = WeatherAdvice.DejaDit(jour: jour, conseil: nil, rectifiee: false)
        let resultat = annonce(journee(jour, pluvieuses: Array(6...10) + Array(16...21)),
                               dejaDit: dejaDit)
        XCTAssertEqual(resultat, .conseil(pluieDuSoir))
    }

    /// Un jour neuf repart de zéro, rectification comprise : ce qu'on a dit hier ne limite pas ce
    /// qu'on peut dire aujourd'hui.
    func testUnJourNeufEffaceCeQuOnADitLaVeille() {
        let hier = cal.date(byAdding: .day, value: -1, to: jour)!
        let dejaDit = WeatherAdvice.DejaDit(jour: hier, conseil: pluieDuSoirVersLeMatin, rectifiee: true)
        let resultat = annonce(journee(jour, pluvieuses: Array(6...10) + Array(16...21)),
                               dejaDit: dejaDit)
        XCTAssertEqual(resultat, .conseil(pluieDuSoir))
    }

    // MARK: - Ce qu'on retient

    func testOnRetientAvoirRegardeUnJourNeufMemeSansRienDire() {
        let memoire = WeatherAdvice.memoire(apres: nil, pour: jour,
                                            dejaDit: WeatherAdvice.DejaDit(), calendrier: cal)
        XCTAssertEqual(memoire, WeatherAdvice.DejaDit(jour: jour, conseil: nil, rectifiee: false))
    }

    /// Et surtout : ne rien dire sur un jour DÉJÀ connu n'efface pas ce qu'on y avait annoncé.
    /// L'écraser rendrait la rectification impossible — on ne saurait plus qu'on avait promis
    /// de la pluie.
    func testNeRienDireNEffacePasLeConseilEnMemoire() {
        let dejaDit = WeatherAdvice.DejaDit(jour: jour, conseil: pluieDuSoir, rectifiee: false)
        XCTAssertEqual(WeatherAdvice.memoire(apres: nil, pour: jour, dejaDit: dejaDit, calendrier: cal),
                       dejaDit)
    }

    func testUneRectificationConsommeLUniqueRectification() {
        let memoire = WeatherAdvice.memoire(apres: .rectification(pluieDuSoirVersLeMatin),
                                             pour: jour,
                                             dejaDit: .init(jour: jour, conseil: pluieDuSoir),
                                             calendrier: cal)
        XCTAssertEqual(memoire, WeatherAdvice.DejaDit(jour: jour, conseil: pluieDuSoirVersLeMatin,
                                                      rectifiee: true))
    }

    func testUnDementiEffaceLeConseilEtConsommeLaRectification() {
        let memoire = WeatherAdvice.memoire(apres: .annulation(.evening), pour: jour,
                                             dejaDit: .init(jour: jour, conseil: pluieDuSoir),
                                             calendrier: cal)
        XCTAssertEqual(memoire, WeatherAdvice.DejaDit(jour: jour, conseil: nil, rectifiee: true))
    }

    func testUnConseilNeConsommePasLaRectification() {
        let memoire = WeatherAdvice.memoire(apres: .conseil(pluieDuSoir), pour: jour,
                                             dejaDit: WeatherAdvice.DejaDit(), calendrier: cal)
        XCTAssertEqual(memoire, WeatherAdvice.DejaDit(jour: jour, conseil: pluieDuSoir,
                                                      rectifiee: false))
    }
}
