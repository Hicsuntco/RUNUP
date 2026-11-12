import XCTest
import SwiftData
@testable import RunUp

/// Les réparations du lancement, éprouvées — ce qui était impossible tant qu'elles vivaient dans
/// `AppState`.
///
/// # CE QUE CES CAS COUVRENT, ET QUI N'ÉTAIT PAS COUVERT
///
/// `RestDayRunTitleTests` tient la RÈGLE — `buildRunRecord` refuse d'écrire un nouveau titre de
/// jour de repos — et `ElevationGainTests` tient le CALCUL. Personne ne tenait la RÉPARATION
/// elle-même : le marqueur qui la fait tourner une seule fois, la sélection des lignes à toucher,
/// et le fait qu'elle ne touche pas les autres.
///
/// Elle n'était pas tenue parce qu'elle n'était pas atteignable : deux méthodes `private` d'un
/// objet qu'un test ne peut pas construire sans toute l'app derrière. C'est la même histoire que
/// `LocationService.majDeLaDistance`, dont le commentaire raconte qu'une règle corrigeant une
/// erreur de cinquante pour cent n'avait aucun test pour cette seule raison.
final class ReparationsAuLancementTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: RunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // LES MARQUEURS VIVENT DANS `UserDefaults`, QUI EST PARTAGÉ PAR TOUTE LA SUITE.
        //
        // Sans ce nettoyage, le premier cas poserait le marqueur et les suivants ne verraient
        // plus rien tourner — ils passeraient en n'éprouvant rien. Les clés sont LUES sur le type
        // plutôt que recopiées : une clé recopiée qui dérive donne exactement ce faux vert.
        UserDefaults.standard.removeObject(forKey: ReparationsAuLancement.Marqueur.titresDesJoursDeRepos)
        UserDefaults.standard.removeObject(forKey: ReparationsAuLancement.Marqueur.denivelePositif)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ReparationsAuLancement.Marqueur.titresDesJoursDeRepos)
        UserDefaults.standard.removeObject(forKey: ReparationsAuLancement.Marqueur.denivelePositif)
        container = nil
        super.tearDown()
    }

    @MainActor
    private func course(titre: String, kind: SessionKind? = nil, km: Double = 7.4,
                        dplus: Int = 0, altitudes: [Double] = []) -> RunRecord {
        let trace = altitudes.map { RunRecord.RoutePoint(lat: 48.85, lng: 2.35, altitude: $0) }
        let r = RunRecord(date: .now, title: titre, distanceKm: km, durationSeconds: 2718,
                          avgPace: "6:08", avgHeartRate: 142, kcal: 420, sessionKind: kind)
        r.elevationGainM = dplus
        r.route = trace
        container.mainContext.insert(r)
        return r
    }

    // MARK: Les titres de jour de repos

    /// « Repos · 7,4 km · 45:18 » est une ligne qui se contredit dans sa propre largeur.
    @MainActor
    func testUneCourseTitreeReposEstRenommee() {
        let r = course(titre: "Repos", kind: .rest)
        ReparationsAuLancement.renommerLesCoursesDuJourDeRepos(container.mainContext)
        XCTAssertNotEqual(r.title, "Repos")
        XCTAssertEqual(r.title, String(localized: "Séance libre"))
    }

    /// LE CRITÈRE EST LE TYPE, PAS LE TEXTE — mais le texte reste le repli des courses d'avant
    /// que `sessionKind` existe. Les deux chemins doivent attraper.
    @MainActor
    func testUneCourseSansTypeMaisTitreeReposEstRenommeeAussi() {
        let r = course(titre: "Repos", kind: nil)
        ReparationsAuLancement.renommerLesCoursesDuJourDeRepos(container.mainContext)
        XCTAssertEqual(r.title, String(localized: "Séance libre"))
    }

    /// Une vraie séance n'est pas touchée. Une réparation qui renomme trop est pire qu'une
    /// réparation absente : elle efface ce que quelqu'un a couru.
    @MainActor
    func testUneVraieSeanceNEstPasTouchee() {
        let r = course(titre: "Fractionné 5 × 500 m", kind: .vo2maxIntervals)
        ReparationsAuLancement.renommerLesCoursesDuJourDeRepos(container.mainContext)
        XCTAssertEqual(r.title, "Fractionné 5 × 500 m")
    }

    /// LA RÉPARATION NE TOURNE QU'UNE FOIS PAR INSTALLATION, et ce cas fixe ce que ça coûte.
    ///
    /// Ce n'est pas une règle, c'est une réparation : le marqueur évite de relire tout
    /// l'historique à chaque lancement. La contrepartie est qu'une ligne arrivée APRÈS — par une
    /// restauration de sauvegarde, par exemple — ne sera pas réparée. C'est écrit ici pour que
    /// personne ne le découvre en s'étonnant.
    @MainActor
    func testElleNeTourneQuUneFois() {
        _ = course(titre: "Repos", kind: .rest)
        ReparationsAuLancement.renommerLesCoursesDuJourDeRepos(container.mainContext)
        XCTAssertTrue(UserDefaults.standard.bool(
            forKey: ReparationsAuLancement.Marqueur.titresDesJoursDeRepos))

        let tardive = course(titre: "Repos", kind: .rest)
        ReparationsAuLancement.renommerLesCoursesDuJourDeRepos(container.mainContext)
        XCTAssertEqual(tardive.title, "Repos", "le marqueur était posé : rien ne se relit")
    }

    // MARK: Le dénivelé positif

    /// L'ANCIEN CALCUL SOMMAIT LA MOITIÉ POSITIVE D'UN BRUIT SYMÉTRIQUE, et fabriquait des
    /// milliers de mètres de D+ sur de l'immobilité. Toutes les sorties de l'historique portent
    /// ce chiffre, et le badge « 300 m de D+ » du Club s'est décerné dessus.
    @MainActor
    func testUnDenivelleGonfleEstCorrigeVersLeBas() {
        // Une suite d'altitudes qui oscille : du bruit, pas une côte.
        let bruit = (0..<60).map { 100.0 + ($0 % 2 == 0 ? 0.8 : -0.8) }
        let r = course(titre: "Sortie", kind: .easyFooting, dplus: 1200, altitudes: bruit)
        ReparationsAuLancement.recalculerLeDenivelePositif(container.mainContext)
        XCTAssertLessThan(r.elevationGainM, 1200, "le D+ gonflé doit descendre")
        XCTAssertTrue(UserDefaults.standard.bool(
            forKey: ReparationsAuLancement.Marqueur.denivelePositif))
    }

    /// ELLE NE PEUT QUE DESCENDRE. Le défaut d'origine ne pouvait que gonfler le chiffre : une
    /// réparation qui le ferait monter corrigerait dans le mauvais sens, et personne ne verrait
    /// la différence entre un vrai dénivelé et un bruit réinterprété.
    @MainActor
    func testElleNeFaitJamaisMonterUnDenivelle() {
        let plat = Array(repeating: 100.0, count: 60)
        let r = course(titre: "Sortie plate", kind: .easyFooting, dplus: 3, altitudes: plat)
        ReparationsAuLancement.recalculerLeDenivelePositif(container.mainContext)
        XCTAssertLessThanOrEqual(r.elevationGainM, 3)
    }

    /// Une course sans tracé n'a pas d'altitudes à rejouer : on ne la touche pas plutôt que de
    /// lui inventer un zéro.
    @MainActor
    func testUneCourseSansTraceGardeSonDenivelle() {
        let r = course(titre: "Saisie à la main", kind: .easyFooting, dplus: 250, altitudes: [])
        ReparationsAuLancement.recalculerLeDenivelePositif(container.mainContext)
        XCTAssertEqual(r.elevationGainM, 250)
    }
}
