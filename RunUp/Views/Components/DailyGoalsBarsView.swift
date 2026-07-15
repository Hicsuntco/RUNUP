import SwiftUI

/// The "3 daily goals" widget — reuses the app's own Stride Bars mark (3 of its 4 bars) as
/// fillable progress tracks instead of a rings pattern. Each bar's dim "track" is always full
/// length (the goal); its bright "fill" segment is drawn from the same start point out to
/// `pct` of the way along the track — geometry ported 1:1 from the design handoff
/// (`DAILY_GOALS_WIDGET.md`), which reuses `AppMarkView`'s bars 2–4 (skips the shortest bar).
/// Deliberately nothing like a ring: Apple's Human Interface Guidelines reserve the
/// concentric-ring look for the system Activity control (Move/Exercise/Stand), and app review
/// rejects lookalikes under guideline 5.2.5.
struct DailyGoalsBarsView: View {
    /// [Séance du jour, Renfo & mobilité, Pas], each 0...1.
    var progress: [Double]
    var size: CGFloat = 96
    var radius: CGFloat? = nil

    private var cornerRadius: CGFloat { radius ?? size * 0.26 }
    private var glyphSize: CGFloat { size * 0.66 }

    /// (x1, y1, x2, y2, fillColor, fillOpacity) in the design's 100×100 viewBox — bars 2–4 of
    /// `AppMarkView.bars`.
    private static let bars: [(CGFloat, CGFloat, CGFloat, CGFloat, Color, Double)] = [
        (29.25, 88, 36.75, 60, Color(hex: 0xFFE1E9), 0.85),
        (49.25, 88, 61.25, 36, Color(hex: 0xFFB4C9), 0.9),
        (69.25, 88, 85.75, 12, .white, 1.0)
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RUColor.brandGradient)
            .frame(width: size, height: size)
            .overlay(
                ZStack {
                    ForEach(Array(Self.bars.enumerated()), id: \.offset) { i, bar in
                        let scale = glyphSize / 100
                        let lineWidth = 19 * scale
                        // Track: the goal, always full length, dim.
                        Path { path in
                            path.move(to: CGPoint(x: bar.0 * scale, y: bar.1 * scale))
                            path.addLine(to: CGPoint(x: bar.2 * scale, y: bar.3 * scale))
                        }
                        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                        // Fill: from the same start point, out to `pct` of the way along the track.
                        let pct = max(0, min(1, i < progress.count ? progress[i] : 0))
                        let fx = bar.0 + (bar.2 - bar.0) * pct
                        let fy = bar.1 + (bar.3 - bar.1) * pct
                        Path { path in
                            path.move(to: CGPoint(x: bar.0 * scale, y: bar.1 * scale))
                            path.addLine(to: CGPoint(x: fx * scale, y: fy * scale))
                        }
                        .stroke(bar.4.opacity(bar.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .animation(.easeOut(duration: 0.8), value: pct)
                    }
                }
                .frame(width: glyphSize, height: glyphSize)
            )
    }
}

#Preview {
    DailyGoalsBarsView(progress: [1, 0.6, 0.12], size: 180)
        .padding()
        .background(RUColor.bg)
}
