import XCTest
@testable import RunUp

/// Verrouille la règle de confidentialité des itinéraires partagés.
///
/// Comme les tests du moteur de programme, ceux-ci ne sont pas là pour la couverture. Publier un
/// tracé GPS brut publie une adresse : celle d'où l'on part chaque matin, et l'horaire auquel on
/// n'y est pas. `RouteGeometry.trimmedForSharing` est le seul endroit du code où une erreur a cette
/// conséquence-là, et rien à l'écran ne la rendrait visible — un tracé trop peu rogné ressemble
/// exactement à un tracé bien rogné. D'où des assertions sur les mètres réellement retirés.
final class RouteSharingPrivacyTests: XCTestCase {

    // MARK: - Fixtures

    /// Un tracé rectiligne vers l'est, à Paris, avec un point tous les `stepMeters`.
    ///
    /// Une ligne droite est le pire cas pour le rognage : sur une boucle, les premiers points
    /// finissent loin du départ dès qu'on tourne, alors qu'ici chaque mètre parcouru est un mètre
    /// gagné en éloignement. Si la règle tient sur une ligne droite, elle tient partout.
    private func straightLine(pointCount: Int, stepMeters: Double) -> [RunRecord.RoutePoint] {
        let startLat = 48.8566
        let startLng = 2.3522
        // À cette latitude, un degré de longitude vaut ~73 km ; on en déduit le pas en degrés.
        let metersPerDegreeLng = 111_320.0 * cos(startLat * .pi / 180)
        return (0..<pointCount).map { i in
            RunRecord.RoutePoint(
                lat: startLat,
                lng: startLng + (Double(i) * stepMeters) / metersPerDegreeLng,
                altitude: 35
            )
        }
    }

    // MARK: - Le rognage retire bien ce qu'il annonce

    func testTrimRemovesAtLeastTheTrimDistanceFromBothEnds() {
        // 3 km, un point tous les 10 m.
        let route = straightLine(pointCount: 301, stepMeters: 10)
        let trimmed = RouteGeometry.trimmedForSharing(route)

        XCTAssertGreaterThan(trimmed.count, 1, "un parcours de 3 km doit rester publiable")

        let droppedAtStart = RouteGeometry.distanceMeters(route[0], trimmed[0])
        let droppedAtEnd = RouteGeometry.distanceMeters(route[route.count - 1], trimmed[trimmed.count - 1])

        // « Au moins », pas « exactement » : on coupe sur un point existant, donc on retire
        // toujours un peu plus que le seuil. Retirer MOINS serait le défaut dangereux.
        XCTAssertGreaterThanOrEqual(droppedAtStart, RouteGeometry.sharingTrimMeters)
        XCTAssertGreaterThanOrEqual(droppedAtEnd, RouteGeometry.sharingTrimMeters)
        // Et pas non plus n'importe quoi : un point tous les 10 m borne le dépassement.
        XCTAssertLessThan(droppedAtStart, RouteGeometry.sharingTrimMeters + 20)
        XCTAssertLessThan(droppedAtEnd, RouteGeometry.sharingTrimMeters + 20)
    }

    /// Le cas qui compte vraiment : aucun point publié ne doit se trouver à moins de 300 m d'une
    /// des deux extrémités réelles. C'est la formulation de la promesse, indépendamment de la façon
    /// dont le rognage est implémenté.
    func testNoPublishedPointSitsNearTheRealEndpoints() {
        let route = straightLine(pointCount: 301, stepMeters: 10)
        guard let payload = RouteGeometry.shareablePayload(route) else {
            return XCTFail("un parcours de 3 km doit être publiable")
        }
        let realStart = route[0]
        let realEnd = route[route.count - 1]

        for point in payload.points {
            XCTAssertGreaterThanOrEqual(RouteGeometry.distanceMeters(point, realStart),
                                        RouteGeometry.sharingTrimMeters)
            XCTAssertGreaterThanOrEqual(RouteGeometry.distanceMeters(point, realEnd),
                                        RouteGeometry.sharingTrimMeters)
        }
        // L'aperçu part sur la carte de découverte comme le tracé complet — il ne bénéficie
        // d'aucune indulgence.
        for point in payload.preview {
            XCTAssertGreaterThanOrEqual(RouteGeometry.distanceMeters(point, realStart),
                                        RouteGeometry.sharingTrimMeters)
            XCTAssertGreaterThanOrEqual(RouteGeometry.distanceMeters(point, realEnd),
                                        RouteGeometry.sharingTrimMeters)
        }
    }

    // MARK: - Les parcours trop courts ne sont pas publiables

    func testRouteShorterThanTwiceTheTrimIsRefused() {
        // 400 m : rogner 300 m de chaque côté ne laisse rien.
        let route = straightLine(pointCount: 41, stepMeters: 10)
        XCTAssertTrue(RouteGeometry.trimmedForSharing(route).isEmpty)
        XCTAssertNil(RouteGeometry.shareablePayload(route),
                     "un parcours plus court que le rognage doit être refusé, jamais publié brut")
    }

    func testRouteJustAboveTheTrimButUnderTheMinimumIsRefused() {
        // 900 m : il reste ~300 m après rognage, donc un tracé non vide — mais sous le plancher
        // publiable. C'est le piège : `trimmedForSharing` rend quelque chose, et il faut quand
        // même refuser.
        let route = straightLine(pointCount: 91, stepMeters: 10)
        XCTAssertFalse(RouteGeometry.trimmedForSharing(route).isEmpty)
        XCTAssertNil(RouteGeometry.shareablePayload(route))
    }

    func testEmptyAndSinglePointRoutesAreRefused() {
        XCTAssertNil(RouteGeometry.shareablePayload([]))
        XCTAssertNil(RouteGeometry.shareablePayload([RunRecord.RoutePoint(lat: 48.85, lng: 2.35, altitude: 0)]))
    }

    // MARK: - Aller-retour : départ et arrivée au même endroit

    /// Un aller-retour finit là où il commence. Rogner les deux extrémités doit protéger ce point
    /// unique deux fois — un rognage qui ne s'occuperait que du départ laisserait l'arrivée, donc
    /// la même adresse, en clair.
    func testOutAndBackProtectsTheSharedEndpoint() {
        let outward = straightLine(pointCount: 151, stepMeters: 10)      // 1,5 km aller
        let route = outward + outward.dropLast().reversed()              // 3 km aller-retour
        guard let payload = RouteGeometry.shareablePayload(route) else {
            return XCTFail("un aller-retour de 3 km doit être publiable")
        }
        let home = route[0]
        for point in payload.points {
            XCTAssertGreaterThanOrEqual(RouteGeometry.distanceMeters(point, home),
                                        RouteGeometry.sharingTrimMeters)
        }
    }

    // MARK: - Plafonds attendus par le serveur

    func testPayloadRespectsServerLimits() {
        // 20 km, un point toutes les 2 s de course ≈ 6000 points : bien au-delà des plafonds.
        let route = straightLine(pointCount: 6000, stepMeters: 3.3)
        guard let payload = RouteGeometry.shareablePayload(route) else {
            return XCTFail("un parcours de 20 km doit être publiable")
        }
        // `api/activities/[action].js` refuse au-delà : MAX_ROUTE_POINTS = 600, MAX_PREVIEW_POINTS = 32.
        XCTAssertLessThanOrEqual(payload.points.count, 600)
        XCTAssertLessThanOrEqual(payload.preview.count, 32)
        XCTAssertGreaterThan(payload.preview.count, 1)
    }
}
