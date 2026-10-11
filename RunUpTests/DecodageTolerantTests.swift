import XCTest
@testable import RunUp

/// Les structures ENREGISTRÉES survivent à une clé manquante.
///
/// # LA PANNE QUE CES TESTS TIENNENT
///
/// L'app est morte 0,2 seconde après son lancement, sur toutes les versions installables, chez
/// quelqu'un dont le programme enregistré contenait une séance que le décodeur ne savait plus
/// relire. L'accueil demande les séances de la semaine, SwiftData les relit, une clé manque, le
/// processus tombe — et comme la donnée est sur le disque, réinstaller une version antérieure
/// n'y change rien.
///
/// # CE QUE CES TESTS PEUVENT, ET CE QU'ILS NE PEUVENT PAS
///
/// Ils ne reproduisent pas l'arrêt du processus : c'est le décodeur de SwiftData qui l'inflige,
/// pas `JSONDecoder`, et un test qui tuerait son propre processus ne rapporterait rien. Ils
/// vérifient la propriété qui, elle, est la cause : AUCUNE CLÉ N'EST EXIGÉE. Là où SwiftData
/// arrête tout, `JSONDecoder` lève — donc un décodage qui réussit ici est un décodage qui ne
/// réclame rien, et c'est exactement ce qui manquait.
///
/// `ci_scripts/check_decodage.py` tient l'autre moitié : que la règle s'applique à toutes les
/// structures enregistrées, y compris celle que quelqu'un ajoutera demain.
final class DecodageTolerantTests: XCTestCase {

    private func decoder<T: Decodable>(_ type: T.Type, _ json: String,
                                       fichier: StaticString = #filePath,
                                       ligne: UInt = #line) throws -> T {
        let data = Data(json.utf8)
        return try XCTUnwrap(try? JSONDecoder().decode(T.self, from: data),
                             "\(T.self) exige encore une clé : \(json)", file: fichier, line: ligne)
    }

    // MARK: Un objet vide se décode, pour chacune

    /// Le cas limite absolu : plus une seule clé. Si celui-là passe, aucune clé n'est exigée.
    func testChaqueStructureEnregistreeSeDecodeDepuisUnObjetVide() throws {
        _ = try decoder(WorkoutSession.self, "{}")
        _ = try decoder(PlannedDay.self, "{}")
        _ = try decoder(IntervalStructure.self, "{}")
        _ = try decoder(DayStatus.self, "{}")
        _ = try decoder(TrainingEase.self, "{}")
        _ = try decoder(WatchRunLayout.self, "{}")
        _ = try decoder(RunRecord.RoutePoint.self, "{}")
    }

    // MARK: Les replis disent quelque chose de juste

    func testUneSeanceSansRienGardeDesValeursAffichables() throws {
        let seance = try decoder(WorkoutSession.self, "{}")
        XCTAssertEqual(seance.durationMinutes, 0)
        // Le tiret cadratin est ce que le moteur écrit déjà pour une journée sans allure.
        XCTAssertEqual(seance.pace, "—")
        XCTAssertEqual(seance.zone, "—")
        XCTAssertNil(seance.kind)
        XCTAssertNil(seance.intervals)
    }

    /// C'est le chemin exact de la panne : une journée porte une séance, la séance porte un
    /// fractionné, et c'est deux niveaux plus bas que le décodage tombait.
    func testUneJourneePorteUneSeanceIncompleteSansSeffondrer() throws {
        let jour = try decoder(PlannedDay.self, #"{"weekday":3,"session":{}}"#)
        XCTAssertEqual(jour.weekday, 3)
        XCTAssertNotNil(jour.session)
        XCTAssertFalse(jour.completed)
    }

    /// UN FRACTIONNÉ VIDE N'EST PAS UN FRACTIONNÉ. Sans ça, une séance annoncerait « 0 × 0 m ».
    func testUnFractionneVideEstJeteAuLieuDeSAfficher() throws {
        let seance = try decoder(WorkoutSession.self, #"{"title":"x","intervals":{}}"#)
        XCTAssertNil(seance.intervals)

        let vrai = try decoder(WorkoutSession.self,
                               #"{"title":"x","intervals":{"reps":6,"repMeters":800}}"#)
        XCTAssertEqual(vrai.intervals?.reps, 6)
        XCTAssertEqual(vrai.intervals?.repMeters, 800)
        XCTAssertNil(vrai.intervals?.recoveryMeters)
    }

    // MARK: Les énumérations venues du futur

    /// UNE APP LIT TOUJOURS, UN JOUR, CE QU'UNE VERSION PLUS RÉCENTE A ÉCRIT.
    ///
    /// Un `rawValue` inconnu ne rend pas nil : il LÈVE. `dua_run_bike_run` a été ajouté la
    /// veille de la panne — la version installée l'avant-veille aurait buté dessus, et le
    /// chemin est le même que celui qui a tué l'app.
    func testUnTypeDeSeanceInconnuNeFaitPasEchouerLaSeance() throws {
        let seance = try decoder(WorkoutSession.self,
                                 #"{"title":"Côtes","kind":"venu_du_futur"}"#)
        XCTAssertNil(seance.kind)
        // Le titre enregistré reste, et c'est sur lui que l'affichage retombe.
        XCTAssertEqual(seance.displayTitle, "Côtes")
    }

    func testUnEtatDeJourInconnuRetombeSurUnEtatAffichable() throws {
        let jour = try decoder(DayStatus.self, #"{"weekday":2,"state":"venu_du_futur"}"#)
        XCTAssertEqual(jour.weekday, 2)
        XCTAssertEqual(jour.state, .upcoming)
    }

    func testUneMesureDeMontreInconnueRetombeSurLaDispositionStandard() throws {
        let layout = try decoder(WatchRunLayout.self,
                                 #"{"hero":"venu_du_futur","secondary":["venu_du_futur"]}"#)
        XCTAssertEqual(layout, .standard)
    }

    // MARK: Les replis ne mentent pas

    /// Un allègement dont on ne sait plus jusqu'à quand il courait est un allègement EXPIRÉ.
    /// L'inverse — un plafond éternel que plus personne ne pense à retirer — est précisément ce
    /// que l'échéance existe pour empêcher.
    func testUnAllegementSansEcheanceEstDejaExpire() throws {
        let ease = try decoder(TrainingEase.self, "{}")
        XCTAssertFalse(ease.isActive())
    }

    // MARK: Rien de tout cela n'a abîmé le cas normal

    func testUneSeanceCompleteFaitLAllerRetourSansPerdreUnChamp() throws {
        let origine = WorkoutSession(
            title: "Fractionné VMA 6 × 800 m", subtitle: "récup 400 m",
            durationMinutes: 40, pace: "4:10", zone: "Z4",
            adjustment: "+1 palier", kind: .vo2maxIntervals,
            intervals: IntervalStructure(reps: 6, repMeters: 800, recoveryMeters: 400),
            adaptationNote: "impact réduit")
        let data = try JSONEncoder().encode(origine)
        XCTAssertEqual(try JSONDecoder().decode(WorkoutSession.self, from: data), origine)
    }

    func testUneJourneeCompleteFaitLAllerRetourSansPerdreUnChamp() throws {
        let origine = PlannedDay(weekday: 5, session: .reprise, completed: true)
        let data = try JSONEncoder().encode(origine)
        XCTAssertEqual(try JSONDecoder().decode(PlannedDay.self, from: data), origine)
    }

    func testUnPointDeTraceFaitLAllerRetourSansPerdreSonAltitude() throws {
        let origine = RunRecord.RoutePoint(lat: 48.85, lng: 2.35, altitude: 112)
        let data = try JSONEncoder().encode(origine)
        XCTAssertEqual(try JSONDecoder().decode(RunRecord.RoutePoint.self, from: data), origine)
    }
}
