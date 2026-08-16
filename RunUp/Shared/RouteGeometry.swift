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
