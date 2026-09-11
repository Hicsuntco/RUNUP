import XCTest
@testable import RunUp

/// L'aller-retour disque de la file d'envoi du Club.
///
/// La file existe pour une seule raison : qu'une sortie finie hors réseau parte quand même, plus
/// tard, ENTIÈRE. Elle est relue depuis le disque à ce moment-là — donc tout ce que l'encodage
/// oublie est perdu pour de bon, silencieusement, et seulement chez les gens hors réseau.
final class ClubOutboxCodableTests: XCTestCase {
    private func aller_retour(_ entree: PendingClubActivity) throws -> PendingClubActivity {
        let data = try JSONEncoder().encode(entree)
        return try JSONDecoder().decode(PendingClubActivity.self, from: data)
    }

    /// Le test qui aurait attrapé la perte de `contentKey` et de `trace` à la seconde près.
    func testEntreeCompleteSurvitAuDisque() throws {
        let entree = PendingClubActivity(
            clientId: UUID(), type: "run", text: "a couru 10 km", xpEarned: 120,
            metrics: ActivityMetrics(distanceKm: 10.2), userId: "u1",
            contentKey: "long_run",
            trace: [RunRecord.RoutePoint(lat: 48.85, lng: 2.35),
                    RunRecord.RoutePoint(lat: 48.86, lng: 2.36)])
        XCTAssertEqual(try aller_retour(entree), entree)
    }

    /// Chaque champ optionnel séparément : un `encodeIfPresent` oublié ne se voit que sur le sien.
    func testChaqueChampOptionnelSurvitSeul() throws {
        let base = PendingClubActivity(clientId: UUID(), type: "run", text: "t", xpEarned: 10,
                                       metrics: nil, userId: nil, contentKey: nil, trace: nil)
        var avecCle = base; avecCle.contentKey = "tempo"
        XCTAssertEqual(try aller_retour(avecCle).contentKey, "tempo")

        var avecTrace = base
        avecTrace.trace = [RunRecord.RoutePoint(lat: 1, lng: 2)]
        XCTAssertEqual(try aller_retour(avecTrace).trace?.count, 1)

        var avecMetriques = base; avecMetriques.metrics = ActivityMetrics(distanceKm: 5)
        XCTAssertEqual(try aller_retour(avecMetriques).metrics?.distanceKm, 5)

        var avecProprietaire = base; avecProprietaire.userId = "u9"
        XCTAssertEqual(try aller_retour(avecProprietaire).userId, "u9")
    }

    /// Une entrée écrite AVANT le regroupement des métriques porte `distanceKm` à la racine. Elle
    /// doit se relire — c'est toute la raison d'être de la clé héritée.
    func testAncienFormatSeRelit() throws {
        let json = """
        {"clientId":"\(UUID().uuidString)","type":"run","text":"t","xpEarned":120,"distanceKm":8.4}
        """.data(using: .utf8)!
        let relu = try JSONDecoder().decode(PendingClubActivity.self, from: json)
        XCTAssertEqual(relu.metrics?.distanceKm, 8.4)
        // Et elle ne doit pas être RÉÉCRITE dans l'ancien format : la clé est en lecture seule.
        let reencode = try JSONEncoder().encode(relu)
        let objet = try XCTUnwrap(try JSONSerialization.jsonObject(with: reencode) as? [String: Any])
        XCTAssertNil(objet["distanceKm"])
        XCTAssertNotNil(objet["metrics"])
    }

    /// Une entrée sans propriétaire appartient à qui la relit — le cas d'une sortie mise en file
    /// avant la connexion. Le `nil` doit survivre au disque, sinon elle devient orpheline.
    func testEntreeSansProprietaire() throws {
        let entree = PendingClubActivity(clientId: UUID(), type: "run", text: "t", xpEarned: 0,
                                         metrics: nil, userId: nil, contentKey: nil, trace: nil)
        XCTAssertNil(try aller_retour(entree).userId)
    }
}
