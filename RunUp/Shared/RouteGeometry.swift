import CoreGraphics
import Foundation

/// La projection d'un tracé GPS vers un carré à dessiner — partagée par la carte de partage et la
/// vignette de l'historique, pour que le MÊME parcours ait la MÊME forme aux deux endroits.
enum RouteGeometry {
    /// Les points ramenés dans un carré 0…1, centrés, à leur vrai rapport de forme.
    ///
    /// La longitude est corrigée de la compression méridienne (`× cos(latitude)`) avant toute
    /// mise à l'échelle. Sans ça, un degré de longitude est traité comme un degré de latitude
    /// alors qu'à Paris il ne vaut que 0,66 fois sa distance : une boucle est-ouest sortait
    /// ~52 % trop large. C'est une projection équirectangulaire centrée sur la course — sur
    /// quelques kilomètres, l'écart avec le Mercator sphérique de MapKit est inférieur à
    /// l'épaisseur du trait.
    ///
    /// Le résultat est un CARRÉ : il doit être dessiné dans un carré, sinon l'étirement redéfait
    /// exactement le travail fait ici.
    static func normalized(_ route: [RunRecord.RoutePoint]) -> [CGPoint] {
        guard route.count > 1 else { return [] }
        let lats = route.map(\.lat)
        let lngs = route.map(\.lng)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max()
        else { return [] }

        let midLat = (minLat + maxLat) / 2
        // 1 à l'équateur, ~0,66 à Paris, ~0 aux pôles — d'où le plancher, sans effet au-delà de
        // 100 km d'un pôle.
        let lngScale = max(cos(midLat * .pi / 180), 0.000001)
        let width = (maxLng - minLng) * lngScale
        let height = maxLat - minLat
        let span = max(width, height, 0.00001)

        return route.map { point in
            let x = ((point.lng - minLng) * lngScale + (span - width) / 2) / span
            // La latitude croît vers le nord, y croît vers le bas à l'écran.
            let y = 1 - ((point.lat - minLat) + (span - height) / 2) / span
            return CGPoint(x: x, y: y)
        }
    }

    /// Un point sur `stride`, en gardant toujours le premier et le dernier.
    ///
    /// Une sortie d'une heure accumule un bon millier de points. À 52 pt de côté c'est trois à dix
    /// points par pixel : le tracé décimé est rigoureusement identique à l'œil, pour un dixième
    /// des segments à tesseller.
    static func decimated(_ points: [CGPoint], keeping target: Int) -> [CGPoint] {
        guard points.count > target, target > 1 else { return points }
        let stride = Double(points.count - 1) / Double(target - 1)
        var out = (0..<target).map { points[Int((Double($0) * stride).rounded())] }
        if let last = points.last, out.last != last { out[out.count - 1] = last }
        return out
    }
}

// MARK: - Publication d'un itinéraire

extension RouteGeometry {
    /// Ce qu'on retire à CHAQUE extrémité d'un tracé avant de le publier.
    ///
    /// Un tracé GPS brut commence et finit devant chez soi. Le publier tel quel, c'est publier une
    /// adresse — et, à raison d'une sortie par jour, l'horaire auquel on n'y est pas. Trois cents
    /// mètres suffisent à noyer le point de départ dans un quartier sans dénaturer le parcours :
    /// c'est l'ordre de grandeur des « zones de confidentialité » que Strava a fini par adopter,
    /// après la carte de chaleur de 2018 qui avait révélé le tracé de bases militaires.
    static let sharingTrimMeters: Double = 300

    /// En dessous, il ne reste rien d'utile après rognage : on refuse de publier plutôt que de
    /// mettre en ligne un moignon de tracé.
    static let minimumShareableMeters: Double = 1000

    /// Distance en mètres entre deux points GPS (formule de haversine).
    ///
    /// La projection équirectangulaire de `normalized` suffit à DESSINER un parcours ; elle ne
    /// suffit pas à décider où couper, parce qu'une erreur de quelques dizaines de mètres ici se
    /// paie en vie privée. Haversine coûte deux sinus de plus et ne se trompe pas.
    static func distanceMeters(_ a: RunRecord.RoutePoint, _ b: RunRecord.RoutePoint) -> Double {
        let earthRadius = 6_371_000.0
        let phi1 = a.lat * .pi / 180
        let phi2 = b.lat * .pi / 180
        let deltaPhi = (b.lat - a.lat) * .pi / 180
        let deltaLambda = (b.lng - a.lng) * .pi / 180
        let h = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }

    /// Longueur totale du tracé, en mètres.
    static func lengthMeters(_ route: [RunRecord.RoutePoint]) -> Double {
        guard route.count > 1 else { return 0 }
        return zip(route, route.dropFirst()).reduce(0) { $0 + distanceMeters($1.0, $1.1) }
    }

    /// Le tracé amputé de ses `meters` premiers ET derniers mètres.
    ///
    /// Appelé sur le téléphone, avant tout envoi : le serveur ne reçoit jamais les extrémités
    /// réelles, donc il ne peut pas les divulguer, quoi qu'il lui arrive plus tard. Rogner côté
    /// serveur aurait été plus simple et strictement moins sûr.
    ///
    /// Rend un tableau vide s'il ne reste pas au moins deux points — l'appelant doit traiter ce cas
    /// comme « ce parcours n'est pas publiable », jamais comme « publier le tracé d'origine ».
    ///
    /// LIMITE CONNUE, à dire plutôt qu'à taire : le rognage se mesure le long du PARCOURS, pas à vol
    /// d'oiseau. Une boucle qui repasse devant chez soi au milieu de la sortie n'est donc pas
    /// protégée à cet endroit-là. Couvrir ce cas demanderait de retirer tout point situé à moins de
    /// 300 m du départ réel, ce qui coupe le tracé en morceaux et le rend illisible. Strava vit avec
    /// la même limite. Si un jour ça se révèle insuffisant, la bonne réponse est une zone de
    /// confidentialité choisie par l'utilisatrice, pas un rognage plus agressif.
    static func trimmedForSharing(_ route: [RunRecord.RoutePoint],
                                  meters: Double = sharingTrimMeters) -> [RunRecord.RoutePoint] {
        guard route.count > 1, meters > 0 else { return route.count > 1 ? route : [] }

        // Premier indice dont la distance cumulée depuis le départ dépasse le seuil.
        var accumulated = 0.0
        var startIndex = route.count
        for i in 1..<route.count {
            accumulated += distanceMeters(route[i - 1], route[i])
            if accumulated >= meters { startIndex = i; break }
        }
        // Dernier indice dont la distance cumulée depuis l'arrivée dépasse le seuil.
        accumulated = 0
        var endIndex = -1
        for i in stride(from: route.count - 1, to: 0, by: -1) {
            accumulated += distanceMeters(route[i], route[i - 1])
            if accumulated >= meters { endIndex = i - 1; break }
        }

        guard startIndex < endIndex else { return [] }
        return Array(route[startIndex...endIndex])
    }

    /// Un tracé publiable, ou `nil` si ce parcours ne doit pas l'être.
    ///
    /// Le seul point d'entrée que l'interface doit appeler : il applique le rognage ET la longueur
    /// minimale, pour qu'aucun écran ne puisse publier un tracé non rogné en oubliant une étape.
    static func shareablePayload(_ route: [RunRecord.RoutePoint])
        -> (points: [RunRecord.RoutePoint], preview: [RunRecord.RoutePoint])? {
        let trimmed = trimmedForSharing(route)
        guard trimmed.count > 1, lengthMeters(trimmed) >= minimumShareableMeters else { return nil }
        // 600 points suffisent à redessiner un parcours au mètre près à l'écran ; 24 suffisent à
        // en reconnaître la forme dans une liste. Les deux plafonds correspondent à ceux que
        // `api/activities/[action].js` accepte.
        let full = decimatedPoints(trimmed, keeping: 600)
        return (full, decimatedPoints(full, keeping: 24))
    }

    /// `decimated`, mais sur des points GPS plutôt que sur des points déjà projetés.
    static func decimatedPoints(_ route: [RunRecord.RoutePoint], keeping target: Int) -> [RunRecord.RoutePoint] {
        guard route.count > target, target > 1 else { return route }
        let step = Double(route.count - 1) / Double(target - 1)
        var out = (0..<target).map { route[Int((Double($0) * step).rounded())] }
        if let last = route.last { out[out.count - 1] = last }
        return out
    }
}
