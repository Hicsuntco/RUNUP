import XCTest
@testable import RunUp

/// Verrouille la classification des séances en familles — celle qui porte la couleur du plan.
///
/// Une couleur qui ment coûte plus cher qu'une couleur absente : elle est lue d'un coup d'œil,
/// sans vérification, et c'est précisément ce qu'on lui demande. Le `switch` de `SessionKind.family`
/// est exhaustif, donc le compilateur empêche déjà d'OUBLIER un type de séance ; ces tests
/// empêchent de le classer contre les règles que l'app applique déjà ailleurs.
final class SessionFamilyTests: XCTestCase {

    /// La règle qui compte : `.intervals` doit reprendre EXACTEMENT `isIntervalWorkout`.
    ///
    /// Les deux classifications vivent côte à côte — l'une pilote le guidage segment par segment
    /// de l'écran Live et le détail de séance, l'autre la couleur. Si elles divergent, une séance
    /// s'affiche en rouge « fractionné » dans le plan et se déroule en effort continu pendant la
    /// course, ou l'inverse. Le désaccord serait invisible en lecture de code, chacune étant
    /// défendable isolément.
    func testIntervalFamilyMatchesTheIntervalClassificationUsedElsewhere() {
        for kind in SessionKind.allCases {
            XCTAssertEqual(
                kind.family == .intervals, kind.isIntervalWorkout,
                "\(kind.rawValue) : famille et isIntervalWorkout ne s'accordent pas"
            )
        }
    }

    /// Le repos est un état, pas un entraînement : lui seul appartient à `.rest`.
    func testOnlyRestIsRest() {
        for kind in SessionKind.allCases {
            XCTAssertEqual(kind.family == .rest, kind == .rest, "\(kind.rawValue)")
        }
    }

    /// Aucune famille ne doit rester vide.
    ///
    /// Une famille sans séance est une couleur inventée : elle occupe une place dans la palette,
    /// personne ne la voit jamais, et elle laisse croire que le vocabulaire est plus riche qu'il
    /// ne l'est. Si un jour une famille se vide, c'est le signe qu'il faut la retirer.
    func testEveryFamilyHasAtLeastOneSession() {
        let used = Set(SessionKind.allCases.map(\.family))
        for family in SessionFamily.allCases {
            XCTAssertTrue(used.contains(family), "aucune séance dans la famille \(family.rawValue)")
        }
    }

    /// Les séances HYROX de renforcement ne sont pas de la course.
    ///
    /// C'est la seule famille dont l'appartenance ne se devine pas depuis le nom du type : une
    /// « course compromise » contient le mot course et se déroule pourtant entre deux stations.
    /// Les placer avec les footings les rendrait indiscernables d'une séance d'endurance dans un
    /// plan HYROX, où elles sont justement la charge de la semaine.
    func testHyroxStationWorkAndCompromisedRunsAreFunctional() {
        let expected: [SessionKind] = [
            .hyroxTechnique, .hyroxTechniquePro, .hyroxIntenseCircuit, .hyroxIntenseCircuitPro,
            .hyroxCompromisedRun3, .hyroxCompromisedRun6, .hyroxCompromisedRunLight2,
            .hyroxStationsReminder, .hyroxLightSimulation, .hyroxLightFunctional,
        ]
        for kind in expected {
            XCTAssertEqual(kind.family, .functional, "\(kind.rawValue)")
        }
    }

    /// Les footings HYROX restent de l'endurance et de la récupération : ils se courent, eux.
    func testHyroxFootingsStayOnTheRunningAxis() {
        XCTAssertEqual(SessionKind.hyroxBaseFooting.family, .endurance)
        XCTAssertEqual(SessionKind.hyroxMaintenanceFooting.family, .endurance)
        XCTAssertEqual(SessionKind.hyroxRecoveryFooting.family, .recovery)
        XCTAssertEqual(SessionKind.hyroxTempoSled.family, .tempo)
    }

    // MARK: Le repli des plans enregistrés avant `kind`

    /// Une séance sans type ne doit jamais rester sans couleur.
    func testLegacySessionWithoutKindFallsBackOnTitle() {
        let interval = WorkoutSession(title: "Fractionné 5 × 500 m", subtitle: "",
                                      durationMinutes: 37, pace: "5:02", zone: "Z3", adjustment: nil)
        XCTAssertEqual(interval.family, .intervals)

        let footing = WorkoutSession(title: "Footing tranquille", subtitle: "",
                                     durationMinutes: 38, pace: "6:03", zone: "Z2", adjustment: nil)
        XCTAssertEqual(footing.family, .endurance)
    }

    /// Une durée nulle est un jour de repos, même sans type enregistré.
    func testLegacyZeroDurationSessionIsRest() {
        let rest = WorkoutSession(title: "Repos", subtitle: "", durationMinutes: 0,
                                  pace: "—", zone: "—", adjustment: nil)
        XCTAssertEqual(rest.family, .rest)
    }

    /// Le type enregistré prime toujours sur le titre.
    ///
    /// Sans cette priorité, une séance dont le titre a été traduit ou reformulé changerait de
    /// famille — donc de couleur — sans que rien de son contenu ait bougé.
    func testStoredKindWinsOverTheTitle() {
        let session = WorkoutSession(title: "Fractionné 5 × 500 m", subtitle: "",
                                     durationMinutes: 40, pace: "5:00", zone: "Z3",
                                     adjustment: nil, kind: .longRun)
        XCTAssertEqual(session.family, .longRun)
    }

    /// LE RÔLE ET LA FAMILLE RÉPONDENT À DEUX QUESTIONS DIFFÉRENTES, et ce test fixe l'écart.
    ///
    /// La famille dit « faut-il un jour de récupération derrière ? » et se répond plus large
    /// exprès, pour l'avertissement de déplacement. Le rôle dit « est-ce que ça compte contre le
    /// plafond de deux séances de qualité par semaine ». Les confondre a fait compter les
    /// transitions d'un duathlon, qui s'apprennent à allure de promenade, comme une séance dure —
    /// et, dans l'autre sens, a laissé le plafond HYROX se vérifier sur une sous-chaîne de titre.
    func testLeRoleEtLaFamilleRepondentADeuxQuestions() {
        let transitions = WorkoutSession(title: "Transitions", subtitle: "", durationMinutes: 30,
                                         pace: "—", zone: "Technique", kind: .triTransitions,
                                         role: .easy)
        XCTAssertTrue(transitions.family.isDemanding,
                      "un jour de récupération derrière : la famille le dit")
        XCTAssertNotEqual(transitions.role, .speed,
                          "mais elle ne coûte rien au plafond hebdomadaire")

        let circuit = WorkoutSession(title: "Circuit intense", subtitle: "", durationMinutes: 40,
                                     pace: "—", zone: "Z3-4", kind: .hyroxIntenseCircuit,
                                     role: .speed)
        XCTAssertTrue(circuit.family.isDemanding)
        XCTAssertEqual(circuit.role, .speed, "celle-ci coûte une place sur deux")

        // Une séance venue d'ailleurs que du générateur n'a pas de rôle, et « on ne sait pas »
        // doit rester distinct de « facile » — voir `WorkoutSession.role`.
        let saisieAlaMain = WorkoutSession(title: "Sortie", subtitle: "", durationMinutes: 45,
                                          pace: "5:30", zone: "Z2")
        XCTAssertNil(saisieAlaMain.role)
    }
}
