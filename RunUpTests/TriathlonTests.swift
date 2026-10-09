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

    /// L'objectif est OUVERT, et les deux surfaces qui le proposent savent le construire.
    ///
    /// Il est resté retenu pendant cinq des six lots. Le fil à la patte qui tenait cette porte
    /// — un test qui exigeait `estProposable == false` tant que l'assistant de nouvel objectif
    /// ne savait pas demander le format — a fait son travail : c'est en le faisant échouer qu'on
    /// a su qu'il fallait reprendre `NewGoalWizardView`, qui liste les objectifs exactement comme
    /// l'inscription. Il est remplacé par ce qui doit rester vrai maintenant.
    func testLeTriathlonEstProposableEtConstructible() {
        XCTAssertTrue(GoalType.triathlon.estProposable)
        XCTAssertEqual(GoalType.allCases.filter(\.estProposable).count, GoalType.allCases.count,
                       "un objectif est retenu : si c'est voulu, dis-le ici")
        // Les deux champs que l'assistant doit savoir remplir. Sans eux, choisir le triathlon
        // par cette porte-là construirait un plan sans format.
        var resultat = AdaptivePlanEngine.NewGoalResult(
            goal: .triathlon, distance: nil, chrono: "2:35", raceDate: .now, runningDays: [0, 2, 4]
        )
        resultat.triathlonFormat = TriathlonFormat.olympique.rawValue
        resultat.nageNiveau = NiveauDeNage.plus1500.rawValue
        XCTAssertEqual(resultat.triathlonFormat, "olympique")
        XCTAssertEqual(resultat.nageNiveau, "plus1500")
    }

    /// Un triathlon exige TROIS jours par semaine, et pas deux.
    ///
    /// Ce n'est pas une préférence. Une semaine à deux jours ne peut pas contenir trois
    /// disciplines : il en manquerait forcément une, et ce serait la natation — la dernière dans
    /// l'ordre de priorité des séances, et celle dont l'absence ne se verrait nulle part
    /// puisque l'app ne la mesure pas.
    func testUnTriathlonExigeTroisJoursParSemaine() {
        XCTAssertEqual(GoalType.triathlon.joursMinimumParSemaine, 3)
        for objectif in GoalType.allCases where objectif != .triathlon {
            XCTAssertEqual(objectif.joursMinimumParSemaine, 2, "\(objectif)")
        }
        for objectif in GoalType.allCases {
            XCTAssertGreaterThanOrEqual(objectif.joursMinimumParSemaine, 2, "\(objectif)")
        }
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
