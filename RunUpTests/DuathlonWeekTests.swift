import XCTest
import SwiftData
@testable import RunUp

/// La semaine d'un plan de duathlon.
///
/// # CE QUE CES TESTS GARDENT
///
/// Un duathlon se court à 51 % de son temps d'effort, contre 33 % pour un triathlon olympique.
/// Toute la question du plan tient là : si la séance la plus longue part au vélo — comme elle
/// le fait, à juste titre, dans un plan de triathlon — c'est l'épreuve qui décide de la journée
/// qu'on sous-entraîne. Et ça ne se verrait nulle part : la semaine serait pleine, les séances
/// cohérentes, les chiffres justes. Juste une coureuse qui marche au second parcours.
///
/// Le second risque est inverse et vient du même endroit : les séances de vélo réutilisent les
/// types écrits pour le triathlon. Une natation qui se glisserait dans un plan de duathlon
/// serait absurde — et parfaitement silencieuse.
///
/// Comme pour le triathlon, les tests balaient deux à six jours sur les quatre blocs : le
/// distributeur fait tourner les archétypes positionnellement, donc le nombre de jours décide
/// de ce qu'elle voit.
@MainActor
final class DuathlonWeekTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProfile(
        format: DuathlonFormat = .standard,
        runningDays: [Int] = [0, 2, 4, 6],
        weeksUntilRace: Int = 12
    ) -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.goalId = .duathlon
        profile.level = .intermediaire
        profile.duathlonFormat = format.rawValue
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

    /// LE TEST QUI PORTE LA DÉCISION : jamais une seule longueur de bassin.
    ///
    /// Les séances de vélo d'un duathlon sont littéralement celles du triathlon — mêmes types,
    /// `triBikeEndurance` et ses voisines. Reprendre par mégarde une natation avec elles ne
    /// casserait rien : ça mettrait une piscine dans le plan de quelqu'un qui n'en a pas.
    func testAucuneNatationDansUnPlanDeDuathlon() {
        for jours in 2...6 {
            let profile = makeProfile(runningDays: Array(0..<jours))
            for week in 1...12 {
                let nages = kinds(profile, week: week).filter { $0.disciplines.contains(.swim) }
                XCTAssertTrue(nages.isEmpty, "\(jours)j s\(week) : natation dans un duathlon — \(nages)")
            }
        }
    }

    /// Les deux disciplines sont là, dès deux jours — c'est le minimum que l'objectif déclare.
    func testLesDeuxDisciplinesSontDansLaSemaine() {
        for jours in 2...6 {
            let profile = makeProfile(runningDays: Array(0..<jours))
            for week in 1...12 {
                let presentes = Set(kinds(profile, week: week).flatMap(\.disciplines))
                XCTAssertTrue(presentes.contains(.run), "\(jours)j s\(week) : pas de course")
                XCTAssertTrue(presentes.contains(.bike), "\(jours)j s\(week) : pas de vélo")
            }
        }
    }

    /// LA COURSE RESTE MAJORITAIRE, et c'est la traduction en séances de `partCourue`.
    ///
    /// Compté sur douze semaines plutôt que sur une : le distributeur tourne positionnellement,
    /// donc une semaine isolée peut pencher d'un côté sans que le plan penche.
    func testLaCourseResteMajoritaireSurLeCycle() {
        for jours in 3...6 {
            let profile = makeProfile(runningDays: Array(0..<jours))
            var course = 0
            var velo = 0
            for week in 1...12 {
                for kind in kinds(profile, week: week) {
                    if kind.disciplines.contains(.run) { course += 1 }
                    if kind.disciplines == [.bike] { velo += 1 }
                }
            }
            XCTAssertGreaterThan(course, velo,
                                 "\(jours)j : \(course) séances à pied contre \(velo) à vélo")
        }
    }

    /// LA RÉPÉTITION GÉNÉRALE N'ARRIVE QU'À L'AFFÛTAGE. Elle coûte cher, et sa valeur est
    /// d'être vécue une fois avant le jour J — pas d'ajouter du volume douze semaines durant.
    func testCourseVeloCourseNArriveQuALAffutage() {
        let profile = makeProfile(runningDays: [0, 2, 4, 6], weeksUntilRace: 12)
        let shape = AdaptivePlanEngine.ProgramShape.compute(
            goal: .duathlon, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
        var semainesAvecRepetition: [Int] = []
        for week in 1...12 where kinds(profile, week: week).contains(.duaRunBikeRun) {
            semainesAvecRepetition.append(week)
        }
        XCTAssertFalse(semainesAvecRepetition.isEmpty, "la répétition générale n'arrive jamais")
        for week in semainesAvecRepetition {
            XCTAssertEqual(AdaptivePlanEngine.trainingBlock(forWeek: week, shape: shape), .affutage,
                           "semaine \(week) : répétition générale hors affûtage")
        }
    }

    /// L'enchaînement vélo→course est la séance du bloc spécifique, et il doit y être.
    /// Sans lui, le plan est deux disciplines côte à côte — pas un duathlon.
    func testLEnchainementEstDansLeBlocSpecifique() {
        let profile = makeProfile(runningDays: [0, 2, 4, 6], weeksUntilRace: 12)
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: .duathlon, raceDate: profile.raceDate,
                                         from: profile.programStartDate ?? .now)
        var vu = false
        for week in 1...12 {
            guard AdaptivePlanEngine.trainingBlock(forWeek: week, shape: shape) == .specifique else { continue }
            if kinds(profile, week: week).contains(.triBrick) { vu = true }
        }
        XCTAssertTrue(vu, "aucun enchaînement dans tout le bloc spécifique")
    }

    /// Le seuil à VÉLO ne doit pas consommer le quota de séances de qualité, qui compte ce qui
    /// pèse sur les jambes. Sinon une semaine à deux qualités en contient une seule à pied, et
    /// le travail d'allure disparaît du plan d'une épreuve qui se court à plus de la moitié.
    func testLeSeuilAVeloNeMangePasLeQuotaDeQualite() {
        let profile = makeProfile(runningDays: [0, 1, 2, 3, 4], weeksUntilRace: 8)
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: .duathlon, raceDate: profile.raceDate,
                                         from: profile.programStartDate ?? .now)
        for week in 1...8 {
            guard AdaptivePlanEngine.trainingBlock(forWeek: week, shape: shape) == .specifique else { continue }
            let semaine = kinds(profile, week: week)
            guard semaine.contains(.triBikeThreshold) else { continue }
            XCTAssertTrue(semaine.contains(.tempoRun) || semaine.contains(.triBrick),
                          "semaine \(week) : du seuil à vélo, mais plus rien de soutenu à pied")
        }
    }
}
