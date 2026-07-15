import SwiftUI

/// The "3 daily goals" widget — reuses the app's own Stride Bars mark (3 of its 4 bars) as
/// fillable progress tracks instead of a rings pattern. The tile is solid black (not the brand
/// gradient — that's reserved for the logo itself, see `AppMarkView`); each bar's dim track is
/// always full length (the goal), and its "fill" segment is a cutout window onto the brand
/// gradient, revealed from the same start point out to `pct` of the way along the track.
/// Geometry ported 1:1 from the design handoff (`DAILY_GOALS_WIDGET.md`), which reuses
/// `AppMarkView`'s bars 2–4 (skips the shortest bar). Deliberately nothing like a ring: Apple's
/// Human Interface Guidelines reserve the concentric-ring look for the system Activity control
/// (Move/Exercise/Stand), and app review rejects lookalikes under guideline 5.2.5.
struct DailyGoalsBarsView: View {
    /// [Séance du jour, Renfo & mobilité, Pas], each 0...1.
    var progress: [Double]
    var size: CGFloat = 96
    var radius: CGFloat? = nil

    private var cornerRadius: CGFloat { radius ?? size * 0.26 }
    private var glyphSize: CGFloat { size * 0.66 }

    /// (x1, y1, x2, y2) in the design's 100×100 viewBox — bars 2–4 of `AppMarkView.bars`.
    private static let bars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (29.25, 88, 36.75, 60),
        (49.25, 88, 61.25, 36),
        (69.25, 88, 85.75, 12)
    ]

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 19 * (glyphSize / 100), lineCap: .round)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RUColor.bg)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            .frame(width: size, height: size)
            .overlay(
                ZStack {
                    // Tracks: the goal, always full length, dim.
                    ForEach(Array(Self.bars.enumerated()), id: \.offset) { _, bar in
                        barPath(bar, to: 1).stroke(Color.white.opacity(0.12), style: strokeStyle)
                    }

                    // Fill: the brand gradient (the logo's own background), revealed only through
                    // each bar's filled portion — a cutout window, not a solid color.
                    RUColor.brandGradient
                        .frame(width: glyphSize, height: glyphSize)
                        .mask(
                            ZStack {
                                ForEach(Array(Self.bars.enumerated()), id: \.offset) { i, bar in
                                    let pct = max(0, min(1, i < progress.count ? progress[i] : 0))
                                    barPath(bar, to: pct).stroke(style: strokeStyle)
                                }
                            }
                            .frame(width: glyphSize, height: glyphSize)
                        )
                        .animation(.easeOut(duration: 0.8), value: progress)
                }
                .frame(width: glyphSize, height: glyphSize)
            )
    }

    private func barPath(_ bar: (CGFloat, CGFloat, CGFloat, CGFloat), to pct: Double) -> Path {
        let scale = glyphSize / 100
        let fx = bar.0 + (bar.2 - bar.0) * pct
        let fy = bar.1 + (bar.3 - bar.1) * pct
        return Path { path in
            path.move(to: CGPoint(x: bar.0 * scale, y: bar.1 * scale))
            path.addLine(to: CGPoint(x: fx * scale, y: fy * scale))
        }
    }
}

#Preview {
    DailyGoalsBarsView(progress: [1, 0.6, 0.12], size: 180)
        .padding()
        .background(RUColor.bg)
}
