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
            var minutes: [Discipline: Int] = [:]
            let semaine = AdaptivePlanEngine.generateWeekSessions(weekNumber: week, tier: 1, profile: profile)
                .compactMap { $0.session }
            for session in semaine {
                guard let kind = session.kind, let premiere = kind.disciplines.first else { continue }
                minutes[premiere, default: 0] += session.durationMinutes
            }
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
