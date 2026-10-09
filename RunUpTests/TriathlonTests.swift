import XCTest
@testable import RunUp

/// Les quatre formats, et la question de natation.
///
/// Ce qui se teste ici n'est pas du calcul : ce sont des distances fixées par les fédérations,
/// et des règles de décision. Les tests existent parce que ces nombres descendent ensuite dans
/// le volume de chaque discipline, dans la place de l'enchaînement vélo→course et dans le
/// contenu du jour J — une virgule déplacée ici produit un plan faux, en silence.
final class TriathlonTests: XCTestCase {

    // MARK: Les formats

    /// Les quatre jeux de distances, à la virgule près.
    ///
    /// Le half finit sur un semi exact et la longue distance sur un marathon exact : ce sont ces
    /// deux nombres-là qui sont le plus souvent arrondis à tort, et cent mètres de course à pied
    /// en fin de journée valent une minute debout là où elle compte le plus.
    func testLesQuatreFormatsPortentLesBonnesDistances() {
        XCTAssertEqual(TriathlonFormat.sprint.nageMetres, 750)
        XCTAssertEqual(TriathlonFormat.sprint.veloKm, 20)
        XCTAssertEqual(TriathlonFormat.sprint.courseKm, 5)

        XCTAssertEqual(TriathlonFormat.olympique.nageMetres, 1500)
        XCTAssertEqual(TriathlonFormat.olympique.veloKm, 40)
        XCTAssertEqual(TriathlonFormat.olympique.courseKm, 10)

        XCTAssertEqual(TriathlonFormat.half.nageMetres, 1900)
        XCTAssertEqual(TriathlonFormat.half.veloKm, 90)
        XCTAssertEqual(TriathlonFormat.half.courseKm, 21.0975, accuracy: 0.0001)

        XCTAssertEqual(TriathlonFormat.longueDistance.nageMetres, 3800)
        XCTAssertEqual(TriathlonFormat.longueDistance.veloKm, 180)
        XCTAssertEqual(TriathlonFormat.longueDistance.courseKm, 42.195, accuracy: 0.0001)
    }

    /// Les trois épreuves grandissent ensemble, format après format.
    ///
    /// L'invariant plutôt que douze nombres : une inversion de deux lignes dans un `switch` —
    /// le genre d'erreur qu'une relecture ne voit pas — donnerait un « half » qui nage moins
    /// qu'un sprint, et aucun test de valeur ne le dirait.
    func testChaqueFormatEstPlusLongQueLePrecedent() {
        let ordre: [TriathlonFormat] = [.sprint, .olympique, .half, .longueDistance]
        for (avant, apres) in zip(ordre, ordre.dropFirst()) {
            XCTAssertLessThan(avant.nageMetres, apres.nageMetres, "nage : \(avant) ≥ \(apres)")
            XCTAssertLessThan(avant.veloKm, apres.veloKm, "vélo : \(avant) ≥ \(apres)")
            XCTAssertLessThan(avant.courseKm, apres.courseKm, "course : \(avant) ≥ \(apres)")
            XCTAssertLessThan(avant.heuresDeffort, apres.heuresDeffort, "effort : \(avant)")
        }
        XCTAssertEqual(ordre.count, TriathlonFormat.allCases.count,
                       "un format a été ajouté sans entrer dans cet ordre")
    }

    /// Le vélo est toujours la plus longue des trois épreuves, et de loin.
    ///
    /// C'est ce qui décide de la forme du plan : la discipline qui prend le plus de temps le jour
    /// J est celle qui doit prendre le plus d'heures dans la semaine. Un plan qui l'oublierait
    /// produirait quelqu'un qui nage bien, court bien, et descend du vélo incapable de courir.
    func testLeVeloEstToujoursLaPlusLonguePartie() {
        for format in TriathlonFormat.allCases {
            XCTAssertGreaterThan(format.veloKm, format.courseKm, "\(format) : vélo ≤ course")
            XCTAssertGreaterThan(format.veloKm, Double(format.nageMetres) / 1000,
                                 "\(format) : vélo ≤ nage")
        }
    }

    /// Les temps proposés sont croissants, et il y en a de quoi choisir.
    func testLesChronosProposesSontCroissants() {
        for format in TriathlonFormat.allCases {
            let presets = format.chronoPresets
            XCTAssertGreaterThanOrEqual(presets.count, 4, "\(format) propose moins de 4 temps")
            let minutes = presets.map { p -> Int in
                let bouts = p.split(separator: ":").compactMap { Int($0) }
                return bouts.count == 2 ? bouts[0] * 60 + bouts[1] : -1
            }
            XCTAssertEqual(minutes, minutes.sorted(), "\(format) : temps non croissants")
            XCTAssertFalse(minutes.contains(-1), "\(format) : un temps est mal écrit")
        }
    }

    /// Le résumé affiché dit la natation en MÈTRES et le reste en kilomètres.
    ///
    /// C'est ce qui identifie un format sans employer de marque déposée : quelqu'un qui cherche
    /// son 70.3 reconnaît « 1900 m · 90 km · 21,1 km » sans hésiter. Et c'est la même règle
    /// d'unité que `Discipline.uniteDeSaisie` applique partout ailleurs.
    func testLeResumeDitLaNageEnMetres() {
        let resume = TriathlonFormat.olympique.resume
        XCTAssertTrue(resume.contains("1500 m"), resume)
        XCTAssertTrue(resume.contains("40 km"), resume)
        XCTAssertTrue(resume.contains("10 km"), resume)
        // Jamais « 1,5 km » : personne n'annonce une natation en kilomètres.
        XCTAssertFalse(resume.contains("1,5 km"), resume)
        XCTAssertFalse(resume.contains("1.5 km"), resume)
        // Et le zéro décimal inutile ne s'affiche pas.
        XCTAssertFalse(TriathlonFormat.sprint.resume.contains("20,0"),
                       TriathlonFormat.sprint.resume)
    }

    // MARK: Le niveau de natation

    /// « Je ne nage pas encore » n'est pas zéro mètre : c'est l'absence de repère.
    ///
    /// La différence compte, parce qu'un zéro se glisserait dans un calcul de volume comme s'il
    /// en était un — et « monter de 0 à 1500 m » est une multiplication par l'infini, pas une
    /// progression. `nil` force chaque lecteur à décider quoi faire de l'inconnu.
    func testNePasNagerEncoreNEstPasZero() {
        XCTAssertNil(NiveauDeNage.pasEncore.metresEnContinu)
        XCTAssertEqual(NiveauDeNage.moins200.metresEnContinu, 150)
        XCTAssertEqual(NiveauDeNage.jusqua800.metresEnContinu, 600)
        XCTAssertEqual(NiveauDeNage.plus1500.metresEnContinu, 1500)
    }

    /// Les niveaux sont croissants, et chacun dit quelque chose.
    func testLesNiveauxDeNageSontCroissants() {
        let connus = NiveauDeNage.allCases.compactMap(\.metresEnContinu)
        XCTAssertEqual(connus, connus.sorted(), "niveaux non croissants : \(connus)")
        XCTAssertEqual(connus.count, NiveauDeNage.allCases.count - 1,
                       "un seul niveau doit être sans repère")
        for niveau in NiveauDeNage.allCases {
            XCTAssertFalse(niveau.title.isEmpty, "\(niveau) n'a pas de libellé")
            XCTAssertFalse(niveau.subtitle.isEmpty, "\(niveau) n'a pas de sous-titre")
        }
    }

    /// L'écart est dit quand il est de ceux qui demandent un apprentissage, pas un entraînement.
    ///
    /// Un facteur trois est la frontière. En dessous, c'est une progression ordinaire sur une
    /// préparation ; au-delà, il faut un bassin, un maître-nageur et des mois.
    func testLEcartNotableEstDitQuandIlCompte() {
        // Ne pas nager du tout : l'écart est dit pour les quatre formats, sprint compris.
        for format in TriathlonFormat.allCases {
            XCTAssertTrue(NiveauDeNage.pasEncore.ecartNotable(pour: format),
                          "\(format) : l'écart n'est pas dit à qui ne nage pas")
        }
        // 1500 m en continu : rien à dire jusqu'au half.
        XCTAssertFalse(NiveauDeNage.plus1500.ecartNotable(pour: .sprint))
        XCTAssertFalse(NiveauDeNage.plus1500.ecartNotable(pour: .olympique))
        XCTAssertFalse(NiveauDeNage.plus1500.ecartNotable(pour: .half))
        // 150 m en continu et un olympique à 1500 m : dix fois plus. Ça se dit.
        XCTAssertTrue(NiveauDeNage.moins200.ecartNotable(pour: .olympique))
        // 600 m et un sprint à 750 m : une progression ordinaire. Rien à dire.
        XCTAssertFalse(NiveauDeNage.jusqua800.ecartNotable(pour: .sprint))
        // 600 m et un half à 1900 m : plus de trois fois. Ça se dit.
        XCTAssertTrue(NiveauDeNage.jusqua800.ecartNotable(pour: .half))
    }

    /// L'invariant : à niveau égal, un format plus long ne peut pas DEVENIR silencieux.
    ///
    /// Formulé plutôt qu'énuméré, pour qu'un cinquième format ou un cinquième niveau soit
    /// couvert le jour où il est écrit.
    func testUnFormatPlusLongNeDevientJamaisMoinsAlarmant() {
        let ordre: [TriathlonFormat] = [.sprint, .olympique, .half, .longueDistance]
        for niveau in NiveauDeNage.allCases {
            var dejaDit = false
            for format in ordre {
                let dit = niveau.ecartNotable(pour: format)
                if dejaDit {
                    XCTAssertTrue(dit, "\(niveau) : \(format) se tait après un format plus court")
                }
                dejaDit = dejaDit || dit
            }
        }
    }

    // MARK: L'objectif

    /// L'objectif est RETENU, et il le reste jusqu'à ce que le plan contienne les trois
    /// disciplines.
    ///
    /// Le choisir aujourd'hui donnerait un plan de course portant le nom « triathlon » : aucune
    /// natation, aucun vélo, aucune transition. Mieux vaut un objectif absent qu'un objectif qui
    /// mente.
    func testLeTriathlonNEstPasEncoreProposable() {
        XCTAssertFalse(GoalType.triathlon.estProposable)
        XCTAssertFalse(GoalType.allCases.filter(\.estProposable).contains(.triathlon))
        // Les sept autres, eux, sont bien offerts.
        XCTAssertEqual(GoalType.allCases.filter(\.estProposable).count,
                       GoalType.allCases.count - 1)
    }

    /// LE FIL À LA PATTE. Le jour où l'objectif s'ouvre, ce test échoue — et il doit échouer.
    ///
    /// `NewGoalWizardView` (l'assistant de nouvel objectif, après la fin d'un programme) liste
    /// `allCases.filter(\.estProposable)` exactement comme l'inscription. Retourner
    /// `estProposable` fera donc apparaître le triathlon dans DEUX surfaces, et l'assistant ne
    /// sait demander ni le format ni le niveau de natation : son `NewGoalResult` n'a pas ces
    /// champs. Le plan serait construit sans format.
    ///
    /// Ce test est là pour que cet oubli soit impossible : en 6/6, il faudra d'abord donner à
    /// l'assistant ses deux questions, puis supprimer ce test avec l'assertion ci-dessus.
    func testOuvrirLObjectifObligeAReprendreLAssistantDeNouvelObjectif() {
        XCTAssertFalse(
            GoalType.triathlon.estProposable,
            "Le triathlon vient d'être ouvert. `NewGoalWizardView` le propose donc aussi, "
            + "et son `NewGoalResult` ne porte ni le format ni le niveau de natation : "
            + "ajoute-les là-bas AVANT de supprimer ce test."
        )
    }

    /// Il se périodise vers une date, comme les trois autres objectifs à date.
    ///
    /// C'est l'oubli qui a coûté à l'ultra-trail son bloc spécifique et son affûtage entiers :
    /// la liste était écrite en dur dans le moteur, et un objectif absent de la liste tombait
    /// dans la branche « programme ouvert » sans qu'une ligne ne casse.
    func testLeTriathlonSePeriodiseVersUneDate() {
        XCTAssertTrue(GoalType.triathlon.periodiseVersUneDate)
        XCTAssertTrue(GoalType.race.periodiseVersUneDate)
        XCTAssertTrue(GoalType.hyrox.periodiseVersUneDate)
        XCTAssertTrue(GoalType.ultraTrail.periodiseVersUneDate)
        XCTAssertFalse(GoalType.health.periodiseVersUneDate)
    }

    /// Chaque objectif a de quoi s'afficher, le triathlon compris — même retenu.
    func testChaqueObjectifEstComplet() {
        for objectif in GoalType.allCases {
            XCTAssertFalse(objectif.title.isEmpty, "\(objectif) n'a pas de titre")
            XCTAssertFalse(objectif.subtitle.isEmpty, "\(objectif) n'a pas de sous-titre")
            XCTAssertFalse(objectif.emoji.isEmpty, "\(objectif) n'a pas d'emoji")
            XCTAssertGreaterThan(objectif.recoveryDays, 0, "\(objectif) : récup à zéro")
        }
    }
}
