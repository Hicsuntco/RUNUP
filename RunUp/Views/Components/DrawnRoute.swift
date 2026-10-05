import SwiftUI

/// Le tracé d'une course qui se REDESSINE, du départ à l'arrivée, avec la tête lumineuse qui
/// avance dessus.
///
/// # POURQUOI
///
/// `RouteThumbnail` pose le tracé d'un coup, déjà fini. C'est juste pour une vignette de 52
/// points au bout d'une ligne d'historique. Ça ne l'est plus quand le tracé est le SUJET de
/// l'écran — la fin de course, la carte du fil — parce qu'un parcours posé d'un bloc est une
/// forme, alors qu'un parcours qui se dessine est un RÉCIT : on voit la boucle partir, hésiter au
/// carrefour, revenir. C'est la seule chose à l'écran qui raconte quelque chose que la personne a
/// vraiment fait.
///
/// # LA TÊTE EST CE QUI FAIT LA DIFFÉRENCE
///
/// Un trait qui s'allonge se lit comme un chargement. Le même trait avec un point lumineux à son
/// extrémité se lit comme un déplacement — l'œil suit la tête, pas la longueur. Deux cercles : un
/// net, un flou derrière, dans un calque à part pour que le flou ne mange pas le trait.
///
/// # LA GÉOMÉTRIE N'EST PAS RECOPIÉE
///
/// `RouteGeometry.normalized` et `.decimated` font déjà le cadrage et l'allègement pour
/// `RouteThumbnail`. Les refaire ici donnerait deux tracés légèrement différents pour la même
/// course, visibles côte à côte dans l'historique.
struct DrawnRoute: View, Animatable {
    var route: [RunRecord.RoutePoint]
    var lineWidth: CGFloat = 3
    /// Le tracé est peint d'un dégradé d'accent : il part discret et arrive à pleine valeur, donc
    /// l'arrivée est le point le plus lumineux de la forme.
    var colors: [Color] = [RUColor.rose2, RUColor.rose, RUColor.violet]
    /// Plus de sommets qu'une vignette : à pleine largeur, 60 points donnent une ligne brisée.
    var targetPoints: Int = 220
    /// Marque le départ d'un anneau creux une fois le tracé fini.
    var showsStart = true
    /// 0 = rien, 1 = le tracé entier. Animable par l'appelant.
    var progress: Double

    /// SANS CECI, LE TRACÉ SAUTE AU LIEU DE SE DESSINER. `withAnimation` interpole les propriétés
    /// ANIMABLES d'une vue ; un `Double` stocké n'en est pas une, et SwiftUI se contenterait de
    /// réévaluer le corps une fois, avec la valeur finale. Déclarer la vue `Animatable` et
    /// exposer `progress` comme sa donnée animable fait redessiner le `Canvas` à chaque image
    /// intermédiaire — c'est là, et seulement là, que le dessin existe.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private var points: [CGPoint] {
        RouteGeometry.decimated(RouteGeometry.normalized(route), keeping: targetPoints)
    }

    var body: some View {
        Canvas { context, size in
            let pts = points
            guard pts.count > 1 else { return }

            // Dessiné dans le plus grand carré centré, comme `RouteThumbnail` : `normalized` rend
            // un carré, l'étirer sur un rectangle défairait sa correction de rapport de forme.
            let inset = lineWidth * 2
            let side = max(min(size.width, size.height) - inset * 2, 1)
            let originX = (size.width - side) / 2
            let originY = (size.height - side) / 2
            func place(_ p: CGPoint) -> CGPoint {
                CGPoint(x: originX + p.x * side, y: originY + p.y * side)
            }

            var full = Path()
            full.move(to: place(pts[0]))
            for p in pts.dropFirst() { full.addLine(to: place(p)) }

            let t = min(max(progress, 0), 1)
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: originX, y: originY + side),
                endPoint: CGPoint(x: originX + side, y: originY)
            )

            // Le chemin déjà parcouru. `trimmedPath` coupe à la longueur, pas au nombre de
            // segments : la tête avance donc à vitesse constante, quelle que soit la densité des
            // points — dense dans les virages, clairsemée en ligne droite.
            let drawn = full.trimmedPath(from: 0, to: t)

            // La trace fantôme du reste du parcours. Sans elle, l'œil ne sait pas où ça va et le
            // dessin se lit comme une barre de progression. Avec elle, on voit la forme à remplir.
            context.stroke(full, with: .color(RUColor.textPrimary.opacity(0.07)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // Le halo, dans son propre calque : un filtre appliqué au contexte principal flouterait
            // aussi le trait net dessiné juste après.
            context.drawLayer { halo in
                halo.addFilter(.blur(radius: lineWidth * 2.2))
                halo.stroke(drawn, with: shading,
                            style: StrokeStyle(lineWidth: lineWidth * 1.6, lineCap: .round, lineJoin: .round))
            }
            context.stroke(drawn, with: shading,
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            if showsStart, t > 0.02 {
                let start = place(pts[0])
                let r = lineWidth * 1.5
                context.stroke(Path(ellipseIn: CGRect(x: start.x - r, y: start.y - r,
                                                      width: r * 2, height: r * 2)),
                               with: .color(RUColor.textPrimary.opacity(0.85)),
                               lineWidth: lineWidth * 0.7)
            }

            // La tête. Elle disparaît une fois arrivée : un point lumineux qui reste au bout d'un
            // tracé fini n'est plus un déplacement, c'est une pastille de notification.
            if t > 0.01 && t < 0.995 {
                let head = headPoint(of: full, at: t) ?? place(pts[0])
                let r = lineWidth * 1.35
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: lineWidth * 3))
                    glow.fill(Path(ellipseIn: CGRect(x: head.x - r * 2.2, y: head.y - r * 2.2,
                                                     width: r * 4.4, height: r * 4.4)),
                              with: .color(colors.last ?? RUColor.rose))
                }
                context.fill(Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(RUColor.textPrimary))
            }
        }
    }

    /// Où se trouve l'extrémité du chemin déjà parcouru.
    ///
    /// Obtenue en découpant une tranche très courte juste avant `t` et en prenant son coin : un
    /// segment d'un millième de la longueur est trop petit pour qu'on distingue son coin de son
    /// milieu, et c'est beaucoup moins de calcul que de reparcourir les points pour cumuler les
    /// longueurs à chaque image.
    private func headPoint(of path: Path, at t: Double) -> CGPoint? {
        let slice = path.trimmedPath(from: max(0, t - 0.001), to: t)
        let box = slice.boundingRect
        guard !box.isNull, box.width.isFinite, box.height.isFinite else { return nil }
        return CGPoint(x: box.midX, y: box.midY)
    }
}

/// `DrawnRoute` qui se dessine tout seul en apparaissant.
///
/// Séparé pour que l'appelant qui a déjà une progression à lui — un curseur de lecture, un
/// défilement — puisse piloter `DrawnRoute` directement sans se battre contre une animation
/// interne qu'il n'a pas demandée.
struct SelfDrawingRoute: View {
    var route: [RunRecord.RoutePoint]
    var lineWidth: CGFloat = 3
    var colors: [Color] = [RUColor.rose2, RUColor.rose, RUColor.violet]
    var targetPoints: Int = 220
    var showsStart = true

    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        DrawnRoute(route: route, lineWidth: lineWidth, colors: colors,
                   targetPoints: targetPoints, showsStart: showsStart, progress: progress)
            .onAppear {
                guard progress == 0 else { return }
                if reduceMotion { progress = 1 } else {
                    withAnimation(RUMotion.draw) { progress = 1 }
                }
            }
    }
}
