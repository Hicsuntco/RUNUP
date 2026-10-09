import XCTest
import SwiftData
@testable import RunUp

/// `UserProfile.runValue` est une distance COURUE, et rien d'autre.
///
/// Son commentaire le dit depuis toujours — « Distance run today (km) » — et pourtant
/// `applyDebrief` y ajoutait `run.distanceKm` sans poser une seule condition. Quarante kilomètres
/// de vélo entraient donc dans la distance courue du jour, qui est lue par le classement du club
/// et par le bilan de fin de programme : un chiffre de course gonflé par une discipline qui n'en
/// est pas une, en tête d'un classement entre coureuses.
///
/// Le défaut existait depuis que le vélo existe. Il a été trouvé en relisant ce chemin pour la
/// natation, c'est-à-dire par la discipline SUIVANTE — exactement la panne que l'en-tête de
/// `Discipline` décrit : rien ne casse, rien ne s'affiche en rouge, le nombre devient faux et on
/// s'en aperçoit des semaines plus tard.
@MainActor
final class DistanceCourueTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: UserProfile.self, RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeProfile() -> UserProfile {
        let profile = UserProfile(name: "Test")
        profile.weekStrip = (0..<7).map { DayStatus(weekday: $0, letter: "·", state: .upcoming) }
        profile.weekSessions = (0..<7).map { PlannedDay(weekday: $0) }
        // Un plafond haut : c'est le filtre par discipline qu'on mesure, pas l'écrêtage.
        profile.runGoal = 100
        profile.runValue = 0
        container.mainContext.insert(profile)
        return profile
    }

    private func seance(_ discipline: Discipline, km: Double) -> RunRecord {
        AdaptivePlanEngine.buildRunRecord(
            title: "Test", elapsedSeconds: 3600, distanceKm: km, kcal: 300,
            avgHeartRate: 140, discipline: discipline
        )
    }

    /// Courir compte, et c'est le cas ordinaire : sans lui, le garde-fou aurait pu tout refuser
    /// sans que rien ne le dise.
    func testCourirCompteDansLaDistanceCourue() {
        let profile = makeProfile()
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: seance(.run, km: 10), profile: profile)
        XCTAssertEqual(profile.runValue, 10, accuracy: 0.001)
    }

    /// Le trail aussi : c'est de la course à pied, faite ailleurs.
    func testLeTrailCompteDansLaDistanceCourue() {
        let profile = makeProfile()
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: seance(.trail, km: 12), profile: profile)
        XCTAssertEqual(profile.runValue, 12, accuracy: 0.001)
    }

    /// Le défaut, dans sa version vélo : quarante kilomètres roulés ne sont pas quarante
    /// kilomètres courus.
    func testRoulerNeComptePasDansLaDistanceCourue() {
        let profile = makeProfile()
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: seance(.bike, km: 40), profile: profile)
        XCTAssertEqual(profile.runValue, 0, accuracy: 0.001)
    }

    /// Et dans sa version natation.
    func testNagerNeComptePasDansLaDistanceCourue() {
        let profile = makeProfile()
        AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: seance(.swim, km: 1.5), profile: profile)
        XCTAssertEqual(profile.runValue, 0, accuracy: 0.001)
    }

    /// L'invariant, écrit une fois pour toutes les disciplines présentes et à venir : la distance
    /// courue n'augmente QUE pour celles qui se font chaussées.
    ///
    /// Formulé sur `wearsShoes` plutôt que sur une liste de disciplines, pour que la cinquième
    /// discipline soit couverte par ce test le jour où elle est écrite, sans qu'on y revienne.
    func testSeuleUneDisciplineChausseeAugmenteLaDistanceCourue() {
        for discipline in Discipline.allCases {
            let profile = makeProfile()
            AdaptivePlanEngine.applyDebrief(rpe: .justeBien, run: seance(discipline, km: 8),
                                            profile: profile)
            let attendu: Double = discipline.wearsShoes ? 8 : 0
            XCTAssertEqual(profile.runValue, attendu, accuracy: 0.001,
                           "\(discipline) : distance courue inattendue")
        }
    }

    /// L'assiduité, elle, compte pour tout le monde — c'est l'autre moitié de la règle, et elle
    /// ne doit pas être emportée par le garde-fou ci-dessus. Quelqu'un qui nage une heure n'a
    /// pas couru, et n'a pas rien fait non plus.
    func testToutesLesDisciplinesComptentPourLAssiduite() {
        for discipline in Discipline.allCases {
            XCTAssertTrue(discipline.countsTowardStreak, "\(discipline) ne compte pas pour la série")
        }
    }
}
