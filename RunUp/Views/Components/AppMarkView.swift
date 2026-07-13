import SwiftUI

/// The app's logo mark — "Stride Bars": 4 rounded-cap strokes of increasing height (stride/
/// cadence, reading left→right as acceleration) on a rounded-square tile filled with the brand
/// gradient. Geometry ported 1:1 from the design handoff's 100×100 SVG viewBox (see LOGO.md) —
/// deliberately not a progress-ring glyph or parallel bars, both dropped in the handoff for
/// reading too close to existing marks (Apple Fitness rings / adidas stripes).
struct AppMarkView: View {
    var size: CGFloat = 24
    var radius: CGFloat? = nil
    var color: Color = .white

    private var cornerRadius: CGFloat { radius ?? size * 0.26 }
    private var glyphSize: CGFloat { size * 0.62 }

    /// (x1, y1, x2, y2, lineWidth, opacity) in the design's 100×100 viewBox.
    private static let bars: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
        (11.75, 88, 15.5, 74, 14, 0.3),
        (29.25, 88, 36.75, 60, 19, 0.5),
        (49.25, 88, 61.25, 36, 19, 0.75),
        (69.25, 88, 85.75, 12, 19, 1.0)
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RUColor.brandGradient)
            .frame(width: size, height: size)
            .overlay(
                ZStack {
                    ForEach(Array(Self.bars.enumerated()), id: \.offset) { _, bar in
                        let scale = glyphSize / 100
                        Path { path in
                            path.move(to: CGPoint(x: bar.0 * scale, y: bar.1 * scale))
                            path.addLine(to: CGPoint(x: bar.2 * scale, y: bar.3 * scale))
                        }
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
        .background(RUColor.bg)
}
