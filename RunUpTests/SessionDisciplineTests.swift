import XCTest
@testable import RunUp

/// Ce dont une séance est faite, et ce qui la coche.
///
/// # L'HYPOTHÈSE QUE CES TESTS RENDENT EXPLICITE
///
/// Le plan de cette app a toujours été un plan de course : aucune séance n'avait à dire sa
/// discipline, il n'y en avait qu'une. Le triathlon met trois disciplines dans la même semaine,
/// et « la séance du jour » n'est plus forcément une course. `SessionKind.disciplines` est
/// l'endroit où chaque séance le dit enfin, et `estCompleteePar(_:)` est ce qui décide si une
/// sortie enregistrée coche cette journée.
///
/// Les deux ne disent PAS la même chose, et c'est tout l'objet de ce fichier.
final class SessionDisciplineTests: XCTestCase {

    /// Chaque séance dit de quoi elle est faite, et le repos ne dit rien.
    func testChaqueSeanceDitSaDiscipline() {
        for kind in SessionKind.allCases where kind != .rest {
            XCTAssertFalse(kind.disciplines.isEmpty, "\(kind.rawValue) ne dit aucune discipline")
        }
        XCTAssertTrue(SessionKind.rest.disciplines.isEmpty)
    }

    /// La natation apparaît dans le vocabulaire du plan. C'était la demande.
    ///
    /// Jusqu'ici aucune séance de cette app ne pouvait être une nage : le plan ne savait
    /// prescrire que de la course. Cinq séances de bassin existent maintenant, et le test les
    /// compte plutôt que de les nommer une par une.
    func testLaNatationExisteDansLePlan() {
        let nages = SessionKind.allCases.filter { $0.disciplines == [.swim] }
        XCTAssertGreaterThanOrEqual(nages.count, 4, "trop peu de séances de natation : \(nages)")
        XCTAssertTrue(nages.contains(.triSwimEndurance))
        XCTAssertTrue(nages.contains(.triOpenWater))
        // Et il existe une séance pour qui ne nage pas encore — sans elle, le plan n'aurait
        // rien à proposer à la réponse la plus fragile de l'inscription.
        XCTAssertTrue(nages.contains(.triSwimLearn))
    }

    /// Le vélo aussi, et il est prescrit — pas seulement enregistrable.
    func testLeVeloEstPrescritEtPasSeulementEnregistrable() {
        let velos = SessionKind.allCases.filter { $0.disciplines == [.bike] }
        XCTAssertGreaterThanOrEqual(velos.count, 2, "trop peu de séances de vélo : \(velos)")
    }

    /// L'ENCHAÎNEMENT PORTE SES DEUX DISCIPLINES, DANS L'ORDRE.
    ///
    /// `[.bike, .run]` et jamais l'inverse : tout le sens de la séance est là. Réduire un
    /// enchaînement à l'une de ses deux moitiés serait écrire la moitié de la séance.
    func testLEnchainementPorteSesDeuxDisciplinesDansLOrdre() {
        XCTAssertEqual(SessionKind.triBrick.disciplines, [.bike, .run])
        XCTAssertEqual(SessionKind.triBrickRace.disciplines, [.bike, .run])
        XCTAssertEqual(SessionKind.triTransitions.disciplines, [.bike, .run])
    }

    /// Les séances d'ultra sont du trail, et le disent enfin.
    func testLesSeancesDUltraSontDuTrail() {
        for kind in SessionKind.allCases where kind.rawValue.hasPrefix("ultra_") {
            XCTAssertEqual(kind.disciplines, [.trail], "\(kind.rawValue) n'est pas du trail")
        }
    }

    // MARK: Ce qui coche une journée

    /// COURIR COCHE UNE SÉANCE DE TRAIL, ET INVERSEMENT.
    ///
    /// Le cas que `disciplines.contains(_:)` tout seul aurait cassé : une préparation d'ultra se
    /// fait en grande partie sur route — c'est ce que fait tout le monde en semaine. Un
    /// `contains` strict aurait laissé « à faire » une journée faite, et le moteur aurait adapté
    /// la semaine suivante sur une séance qui a bien eu lieu.
    func testCourirCocheUneSeanceDeTrailEtInversement() {
        XCTAssertTrue(SessionKind.ultraLongRun.estCompleteePar(.run))
        XCTAssertTrue(SessionKind.ultraHillRepeats.estCompleteePar(.trail))
        XCTAssertTrue(SessionKind.longRun.estCompleteePar(.trail))
        XCTAssertTrue(SessionKind.easyFooting.estCompleteePar(.run))
    }

    /// Nager ne coche pas une séance de course, et rouler non plus.
    ///
    /// C'est la règle que `Discipline.completesRunningPlan` portait, généralisée : elle part
    /// désormais de la SÉANCE, parce que « est-ce que ça coche le plan de course » n'a plus de
    /// sens dans un plan qui contient trois disciplines.
    func testNagerOuRoulerNeCochePasUneSeanceDeCourse() {
        for kind in [SessionKind.easyFooting, .longRun, .vo2maxIntervals, .ultraLongRun] {
            XCTAssertFalse(kind.estCompleteePar(.swim), "\(kind.rawValue) cochée en nageant")
            XCTAssertFalse(kind.estCompleteePar(.bike), "\(kind.rawValue) cochée à vélo")
        }
    }

    /// Et une séance de natation ne se coche qu'en nageant.
    func testUneSeanceDeNatationNeSeCocheQuEnNageant() {
        for kind in SessionKind.allCases where kind.disciplines == [.swim] {
            XCTAssertTrue(kind.estCompleteePar(.swim), "\(kind.rawValue)")
            XCTAssertFalse(kind.estCompleteePar(.run), "\(kind.rawValue) cochée en courant")
            XCTAssertFalse(kind.estCompleteePar(.trail), "\(kind.rawValue) cochée en trail")
            XCTAssertFalse(kind.estCompleteePar(.bike), "\(kind.rawValue) cochée à vélo")
        }
    }

    /// Une séance de vélo ne se coche qu'à vélo.
    func testUneSeanceDeVeloNeSeCocheQuAVelo() {
        for kind in SessionKind.allCases where kind.disciplines == [.bike] {
            XCTAssertTrue(kind.estCompleteePar(.bike), "\(kind.rawValue)")
            XCTAssertFalse(kind.estCompleteePar(.swim), "\(kind.rawValue) cochée en nageant")
            XCTAssertFalse(kind.estCompleteePar(.run), "\(kind.rawValue) cochée en courant")
        }
    }

    /// L'enchaînement se coche par l'une ou l'autre de ses moitiés, et pas en nageant.
    ///
    /// Exiger les deux laisserait la case vide pour quelqu'un qui a fait la séance et n'a
    /// enregistré qu'une sortie — le cas ordinaire, puisque l'app ne sait pas enregistrer deux
    /// disciplines dans un même relevé. Mieux vaut une case cochée pour une séance faite aux
    /// trois quarts qu'une case vide pour une séance faite.
    func testLEnchainementSeCocheParLUneOuLAutreDeSesMoities() {
        XCTAssertTrue(SessionKind.triBrick.estCompleteePar(.bike))
        XCTAssertTrue(SessionKind.triBrick.estCompleteePar(.run))
        // Le trail aussi : c'est une discipline chaussée, et courir en sentier après le vélo
        // reste un enchaînement.
        XCTAssertTrue(SessionKind.triBrick.estCompleteePar(.trail))
        XCTAssertFalse(SessionKind.triBrick.estCompleteePar(.swim))
    }

    /// Le repos ne se coche par rien. Une journée de repos n'a pas de séance à valider.
    func testLeReposNeSeCocheParRien() {
        for discipline in Discipline.allCases {
            XCTAssertFalse(SessionKind.rest.estCompleteePar(discipline), "\(discipline)")
        }
    }

    /// L'INVARIANT GÉNÉRAL : une discipline non chaussée ne coche que ce qui est exactement elle.
    ///
    /// Formulé plutôt qu'énuméré, pour qu'une cinquième discipline ou une cinquante-quatrième
    /// séance soient couvertes le jour où elles sont écrites.
    func testUneDisciplineNonChausseeNeCocheQueCeQuiEstElle() {
        for kind in SessionKind.allCases {
            for discipline in Discipline.allCases where !discipline.wearsShoes {
                XCTAssertEqual(kind.estCompleteePar(discipline),
                               kind.disciplines.contains(discipline),
                               "\(kind.rawValue) / \(discipline)")
            }
        }
    }

    /// Et l'autre moitié : une discipline chaussée coche exactement les séances chaussées.
    func testUneDisciplineChausseeCocheLesSeancesChaussees() {
        for kind in SessionKind.allCases {
            let chaussee = kind.disciplines.contains { $0.wearsShoes }
            for discipline in Discipline.allCases where discipline.wearsShoes {
                XCTAssertEqual(kind.estCompleteePar(discipline), chaussee,
                               "\(kind.rawValue) / \(discipline)")
            }
        }
    }

    // MARK: La cohérence avec le reste du modèle

    /// Le fractionné en bassin est bien classé des deux côtés.
    ///
    /// `SessionFamilyTests` vérifie l'invariant `family == .intervals ⇔ isIntervalWorkout` pour
    /// tous les types ; celui-ci dit explicitement que la nage fractionnée y répond, parce que
    /// c'est le premier type en répétitions de toute l'app qui ne se mesure pas au GPS.
    func testLeFractionneEnBassinEstClasseDesDeuxCotes() {
        XCTAssertEqual(SessionKind.triSwimIntervals.family, .intervals)
        XCTAssertTrue(SessionKind.triSwimIntervals.isIntervalWorkout)
    }

    /// Aucune séance de natation ni de vélo ne réclame d'allure de course à pied.
    ///
    /// `followsPaceTargets` est faux pour les deux disciplines, donc une voix qui annoncerait
    /// « tu es trop lente » n'a aucune cible à laquelle se référer — et de toute façon personne
    /// ne porte un écouteur dans un bassin.
    func testAucuneSeanceHorsCourseNeReclameDAllure() {
        for kind in SessionKind.allCases {
            let horsCourse = !kind.disciplines.isEmpty && !kind.disciplines.contains { $0.wearsShoes }
            guard horsCourse else { continue }
            for discipline in kind.disciplines {
                XCTAssertFalse(discipline.followsPaceTargets, "\(kind.rawValue) / \(discipline)")
            }
        }
    }
}
