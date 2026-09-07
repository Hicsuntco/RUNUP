import SwiftUI

/// La vignette de tracé d'une ligne d'historique — un chemin dessiné, pas une carte.
///
/// C'était une `RunRouteMapView`, donc une vraie `MKMapView` : tuiles réseau, moteur de rendu et
/// cache, dans un carré de 52 pt. Une liste recycle ses cellules, donc ces vues étaient créées et
/// détruites PENDANT le défilement — une seule création dépasse déjà le budget d'une image à
/// 120 Hz. À cent courses dans des lieux différents, c'était aussi jusqu'à cent régions de tuiles
/// à télécharger pour des vignettes où l'on distingue à peine une boucle d'un aller-retour.
///
/// Un `Canvas` donne exactement le même rendu utile à cette taille, sans réseau ni MapKit. La fin
/// de course, elle, garde une vraie carte : à pleine largeur, le fond de plan porte du sens.
struct RouteThumbnail: View {
    var route: [RunRecord.RoutePoint]
    var lineWidth: CGFloat = 2
    var lineColor: Color = RUColor.rose
    /// Quand il est renseigné, le tracé est peint d'un dégradé plutôt que d'une couleur pleine.
    /// C'est ce que demande la carte du fil, où le tracé est le sujet de la carte et non une
    /// vignette de 52 points au bout d'une ligne.
    var gradientColors: [Color]? = nil
    /// Marque le point de départ. Invisible à 52 points, utile en grand : il dit dans quel sens la
    /// boucle a été courue, et où elle se referme.
    var showsStart = false
    /// Le nombre de points conservés. Le défaut suffit à une vignette ; une carte de fil en montre
    /// trois fois plus de large et mérite donc plus de sommets.
    var targetPoints: Int = RouteThumbnail.defaultTargetPoints

    /// ~60 points suffisent à 52 pt de côté. Au-delà, on tesselle des segments plus courts qu'un
    /// pixel.
    static let defaultTargetPoints = 60

    private var points: [CGPoint] {
        RouteGeometry.decimated(RouteGeometry.normalized(route), keeping: targetPoints)
    }

    var body: some View {
        Canvas { context, size in
            let pts = points
            guard pts.count > 1 else { return }
            // Dessiné dans le plus grand carré centré : `normalized` rend un carré, l'étirer sur
            // un rectangle défairait la correction de rapport de forme qu'il vient d'appliquer.
            let inset = lineWidth
            let side = max(min(size.width, size.height) - inset * 2, 1)
            let originX = (size.width - side) / 2
            let originY = (size.height - side) / 2

            var path = Path()
            path.move(to: CGPoint(x: originX + pts[0].x * side, y: originY + pts[0].y * side))
            for p in pts.dropFirst() {
                path.addLine(to: CGPoint(x: originX + p.x * side, y: originY + p.y * side))
            }
            let shading: GraphicsContext.Shading
            if let gradientColors, gradientColors.count > 1 {
                shading = .linearGradient(
                    Gradient(colors: gradientColors),
                    startPoint: CGPoint(x: originX, y: originY),
                    endPoint: CGPoint(x: originX + side, y: originY + side)
                )
            } else {
                shading = .color(lineColor)
            }
            context.stroke(
                path,
                with: shading,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            if showsStart {
                let start = CGPoint(x: originX + pts[0].x * side, y: originY + pts[0].y * side)
                let r = lineWidth * 1.4
                context.fill(
                    Path(ellipseIn: CGRect(x: start.x - r, y: start.y - r, width: r * 2, height: r * 2)),
                    with: .color(RUColor.lime)
                )
            }
        }
        // Le tracé est décoratif ici : la ligne porte déjà sa distance, sa durée et son allure en
        // texte, et un contour de parcours ne se décrit pas utilement à voix haute.
        .accessibilityHidden(true)
    }
}
