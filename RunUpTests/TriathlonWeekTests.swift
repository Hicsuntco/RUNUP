import XCTest
import SwiftData
@testable import RunUp

/// La semaine d'un plan de triathlon.
///
/// # CE QUE CES TESTS GARDENT
///
/// « La natation doit figurer dans le plan. » C'est la demande, et c'est la seule chose qu'un
/// plan de triathlon ne peut pas rater — parce que c'est aussi la discipline que l'app ne sait
/// pas mesurer, donc la seule dont l'absence ne se verrait nulle part ailleurs : aucun relevé
/// manquant, aucun chiffre faux, juste une semaine qui ne la contient pas.
///
/// Le distributeur fait tourner les archétypes positionnellement, donc le nombre de jours
/// qu'elle a choisis décide de ce qu'elle voit. Les tests balaient donc trois à six jours sur
/// les quatre blocs, et pas un seul cas confortable.
@MainActor
final class TriathlonWeekTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProfile(
        format: TriathlonFormat = .olympique,
        nage: NiveauDeNage = .plus1500,
        runningDays: [Int] = [0, 2, 4, 6],
        weeksUntilRace: Int = 12
    ) -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.goalId = .triathlon
        profile.level = .intermediaire
        profile.triathlonFormat = format.rawValue
        profile.nageNiveau = nage.rawValue
        profile.runningDays = runningDays
        profile.preferredLongRunDay = runningDays.max()
        let start = Date()
        profile.programStartDate = start
        profile.raceDate = Calendar.current.date(byAdding: .weekOfYear, value: weeksUntilRace, to: start)
        container.mainContext.insert(profile)
        return profile
    }

    private func kinds(_ profile: UserProfile, week: Int) -> [SessionKind] {
        AdaptivePlanEngine.generateWeekSessions(weekNumber: week, tier: 1, profile: profile)
            .compactMap { $0.session?.kind }
    }

    /// LE TEST QUI PORTE LA DEMANDE : la natation est dans la semaine, quelle que soit la
    /// semaine et quel que soit le nombre de jours.
    func testLaNatationEstDansChaqueSemaineDuPlan() {
        for jours in 3...6 {
            let profile = makeProfile(runningDays: Array(0..<jours))
            for week in 1...12 {
                let semaine = kinds(profile, week: week)
                let nages = semaine.filter { $0.disciplines == [.swim] }
                XCTAssertFalse(nages.isEmpty,
                               "\(jours) jours, semaine \(week) : aucune natation")
            }
        }
    }

    /// Et les trois disciplines y sont, dès quatre jours.
    ///
    /// Trois jours restent minces pour un triathlon — le dire est l'affaire des garde-fous — mais
    /// même à trois, les trois disciplines doivent apparaître : c'est pour ça que l'ordre des
    /// archétypes est un ordre de priorité.
    func testLesTroisDisciplinesSontDansLaSemaine() {
        for jours in 3...6 {
            let profile = makeProfile(runningDays: Array(0..<jours))
            for week in 1...12 {
                let presentes = Set(kinds(profile, week: week).flatMap(\.disciplines))
                XCTAssertTrue(presentes.contains(.swim), "\(jours)j s\(week) : pas de natation")
                XCTAssertTrue(presentes.contains(.bike), "\(jours)j s\(week) : pas de vélo")
                XCTAssertTrue(presentes.contains(.run), "\(jours)j s\(week) : pas de course")
            }
        }
    }

    /// Le niveau de natation INTERDIT des séances, et c'est la seule réponse d'inscription de
    /// toute l'app qui en interdise.
    ///
    /// Quelqu'un qui ne nage pas encore ne doit jamais voir « nage continue » ni « fractionné
    /// en bassin » dans son plan. La séance qu'elle voit est « durer dans l'eau » : des longueurs
    /// courtes, autant de pauses qu'il faut.
    func testUnFaibleNiveauDeNatationInterditLesSeancesContinues() {
        for niveau in [NiveauDeNage.pasEncore, .moins200] {
            let profile = makeProfile(nage: niveau, runningDays: [0, 1, 2, 3, 4, 5, 6])
            for week in 1...12 {
                let semaine = kinds(profile, week: week)
                XCTAssertFalse(semaine.contains(.triSwimIntervals),
                               "\(niveau) s\(week) : fractionné en bassin prescrit")
                XCTAssertFalse(semaine.contains(.triSwimEndurance),
                               "\(niveau) s\(week) : nage continue prescrite")
                // Mais il y a bien de l'eau dans sa semaine — interdire n'est pas supprimer.
                let nages = semaine.filter { $0.disciplines == [.swim] }
                XCTAssertFalse(nages.isEmpty, "\(niveau) s\(week) : plus aucune natation")
            }
        }
    }

    /// Qui nage déjà, elle, a droit aux séances continues.
    func testUnBonNiveauDeNatationDonneAccesAuxSeancesContinues() {
        let profile = makeProfile(nage: .plus1500, runningDays: [0, 1, 2, 3, 4, 5, 6])
        var vues: Set<SessionKind> = []
        for week in 1...12 { vues.formUnion(kinds(profile, week: week)) }
        XCTAssertTrue(vues.contains(.triSwimEndurance), "aucune nage continue sur douze semaines")
        XCTAssertFalse(vues.contains(.triSwimLearn), "« durer dans l'eau » prescrit à qui nage 1500 m")
    }

    /// L'ENCHAÎNEMENT EXISTE DANS LA PRÉPARATION, et c'est la séance qui définit le format.
    ///
    /// Un plan qui travaillerait les trois disciplines séparément produirait quelqu'un capable
    /// de faire chaque épreuve et incapable de les enchaîner. Le test regarde les douze semaines
    /// plutôt qu'une seule : l'enchaînement appartient au bloc spécifique et à l'affûtage, pas
    /// à la base.
    func testLEnchainementApparaitDansLaPreparation() {
        let profile = makeProfile(weeksUntilRace: 12)
        var vues: Set<SessionKind> = []
        for week in 1...12 { vues.formUnion(kinds(profile, week: week)) }
        XCTAssertTrue(vues.contains(.triBrick) || vues.contains(.triBrickRace),
                      "aucun enchaînement vélo→course en douze semaines : \(vues.map(\.rawValue))")
    }

    /// Et les transitions aussi — deux minutes gagnées là valent une séance de seuil.
    func testLesTransitionsApparaissentALAffutage() {
        let profile = makeProfile(weeksUntilRace: 12)
        var vues: Set<SessionKind> = []
        for week in 1...12 { vues.formUnion(kinds(profile, week: week)) }
        XCTAssertTrue(vues.contains(.triTransitions),
                      "aucune séance de transition en douze semaines")
    }

    /// Le vélo porte le volume des semaines qui CONSTRUISENT.
    ///
    /// Mesuré en MINUTES et pas en nombre de séances — c'est le temps passé qui compte, et une
    /// sortie vélo de 90 minutes ne se compare pas à une nage de 40. 180 km contre 42 : c'est la
    /// discipline qui prend le plus de temps le jour J, donc celle qui doit prendre le plus
    /// d'heures dans la semaine.
    ///
    /// LA SEMAINE DE RÉCUP EST EXCLUE, ET C'EST UN CHOIX. Le bassin y porte plus de minutes que
    /// la selle : c'est l'endroit le plus doux de la semaine, sans impact et sans charge sur les
    /// articulations. Une semaine de décharge n'a rien à construire, donc elle n'a pas à
    /// ressembler à la course. Vérifié en simulation avant d'écrire ce test — l'invariant est
    /// faux là, et il doit l'être.
    func testLeVeloPorteLeVolumeDesSemainesQuiConstruisent() {
        let profile = makeProfile(runningDays: [0, 1, 2, 3, 4, 5, 6], weeksUntilRace: 12)
        let forme = AdaptivePlanEngine.ProgramShape.compute(
            goal: profile.goalId, raceDate: profile.raceDate,
            from: profile.programStartDate ?? .now
        )
        var semainesVerifiees = 0
        for week in 1...12 {
            let bloc = AdaptivePlanEngine.trainingBlock(forWeek: week, shape: forme)
            guard bloc != .deload else { continue }
            semainesVerifiees += 1
            let minutes = minutesParDiscipline(profile, week: week)
            let velo = minutes[.bike] ?? 0
            XCTAssertGreaterThan(velo, minutes[.swim] ?? 0, "s\(week) \(bloc.rawValue) : \(minutes)")
            XCTAssertGreaterThan(velo, minutes[.run] ?? 0, "s\(week) \(bloc.rawValue) : \(minutes)")
        }
        XCTAssertGreaterThan(semainesVerifiees, 6, "trop peu de semaines de construction vérifiées")
    }

    // MARK: Le plafond de qualité

    /// LE PLAFOND DE DEUX SÉANCES DURES NE DOIT COMPTER QUE CE QUI PÈSE SUR LES JAMBES.
    ///
    /// Il existe contre une cause précise : plusieurs séances intenses EN COURANT dans la même
    /// semaine, donc plusieurs fois le même impact sur les mêmes tendons. Un plan de triathlon
    /// en met trois d'un coup — bassin, selle, bitume — et les compter ensemble aurait fait
    /// remplacer le seuil vélo par une nage facile, au nom d'un risque de blessure à la course
    /// que ni le bassin ni la selle ne font courir.
    ///
    /// Le propre des trois disciplines est de répartir la charge sur des tissus différents. Un
    /// plafond qui l'ignore annule la raison d'être du format.
    func testLeSeuilVeloNEstPasRemplaceParUneNageFacile() {
        let profile = makeProfile(runningDays: [0, 1, 2, 3, 4, 5, 6], weeksUntilRace: 12)
        var vues: Set<SessionKind> = []
        for week in 1...12 { vues.formUnion(kinds(profile, week: week)) }
        XCTAssertTrue(vues.contains(.triBikeThreshold),
                      "le seuil vélo a disparu du plan : \(vues.map(\.rawValue).sorted())")
    }

    /// Et il reste intact pour les plans de course : aucune séance de qualité d'un autre
    /// objectif ne se fait autrement que chaussée, donc le comportement est inchangé.
    ///
    /// C'est ce qui rend le changement sûr : la question « est-ce que cette séance se fait
    /// chaussée ? » répond oui pour toutes les séances dures qui existaient avant.
    func testLeChangementDePlafondNAffectePasLesPlansDeCourse() {
        let horsTriathlon = SessionKind.allCases.filter {
            !$0.rawValue.hasPrefix("tri_") && $0 != .rest
        }
        for kind in horsTriathlon {
            XCTAssertTrue(kind.disciplines.contains { $0.wearsShoes },
                          "\(kind.rawValue) n'est pas chaussée — le plafond changerait de sens")
        }
    }

    // MARK: Ce qui coche la journée

    private func seance(_ kind: SessionKind, le jour: Int, _ profile: UserProfile) {
        profile.weekStrip = (0..<7).map { DayStatus(weekday: $0, letter: "·", state: .upcoming) }
        profile.weekSessions = (0..<7).map { j in
            var planned = PlannedDay(weekday: j)
            if j == jour {
                planned.session = WorkoutSession(
                    title: "Test", subtitle: "", durationMinutes: 40, pace: "—", zone: "Z2",
                    adjustment: nil, kind: kind
                )
            }
            return planned
        }
    }

    private func releve(_ discipline: Discipline) -> RunRecord {
        AdaptivePlanEngine.buildRunRecord(
            title: "Test", elapsedSeconds: 2400, distanceKm: 1.5, kcal: 300,
            avgHeartRate: 130, discipline: discipline
        )
    }

    /// NAGER COCHE UNE JOURNÉE DE NATATION. Sans ça, la natation serait au plan et impossible à
    /// valider : la case resterait vide pour une séance faite, et le moteur adapterait la
    /// semaine suivante sur une séance qu'il croit manquée.
    func testNagerCocheUneJourneeDeNatation() {
        let profile = makeProfile()
        let jour = AdaptivePlanEngine.weekdayIndex(for: .now)
        seance(.triSwimEndurance, le: jour, profile)
        AdaptivePlanEngine.markSessionDone(for: releve(.swim), profile: profile)
        XCTAssertTrue(profile.weekSessions[jour].completed)
    }

    /// Courir ne coche PAS une journée de natation. On n'a pas fait la séance.
    func testCourirNeCochePasUneJourneeDeNatation() {
        let profile = makeProfile()
        let jour = AdaptivePlanEngine.weekdayIndex(for: .now)
        seance(.triSwimEndurance, le: jour, profile)
        AdaptivePlanEngine.markSessionDone(for: releve(.run), profile: profile)
        XCTAssertFalse(profile.weekSessions[jour].completed)
    }

    /// Rouler coche une journée de vélo — ce que l'ancienne règle refusait, puisqu'elle demandait
    /// à la DISCIPLINE si elle complétait un plan de course.
    func testRoulerCocheUneJourneeDeVelo() {
        let profile = makeProfile()
        let jour = AdaptivePlanEngine.weekdayIndex(for: .now)
        seance(.triBikeEndurance, le: jour, profile)
        AdaptivePlanEngine.markSessionDone(for: releve(.bike), profile: profile)
        XCTAssertTrue(profile.weekSessions[jour].completed)
    }

    /// L'enchaînement se coche par l'une ou l'autre de ses moitiés.
    func testLEnchainementSeCocheParLUneOuLAutreDeSesMoities() {
        for discipline in [Discipline.bike, .run] {
            let profile = makeProfile()
            let jour = AdaptivePlanEngine.weekdayIndex(for: .now)
            seance(.triBrick, le: jour, profile)
            AdaptivePlanEngine.markSessionDone(for: releve(discipline), profile: profile)
            XCTAssertTrue(profile.weekSessions[jour].completed, "\(discipline)")
        }
    }

    // MARK: Les garde-fous

    /// UN PLAN DE TRIATHLON A UN BLOC SPÉCIFIQUE ET UN AFFÛTAGE.
    ///
    /// C'est le défaut qui a coûté à l'ultra-trail l'intégralité de son bloc spécifique et de son
    /// affûtage : son objectif ne figurait pas dans la liste écrite en dur qui décidait quels
    /// plans se périodisent, donc il tombait dans la branche « programme ouvert » — zéro semaine
    /// de base, zéro de spécifique, zéro d'affûtage. Les onze séances d'ultra existaient, le
    /// moteur savait les produire, et il n'en servait jamais que deux blocs sur quatre.
    ///
    /// Pour un triathlon, ce serait pire : sans bloc spécifique il n'y a aucun enchaînement
    /// vélo→course, et sans affûtage aucune séance de transition. Les deux séances qui font la
    /// différence le jour J, absentes, sans une ligne qui casse.
    func testUnPlanDeTriathlonAUnBlocSpecifiqueEtUnAffutage() {
        let profile = makeProfile(weeksUntilRace: 12)
        let forme = AdaptivePlanEngine.ProgramShape.compute(
            goal: profile.goalId, raceDate: profile.raceDate,
            from: profile.programStartDate ?? .now
        )
        XCTAssertNotNil(forme.totalWeeks, "le plan est ouvert : pas de ligne d'arrivée")
        XCTAssertGreaterThan(forme.specificWeeks, 0, "aucune semaine spécifique")
        XCTAssertGreaterThan(forme.taperWeeks, 0, "aucune semaine d'affûtage")
    }

    /// AUCUNE DISCIPLINE NE BONDIT D'UNE SEMAINE DE CONSTRUCTION À LA SUIVANTE.
    ///
    /// La règle du ~10 % par semaine est la raison d'être de la rampe de la sortie longue, et
    /// elle vaut pour les trois disciplines. Le plafond est posé à +40 % et non à +10 % parce
    /// qu'un changement de bloc change aussi la NATURE de la séance longue — une sortie vélo de
    /// 90 minutes devient un enchaînement de 80 — ce qui est une substitution, pas une
    /// progression. En pratique le pire bond mesuré est de +7 %.
    ///
    /// LES SEMAINES DE DÉCHARGE SONT EXCLUES DE LA COMPARAISON, et ce n'est pas une facilité.
    /// Une semaine de décharge est volontairement légère, donc la semaine qui la suit remonte
    /// forcément — ×2,6 sur le vélo, mesuré. La comparer à sa voisine reviendrait à interdire la
    /// décharge elle-même. Le moteur fait déjà exactement cette distinction pour la rampe de la
    /// sortie longue (voir `buildWeekPosition` : « une semaine de décharge ne doit pas consommer
    /// un pas de la progression »), et c'est la même ici.
    ///
    /// La première version de ce test comparait tout à tout et échouait sur ce bond-là. C'est le
    /// test qui avait tort.
    func testAucuneDisciplineNeBonditEntreDeuxSemainesDeConstruction() {
        let profile = makeProfile(runningDays: [0, 2, 4, 6], weeksUntilRace: 12)
        let forme = AdaptivePlanEngine.ProgramShape.compute(
            goal: profile.goalId, raceDate: profile.raceDate,
            from: profile.programStartDate ?? .now
        )
        var precedent: [Discipline: Int] = [:]
        var comparaisons = 0
        for week in 1...12 {
            guard AdaptivePlanEngine.trainingBlock(forWeek: week, shape: forme) != .deload else { continue }
            let minutes = minutesParDiscipline(profile, week: week)
            for (discipline, total) in minutes {
                guard let avant = precedent[discipline], avant > 0 else { continue }
                comparaisons += 1
                XCTAssertLessThan(Double(total) / Double(avant), 1.4,
                                  "s\(week) \(discipline) : \(avant) → \(total) minutes")
            }
            precedent = minutes
        }
        XCTAssertGreaterThan(comparaisons, 10, "trop peu de comparaisons pour conclure")
    }

    /// Et une semaine de décharge décharge VRAIMENT : moins de minutes que la semaine d'avant.
    ///
    /// L'autre moitié de la règle ci-dessus. Exclure les semaines de décharge d'une comparaison
    /// ne doit pas revenir à ne jamais les vérifier — c'est ainsi qu'un bloc « récup » plus
    /// chargé que le bloc qu'il allège passerait inaperçu, défaut qu'`UltraTrailTests` a déjà
    /// eu à corriger sur l'affûtage.
    func testUneSemaineDeDechargeDechargeVraiment() {
        let profile = makeProfile(runningDays: [0, 2, 4, 6], weeksUntilRace: 12)
        let forme = AdaptivePlanEngine.ProgramShape.compute(
            goal: profile.goalId, raceDate: profile.raceDate,
            from: profile.programStartDate ?? .now
        )
        var verifiees = 0
        for week in 2...12 {
            guard AdaptivePlanEngine.trainingBlock(forWeek: week, shape: forme) == .deload else { continue }
            let avant = minutesParDiscipline(profile, week: week - 1).values.reduce(0, +)
            let pendant = minutesParDiscipline(profile, week: week).values.reduce(0, +)
            verifiees += 1
            XCTAssertLessThan(pendant, avant, "s\(week) : décharge de \(avant) à \(pendant) minutes")
        }
        XCTAssertGreaterThan(verifiees, 0, "aucune semaine de décharge dans un plan de douze")
    }

    private func minutesParDiscipline(_ profile: UserProfile, week: Int) -> [Discipline: Int] {
        var minutes: [Discipline: Int] = [:]
        let semaine = AdaptivePlanEngine.generateWeekSessions(weekNumber: week, tier: 1, profile: profile)
            .compactMap { $0.session }
        for session in semaine {
            guard let kind = session.kind, let premiere = kind.disciplines.first else { continue }
            minutes[premiere, default: 0] += session.durationMinutes
        }
        return minutes
    }

    /// LE CHEMIN DE LA SECONDE PORTE, DE BOUT EN BOUT.
    ///
    /// L'assistant de nouvel objectif construit un plan directement, sans passer par
    /// l'inscription. C'est lui qui a tenu l'objectif fermé cinq lots durant : il liste les
    /// objectifs exactement comme l'inscription, donc ouvrir le triathlon l'y faisait apparaître
    /// sans ses deux questions. Ce test parcourt ce chemin-là et vérifie que le plan produit
    /// contient bien de la natation.
    func testUnPlanConstruitParLAssistantContientDeLaNatation() {
        let profile = UserProfile(name: "Test")
        container.mainContext.insert(profile)
        var resultat = AdaptivePlanEngine.NewGoalResult(
            goal: .triathlon,
            distance: nil,
            chrono: "2:35",
            raceDate: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: .now),
            runningDays: [0, 2, 4, 6]
        )
        resultat.triathlonFormat = TriathlonFormat.olympique.rawValue
        resultat.nageNiveau = NiveauDeNage.plus1500.rawValue
        AdaptivePlanEngine.startNewProgram(resultat, profile: profile)

        XCTAssertEqual(profile.triathlonFormat, "olympique", "le format n'a pas été écrit")
        XCTAssertEqual(profile.nageNiveau, "plus1500", "le niveau de natation n'a pas été écrit")
        XCTAssertNotNil(profile.raceDate, "la date a été effacée : le plan serait ouvert")

        let nages = profile.weekSessions.compactMap { $0.session?.kind }
            .filter { $0.disciplines == [.swim] }
        XCTAssertFalse(nages.isEmpty, "le plan construit par l'assistant n'a aucune natation")
    }

    /// Et repartir sur un objectif de course EFFACE le format du triathlon.
    ///
    /// Le laisser derrière ferait lire au moteur un format qui ne décrit plus rien, et
    /// `goalDisplay` afficherait « 10 km » au-dessus d'un plan dimensionné sur une épreuve
    /// abandonnée. Même règle que le dénivelé d'ultra, qui a le même piège.
    func testRepartirSurUneCourseEffaceLeFormatDuTriathlon() {
        let profile = makeProfile()
        XCTAssertEqual(profile.triathlonFormat, "olympique")
        let resultat = AdaptivePlanEngine.NewGoalResult(
            goal: .race, distance: .k10, chrono: "47:30",
            raceDate: Calendar.current.date(byAdding: .weekOfYear, value: 10, to: .now),
            runningDays: [0, 2, 4]
        )
        AdaptivePlanEngine.startNewProgram(resultat, profile: profile)
        XCTAssertNil(profile.triathlonFormat, "le format du triathlon a survécu au changement")
        XCTAssertNil(profile.nageNiveau, "le niveau de natation a survécu au changement")
    }

    /// LE REPLI N'A PAS CHANGÉ POUR UN PLAN SANS `kind`.
    ///
    /// Les plans enregistrés avant que ce champ existe n'ont aucune séance à interroger. Ce sont
    /// tous des plans de course, et l'ancienne règle est la bonne pour eux : courir coche,
    /// rouler non.
    func testUnPlanSansTypeDeSeanceGardeLAncienneRegle() {
        let profile = makeProfile()
        let jour = AdaptivePlanEngine.weekdayIndex(for: .now)
        profile.weekStrip = (0..<7).map { DayStatus(weekday: $0, letter: "·", state: .upcoming) }
        profile.weekSessions = (0..<7).map { PlannedDay(weekday: $0) }
        AdaptivePlanEngine.markSessionDone(for: releve(.bike), profile: profile)
        XCTAssertFalse(profile.weekSessions[jour].completed, "rouler a coché un plan de course")

        profile.weekSessions = (0..<7).map { PlannedDay(weekday: $0) }
        AdaptivePlanEngine.markSessionDone(for: releve(.run), profile: profile)
        XCTAssertTrue(profile.weekSessions[jour].completed, "courir n'a pas coché un plan de course")
    }
}
