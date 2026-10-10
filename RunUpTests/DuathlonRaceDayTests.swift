import XCTest
@testable import RunUp

/// Le découpage de la journée d'un duathlon.
///
/// Un découpage dont les morceaux ne recomposent pas le tout est un écran qu'on relit trois
/// fois sans comprendre. C'est la première chose que ces tests gardent, et la seule qui se
/// voie : les autres — l'ordre des épreuves, les grammes, l'eau — passent inaperçues quand
/// elles sont fausses.
final class DuathlonRaceDayTests: XCTestCase {

    /// Tous les formats, sur une plage de chronos qui couvre les quatre fourchettes proposées.
    private let chronos = [40, 60, 78, 95, 156, 200, 258, 400, 612, 800]

    // MARK: Le découpage

    /// LA SOMME DES QUATRE VAUT EXACTEMENT LE TEMPS VISÉ. C'est pour ça que les transitions
    /// sont le RESTE et non une quatrième part : sinon les arrondis se voient à l'écran.
    /// Balayé de zéro à neuf cents minutes, et pas seulement sur les chronos plausibles : le
    /// défaut qui a motivé la correction du vélo n'apparaissait QUE sous trente minutes — trois
    /// arrondis qui dépassent leur total. Un écran ne l'aurait jamais montré (les totaux se
    /// taisent sous trente), et un test sur les seuls chronos réalistes non plus.
    func testLesQuatreMorceauxRecomposentLeTemps() {
        for format in DuathlonFormat.allCases {
            for minutes in 0...900 {
                let r = DuathlonRaceDay.repartition(format: format, minutesVisees: minutes)
                XCTAssertEqual(r.total, minutes, "\(format.rawValue) à \(minutes)′")
            }
        }
    }

    func testAucunMorceauNegatif() {
        for format in DuathlonFormat.allCases {
            for minutes in chronos + [0, 1, 5] {
                let r = DuathlonRaceDay.repartition(format: format, minutesVisees: minutes)
                XCTAssertGreaterThanOrEqual(r.premiereCourse, 0, "\(format.rawValue) \(minutes)′")
                XCTAssertGreaterThanOrEqual(r.velo, 0, "\(format.rawValue) \(minutes)′")
                XCTAssertGreaterThanOrEqual(r.secondeCourse, 0, "\(format.rawValue) \(minutes)′")
                XCTAssertGreaterThanOrEqual(r.transitions, 0, "\(format.rawValue) \(minutes)′")
            }
        }
    }

    /// Un temps négatif ne doit pas produire une journée négative — même garde que partout
    /// ailleurs dans ce dépôt, et pour la même raison : un champ libre finit toujours par
    /// contenir n'importe quoi.
    func testUnTempsAbsurdeNeProduitRienDAbsurde() {
        for format in DuathlonFormat.allCases {
            let r = DuathlonRaceDay.repartition(format: format, minutesVisees: -120)
            XCTAssertEqual(r.total, 0, "\(format.rawValue)")
        }
    }

    /// LE VÉLO EST TOUJOURS LA PLUS LONGUE DES TROIS ÉPREUVES, sur les quatre formats. Si ça
    /// cessait d'être vrai, la phrase de l'écran — « le vélo prend près de la moitié de la
    /// journée » — deviendrait fausse sans que rien ne le signale.
    func testLeVeloEstToujoursLaPlusLongue() {
        for format in DuathlonFormat.allCases {
            let r = DuathlonRaceDay.repartition(format: format, minutesVisees: 240)
            XCTAssertGreaterThan(r.velo, r.premiereCourse, "\(format.rawValue)")
            XCTAssertGreaterThan(r.velo, r.secondeCourse, "\(format.rawValue)")
        }
    }

    /// Les parts somment à moins de 1 : ce qui reste EST la part des transitions, et elle doit
    /// être strictement positive — une journée sans transition n'est pas un duathlon.
    func testLesTransitionsExistentToujours() {
        for format in DuathlonFormat.allCases {
            let p = DuathlonRaceDay.parts(format)
            let reste = 1 - p.premiere - p.velo - p.seconde
            XCTAssertGreaterThan(reste, 0, "\(format.rawValue) : parts à \(p)")
            // Et jamais plus de cinq pour cent : c'est le constat qui a fait renoncer à
            // recopier `transitionsDecisives` du triathlon.
            XCTAssertLessThan(reste, 0.05, "\(format.rawValue) : transitions à \(reste)")
        }
    }

    // MARK: Ce que le format dit de la journée

    func testLaSecondeCourseEstPlusLongueSurLesFormatsLongs() {
        XCTAssertFalse(DuathlonRaceDay.secondeCourseAuMoinsAussiLongue(.sprint))
        XCTAssertFalse(DuathlonRaceDay.secondeCourseAuMoinsAussiLongue(.standard))
        XCTAssertTrue(DuathlonRaceDay.secondeCourseAuMoinsAussiLongue(.moyenneDistance))
        XCTAssertTrue(DuathlonRaceDay.secondeCourseAuMoinsAussiLongue(.longueDistance))
    }

    /// La réponse doit découler des DISTANCES et non d'une liste écrite à côté, sans quoi les
    /// deux diraient un jour deux choses différentes.
    func testLaReponseDecouleDesDistances() {
        for format in DuathlonFormat.allCases {
            XCTAssertEqual(DuathlonRaceDay.secondeCourseAuMoinsAussiLongue(format),
                           format.secondeCourseKm >= format.premiereCourseKm,
                           "\(format.rawValue)")
        }
    }

    // MARK: Le ravitaillement

    /// LA FENÊTRE EST LE VÉLO, plus la moitié de la seconde course. Pas la journée : la
    /// première course se fait à vide, et après le vélo l'estomac refuse presque tout.
    func testLesGlucidesSeComptentSurLaFenetreEtPasSurLaJournee() {
        for format in DuathlonFormat.allCases {
            let r = DuathlonRaceDay.repartition(format: format, minutesVisees: 240)
            let g = DuathlonRaceDay.glucidesSurLeVelo(r)
            let heuresFenetre = (Double(r.velo) + Double(r.secondeCourse) / 2) / 60
            let heuresJournee = Double(r.total) / 60
            XCTAssertEqual(Double(g.min), heuresFenetre * Double(UltraRaceDay.glucidesParHeureMin),
                           accuracy: 1, "\(format.rawValue)")
            XCTAssertLessThan(Double(g.max),
                              heuresJournee * Double(UltraRaceDay.glucidesParHeureMax),
                              "\(format.rawValue) : compté sur la journée entière")
        }
    }

    func testLaFourchetteDeGlucidesEstCroissante() {
        for format in DuathlonFormat.allCases {
            let r = DuathlonRaceDay.repartition(format: format, minutesVisees: 240)
            let g = DuathlonRaceDay.glucidesSurLeVelo(r)
            XCTAssertLessThan(g.min, g.max, "\(format.rawValue)")
        }
    }

    /// L'eau s'arrondit aux cent millilitres — un bidon ne se remplit pas au millilitre près.
    func testLEauEstArrondieAuxCentMillilitres() {
        for format in DuathlonFormat.allCases {
            for minutes in chronos {
                let r = DuathlonRaceDay.repartition(format: format, minutesVisees: minutes)
                let e = DuathlonRaceDay.eauSurLeVelo(r)
                XCTAssertEqual(e.min % 100, 0, "\(format.rawValue) \(minutes)′ : \(e.min)")
                XCTAssertEqual(e.max % 100, 0, "\(format.rawValue) \(minutes)′ : \(e.max)")
                XCTAssertLessThanOrEqual(e.min, e.max, "\(format.rawValue) \(minutes)′")
            }
        }
    }

    /// Les trois épreuves partagent leurs grammes par heure, et c'est voulu : la physiologie de
    /// l'endurance ne change pas parce qu'on change de sport. Trois copies en auraient trois
    /// versions au premier ajustement.
    func testLesGrammesParHeureViennentDUnSeulEndroit() {
        let r = DuathlonRaceDay.repartition(format: .standard, minutesVisees: 156)
        let heures = (Double(r.velo) + Double(r.secondeCourse) / 2) / 60
        XCTAssertEqual(DuathlonRaceDay.glucidesSurLeVelo(r).min,
                       Int((heures * Double(UltraRaceDay.glucidesParHeureMin)).rounded()))
    }
}
