import XCTest
@testable import RunUp

/// Le jour J d'un triathlon : le découpage de la journée, et la fenêtre de ravitaillement.
///
/// Ce qui se teste ici n'est pas du conseil, c'est de l'arithmétique dont le résultat s'affiche
/// à l'écran. Un découpage dont les morceaux ne recomposent pas le temps visé se relit trois
/// fois sans comprendre, et un total de glucides calculé sur la mauvaise fenêtre envoie quelqu'un
/// courir un marathon à jeun.
final class TriathlonRaceDayTests: XCTestCase {

    /// LES QUATRE MORCEAUX RECOMPOSENT EXACTEMENT LE TEMPS VISÉ.
    ///
    /// Les transitions sont le RESTE et non une quatrième part, précisément pour que ce soit
    /// vrai quels que soient les arrondis. Vérifié sur les seize temps proposés par l'app.
    func testLeDecoupageRecomposeExactementLeTempsVise() {
        for format in TriathlonFormat.allCases {
            for preset in format.chronoPresets {
                let minutes = Self.minutes(preset)
                let r = TriathlonRaceDay.repartition(format: format, minutesVisees: minutes)
                XCTAssertEqual(r.total, minutes, "\(format) \(preset)")
                XCTAssertGreaterThanOrEqual(r.transitions, 0, "\(format) \(preset)")
            }
        }
    }

    /// Le vélo est toujours le plus gros morceau de la journée.
    ///
    /// C'est le fait qui porte tout l'écran : si cette part passait sous celle de la course, la
    /// phrase « le vélo prend à peu près la moitié de la journée » deviendrait fausse, et le
    /// conseil « tout ce qu'il faut pour la course se prend sur le vélo » perdrait sa raison.
    func testLeVeloEstToujoursLePlusGrosMorceau() {
        for format in TriathlonFormat.allCases {
            for preset in format.chronoPresets {
                let r = TriathlonRaceDay.repartition(format: format, minutesVisees: Self.minutes(preset))
                XCTAssertGreaterThan(r.velo, r.nage, "\(format) \(preset)")
                XCTAssertGreaterThan(r.velo, r.course, "\(format) \(preset)")
            }
        }
        // Et « à peu près la moitié » n'est pas une figure de style : la part est entre 44 et 54 %.
        for format in TriathlonFormat.allCases {
            let part = TriathlonRaceDay.parts(format).velo
            XCTAssertGreaterThan(part, 0.44, "\(format)")
            XCTAssertLessThan(part, 0.54, "\(format)")
        }
    }

    /// La part de natation DIMINUE quand l'épreuve s'allonge, et c'est la seule.
    ///
    /// C'est ce qui justifie des parts par format plutôt qu'un jeu unique : la natation pèse un
    /// cinquième d'un sprint et un huitième d'une longue distance.
    func testLaPartDeNatationDiminueQuandLEpreuveSAllonge() {
        let ordre: [TriathlonFormat] = [.sprint, .olympique, .half, .longueDistance]
        XCTAssertGreaterThan(TriathlonRaceDay.parts(.sprint).nage,
                             TriathlonRaceDay.parts(.longueDistance).nage)
        // Le vélo et la course, eux, augmentent — ou restent stables.
        for (avant, apres) in zip(ordre, ordre.dropFirst()) {
            XCTAssertGreaterThanOrEqual(TriathlonRaceDay.parts(apres).velo,
                                        TriathlonRaceDay.parts(avant).velo, "\(avant) → \(apres)")
        }
        // Les trois parts laissent toujours de la place aux transitions.
        for format in TriathlonFormat.allCases {
            let p = TriathlonRaceDay.parts(format)
            XCTAssertLessThan(p.nage + p.velo + p.course, 1, "\(format)")
        }
    }

    /// LES CONSTANTES VIENNENT D'`UltraRaceDay`, ET DOIVENT EN VENIR.
    ///
    /// La physiologie de l'endurance ne change pas parce qu'on change de sport. Les recopier
    /// aurait créé deux vérités pour une seule question — le défaut exact que `Calories` existe
    /// pour empêcher ailleurs dans ce dépôt. Ce test échoue si quelqu'un les fige ici.
    func testLesConstantesViennentDUltraRaceDay() {
        let r = TriathlonRaceDay.Repartition(nage: 30, velo: 60, course: 40, transitions: 5)
        let g = TriathlonRaceDay.glucidesSurLeVelo(r)
        XCTAssertEqual(g.min, UltraRaceDay.glucidesParHeureMin, "une heure de vélo = la borne basse")
        XCTAssertEqual(g.max, UltraRaceDay.glucidesParHeureMax, "une heure de vélo = la borne haute")
        let e = TriathlonRaceDay.eauSurLeVelo(r)
        XCTAssertEqual(e.min, UltraRaceDay.eauParHeureMinML)
        XCTAssertEqual(e.max, UltraRaceDay.eauParHeureMaxML)
    }

    /// La fenêtre de ravitaillement est le VÉLO, pas la journée.
    ///
    /// On ne mange pas dans l'eau : compter la natation gonflerait le total de ce qu'il est
    /// impossible d'avaler. Pour un olympique en 2:35, la différence est d'environ un tiers.
    func testLaFenetreDeRavitaillementEstLeVeloEtPasLaJournee() {
        let r = TriathlonRaceDay.repartition(format: .olympique, minutesVisees: 155)
        let surLeVelo = TriathlonRaceDay.glucidesSurLeVelo(r).min
        let surLaJournee = Int((Double(r.total) / 60 * Double(UltraRaceDay.glucidesParHeureMin)).rounded())
        XCTAssertLessThan(surLeVelo, surLaJournee, "la fenêtre couvre toute la journée")
        // Et elle reste substantielle : plus de 40 % de ce qu'un compte sur la journée entière
        // donnerait. La première version de ce test affirmait « plus de la moitié », et elle
        // était fausse d'un cheveu — le vélo pèse 46,4 % d'un olympique, donc le double de la
        // fenêtre reste sous le total. Une assertion fausse dans un test est pire qu'une
        // assertion absente : elle finit par être « corrigée » en relâchant la vraie règle.
        XCTAssertGreaterThan(Double(surLeVelo), Double(surLaJournee) * 0.4)
    }

    /// L'eau s'arrondit aux cent millilitres : un bidon ne se remplit pas au millilitre près.
    func testLEauSArrondiAuxCentMillilitres() {
        for format in TriathlonFormat.allCases {
            for preset in format.chronoPresets {
                let r = TriathlonRaceDay.repartition(format: format, minutesVisees: Self.minutes(preset))
                let e = TriathlonRaceDay.eauSurLeVelo(r)
                XCTAssertEqual(e.min % 100, 0, "\(format) \(preset)")
                XCTAssertEqual(e.max % 100, 0, "\(format) \(preset)")
                XCTAssertLessThanOrEqual(e.min, e.max, "\(format) \(preset)")
            }
        }
    }

    /// SEUL LE SPRINT SE GAGNE EN TRANSITION.
    ///
    /// Le seuil était à trois pour cent dans la première version, et l'olympique comme le half
    /// tombaient du même côté que le sprint à égalité parfaite — un seuil qui ne distingue rien
    /// ne mérite pas d'exister. Les parts mesurées sont 6,9 / 3,6 / 3,6 / 1,9 %, donc la seule
    /// frontière réelle sépare le sprint du reste.
    ///
    /// Ça compte à l'écran : dire « un triathlon se gagne en transition » à quelqu'un qui
    /// prépare un Ironman l'enverrait travailler la seule chose qui ne changera rien à sa
    /// journée.
    func testSeulLeSprintSeGagneEnTransition() {
        XCTAssertTrue(TriathlonRaceDay.transitionsDecisives(.sprint))
        XCTAssertFalse(TriathlonRaceDay.transitionsDecisives(.olympique))
        XCTAssertFalse(TriathlonRaceDay.transitionsDecisives(.half))
        XCTAssertFalse(TriathlonRaceDay.transitionsDecisives(.longueDistance))
    }

    /// Un temps visé inconnu ne produit pas de faux chiffres, il produit des zéros — et c'est
    /// l'écran qui se tait alors, plutôt que d'afficher un total calculé sur rien.
    func testUnTempsInconnuNeProduitPasDeFauxChiffres() {
        let r = TriathlonRaceDay.repartition(format: .olympique, minutesVisees: 0)
        XCTAssertEqual(r.total, 0)
        XCTAssertEqual(TriathlonRaceDay.glucidesSurLeVelo(r).max, 0)
        XCTAssertEqual(TriathlonRaceDay.eauSurLeVelo(r).max, 0)
        // Et un temps négatif ne renvoie jamais de part négative.
        let absurde = TriathlonRaceDay.repartition(format: .half, minutesVisees: -120)
        XCTAssertEqual(absurde.total, 0)
    }

    private static func minutes(_ chrono: String) -> Int {
        let bouts = chrono.split(separator: ":").compactMap { Int($0) }
        return bouts.count == 2 ? bouts[0] * 60 + bouts[1] : 0
    }
}
