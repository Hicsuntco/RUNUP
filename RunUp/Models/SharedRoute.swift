import Foundation
import CoreLocation

/// Un itinéraire publié par quelqu'un, tel que le serveur le rend.
///
/// Ce n'est pas un `@Model` SwiftData, contrairement à `RunRecord` : c'est de la donnée distante,
/// consultée en passant quand on cherche où courir dans une ville qu'on ne connaît pas, et qui
/// n'a aucune raison de vivre sur le téléphone entre deux consultations. Seuls les itinéraires
/// que l'utilisatrice enregistre valent la peine d'être retenus, et c'est le serveur qui tient
/// cette liste (`route_saves`), pas le disque local.
struct SharedRoute: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    /// Écrit par l'autrice, visible par des inconnus — d'où le filtre de modération côté serveur.
    var notes: String?
    var distanceKm: Double?
    var elevationGainM: Int?
    /// Le temps qu'a mis la personne qui a publié, à titre indicatif. Ce n'est PAS un objectif :
    /// l'afficher comme tel transformerait une carte d'entraide en classement déguisé.
    var durationSeconds: Int?

    /// Une vingtaine de points, assez pour reconnaître la forme du parcours dans une liste ou sur
    /// une carte dézoomée. Toujours présent.
    var preview: [[Double]]
    /// Le tracé complet — présent uniquement quand on a ouvert l'itinéraire (`fetchRoute`), jamais
    /// dans la liste : cinquante tracés complets, c'est plusieurs mégaoctets pour dessiner des
    /// gribouillis de quelques millimètres.
    var points: [[Double]]?

    /// Le départ du tracé ROGNÉ, donc à ~300 m du vrai point de départ de la personne qui l'a
    /// publié (voir `RouteGeometry.trimmedForSharing`). C'est ce point qui épingle l'itinéraire
    /// sur la carte de découverte.
    var startLat: Double
    var startLng: Double
    var locality: String?
    var countryCode: String?
    var photoUrl: String?

    var savesCount: Int
    /// Vrai si l'utilisatrice courante l'a enregistré.
    var saved: Bool
    var createdAt: Date

    var authorName: String?
    var authorUsername: String?
    var authorAvatarUrl: String?

    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLat, longitude: startLng)
    }

    /// Les coordonnées à dessiner : le tracé complet s'il a été chargé, l'aperçu sinon.
    var drawableCoordinates: [CLLocationCoordinate2D] {
        (points ?? preview).compactMap { pair in
            guard pair.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
    }

    /// « Lisbonne · 10,2 km » — l'étiquette d'une ligne de liste. La localité vient du géocodage
    /// fait sur l'appareil de la personne qui a publié, donc elle peut manquer.
    var subtitleLine: String {
        let distance = distanceKm.map { String(format: "%.1f km", locale: Locale.current, $0) }
        return [locality, distance].compactMap { $0 }.joined(separator: " · ")
    }
}

struct SharedRoutesResponse: Decodable {
    var routes: [SharedRoute]
}

struct SharedRouteResponse: Decodable {
    var route: SharedRoute
}

struct MyRoutesResponse: Decodable {
    var published: [SharedRoute]
    var saved: [SharedRoute]
}

struct RouteSaveResponse: Decodable {
    var ok: Bool
    var savesCount: Int
}

struct RoutePublishResponse: Decodable {
    var ok: Bool
    var id: String?
}

struct RoutePhotoResponse: Decodable {
    var ok: Bool
    var photoUrl: String?
}
