import SwiftUI

/// The app's logo mark — "Stride Bars": 4 rounded-cap strokes of increasing height (stride/
/// cadence, reading left→right as acceleration) on a rounded-square tile filled with the brand
/// gradient. Geometry ported 1:1 from the design handoff's 100×100 SVG viewBox (see LOGO.md) —
/// deliberately not a progress-ring glyph or parallel bars, both dropped in the handoff for
/// reading too close to existing marks (Apple Fitness rings / adidas stripes).
struct AppMarkView: View, Animatable {
    var size: CGFloat = 24
    var radius: CGFloat? = nil
    var color: Color = .white
    /// L'avancement du TRACÉ des quatre barres : 0 = la tuile nue, 1 = la marque entière.
    ///
    /// Par défaut 1, donc tous les appels existants — barre d'onglets, notification, en-tête —
    /// rendent exactement ce qu'ils rendaient. Seul le lancement s'en sert pour faire naître la
    /// marque trait par trait, et il le fait sur CETTE géométrie plutôt que sur une copie : les
    /// quatre couples de coordonnées ci-dessous viennent de la maquette, et deux exemplaires
    /// auraient divergé au premier ajustement.
    var drawn: Double = 1

    var animatableData: Double {
        get { drawn }
        set { drawn = newValue }
    }

    private var cornerRadius: CGFloat { radius ?? size * 0.26 }
    private var glyphSize: CGFloat { size * 0.62 }

    /// (x1, y1, x2, y2, lineWidth, opacity) in the design's 100×100 viewBox.
    private static let bars: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
        (11.75, 88, 15.5, 74, 14, 0.3),
        (29.25, 88, 36.75, 60, 19, 0.5),
        (49.25, 88, 61.25, 36, 19, 0.75),
        (69.25, 88, 85.75, 12, 19, 1.0)
    ]

    /// Où en est la barre `index` quand la marque entière en est à `d`.
    ///
    /// Les quatre tracés se chevauchent au lieu de se succéder : à 0,18 d'écart pour 0,46 de
    /// durée, la deuxième part quand la première est à 40 %. Bout à bout, on compterait les
    /// barres ; en se chevauchant, on lit une accélération — ce que le logo raconte déjà par ses
    /// hauteurs croissantes.
    static func progress(ofBar index: Int, at d: Double) -> Double {
        let depart = Double(index) * 0.18
        let duree = 0.46
        return min(max((d - depart) / duree, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RUColor.brandGradient)
            .frame(width: size, height: size)
            .overlay(
                ZStack {
                    ForEach(Array(Self.bars.enumerated()), id: \.offset) { index, bar in
                        let scale = glyphSize / 100
                        Path { path in
                            path.move(to: CGPoint(x: bar.0 * scale, y: bar.1 * scale))
                            path.addLine(to: CGPoint(x: bar.2 * scale, y: bar.3 * scale))
                        }
                        // La barre part du BAS (y = 88) vers le haut : couper le chemin à sa
                        // longueur la fait donc POUSSER, ce qui est exactement la lecture voulue
                        // — quatre foulées qui montent, de gauche à droite.
                        .trim(from: 0, to: Self.progress(ofBar: index, at: drawn))
                        .stroke(color.opacity(bar.5), style: StrokeStyle(lineWidth: bar.4 * scale, lineCap: .round))
                    }
                }
                .frame(width: glyphSize, height: glyphSize)
            )
    }
}

#Preview {
    AppMarkView(size: 88, radius: 26)
        .padding()
        .background(RUColor.pageBackground)
}
