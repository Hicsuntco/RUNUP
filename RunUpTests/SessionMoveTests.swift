import XCTest
@testable import RunUp

/// Verrouille les règles du déplacement de séance.
///
/// Ce sont des règles d'entraînement, pas d'interface : elles se vérifient sans écran, et c'est
/// exactement pour ça que la logique vit dans `SessionMove` plutôt que dans la feuille qui
/// l'appelle.
final class SessionMoveTests: XCTestCase {

    private func session(_ kind: SessionKind, minutes: Int = 40) -> WorkoutSession {
        WorkoutSession(title: kind.rawValue, subtitle: "", durationMinutes: minutes,
                       pace: "5:30", zone: "Z2", adjustment: nil, kind: kind)
    }

    /// Lundi footing, mardi fractionné, le reste libre.
    private func week(_ plan: [Int: SessionKind], done: Set<Int> = []) -> [PlannedDay] {
        (0..<7).map { weekday in
            PlannedDay(weekday: weekday,
                       session: plan[weekday].map { session($0) },
                       completed: done.contains(weekday))
        }
    }

    // MARK: Déplacer

    func testMovingToAFreeDayRelocatesTheSession() {
        let days = week([0: .easyFooting])
        let moved = SessionMove.apply(to: days, from: 0, to: 3)
        XCTAssertNil(moved?.first { $0.weekday == 0 }?.session)
        XCTAssertEqual(moved?.first { $0.weekday == 3 }?.session?.kind, .easyFooting)
    }

    /// Deux séances s'échangent plutôt que l'une n'écrase l'autre.
    ///
    /// L'écrasement perdrait une séance de la semaine sans le dire — le décompte « 0/4 séances
    /// faites » deviendrait faux et personne ne saurait pourquoi.
    func testMovingOntoAnotherSessionSwapsThem() {
        let days = week([0: .easyFooting, 3: .vo2maxIntervals])
        let moved = SessionMove.apply(to: days, from: 0, to: 3)
        XCTAssertEqual(moved?.first { $0.weekday == 0 }?.session?.kind, .vo2maxIntervals)
        XCTAssertEqual(moved?.first { $0.weekday == 3 }?.session?.kind, .easyFooting)
        XCTAssertEqual(moved?.compactMap(\.session).count, 2, "aucune séance ne doit disparaître")
    }

    /// Une séance faite a eu lieu ce jour-là : la déplacer réécrirait l'historique.
    func testACompletedSessionCannotBeMoved() {
        let days = week([0: .easyFooting], done: [0])
        XCTAssertNil(SessionMove.apply(to: days, from: 0, to: 3))
    }

    /// Ni atterrir sur un jour dont la séance est déjà faite — l'échange l'emporterait avec lui.
    func testCannotSwapWithACompletedSession() {
        let days = week([0: .easyFooting, 3: .longRun], done: [3])
        XCTAssertNil(SessionMove.apply(to: days, from: 0, to: 3))
    }

    func testMovingARestDayOrOntoItselfIsRefused() {
        let days = week([0: .easyFooting])
        XCTAssertNil(SessionMove.apply(to: days, from: 1, to: 4), "il n'y a rien mardi")
        XCTAssertNil(SessionMove.apply(to: days, from: 0, to: 0))
        XCTAssertNil(SessionMove.apply(to: days, from: 0, to: 9))
    }

    /// Le déplacement ne valide rien : la séance arrive à faire, pas faite.
    func testAMovedSessionArrivesUnfinished() {
        let days = week([0: .easyFooting])
        let moved = SessionMove.apply(to: days, from: 0, to: 3)
        XCTAssertEqual(moved?.first { $0.weekday == 3 }?.completed, false)
    }

    // MARK: L'avertissement

    /// Coller un fractionné juste après une sortie longue doit se signaler.
    func testStackingTwoDemandingDaysWarns() {
        let days = week([0: .longRun, 4: .vo2maxIntervals])
        XCTAssertTrue(SessionMove.stacksHardDays(in: days, from: 4, to: 1),
                      "sortie longue lundi + fractionné mardi")
    }

    /// Un footing derrière une sortie longue ne pose aucun problème.
    func testMovingAnEasySessionNextToAHardOneDoesNotWarn() {
        let days = week([0: .longRun, 4: .easyFooting])
        XCTAssertFalse(SessionMove.stacksHardDays(in: days, from: 4, to: 1))
    }

    /// On ne signale que ce que le déplacement AJOUTE.
    ///
    /// Une semaine qui empilait déjà deux jours durs n'a pas à se faire gronder pour un
    /// déplacement qui n'y change rien : l'avertissement perdrait tout sens s'il s'allumait
    /// partout.
    func testAnAlreadyStackedWeekIsNotBlamedForAnUnrelatedMove() {
        let days = week([0: .longRun, 1: .vo2maxIntervals, 4: .easyFooting])
        XCTAssertFalse(SessionMove.stacksHardDays(in: days, from: 4, to: 6))
    }

    /// Dimanche et lundi ne sont pas voisins : la semaine suivante n'est pas encore écrite.
    func testTheWeekDoesNotWrapAround() {
        let days = week([0: .longRun, 4: .vo2maxIntervals])
        XCTAssertFalse(SessionMove.stacksHardDays(in: days, from: 4, to: 6),
                       "dimanche dur + lundi dur ne se juge pas ici")
    }

    // MARK: Les destinations proposées

    func testDestinationsExcludeTheSourceAndKeepTheOccupants() {
        let days = week([0: .easyFooting, 3: .longRun])
        let destinations = SessionMove.destinations(in: days, from: 0)
        XCTAssertEqual(destinations.count, 6)
        XCTAssertFalse(destinations.contains { $0.weekday == 0 })
        XCTAssertEqual(destinations.first { $0.weekday == 3 }?.occupant?.kind, .longRun)
        XCTAssertNil(destinations.first { $0.weekday == 5 }?.occupant)
    }

    /// Un jour dont la séance est déjà faite n'est pas proposé.
    func testDestinationsDropDaysHoldingACompletedSession() {
        let days = week([0: .easyFooting, 3: .longRun], done: [3])
        let destinations = SessionMove.destinations(in: days, from: 0)
        XCTAssertFalse(destinations.contains { $0.weekday == 3 })
    }
}
