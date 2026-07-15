import SwiftUI

/// The "3 daily goals" widget — reuses the app's own Stride Bars mark (3 of its 4 bars) as
/// fillable progress tracks instead of a rings pattern. The tile is solid black (not the brand
/// gradient — that's reserved for the logo itself, see `AppMarkView`); each bar's dim track is
/// always full length (the goal), and its fill is drawn from the same start point out to `pct`
/// of the way along the track in one flat color per bar — deliberately NOT a per-bar gradient:
/// with a gradient, the color actually on screen depends on how much of the bar is filled (near
/// zero progress only shows the gradient's start color), so no single "legend" swatch can ever
/// match it at every progress value. A flat color sidesteps that entirely — `fillColors` below
/// and every legend dot (`RingsView`, `HomeView`) read the exact same 3 colors that are drawn
/// here, so they can never drift out of sync again. Colors are the app's 3 core accent tones
/// (`RUColor.rose2` → `.rose` → `.violet`, theme-aware), so the mark re-themes live with the
/// accent picker in Profil → Apparence. Geometry ported 1:1 from the design handoff
/// (`DAILY_GOALS_WIDGET.md`), which reuses `AppMarkView`'s bars 2–4 (skips the shortest bar) —
/// same stroke-width-to-glyph ratio as the logo (19/100), just drawn at a larger glyph fraction
/// of the tile so it reads clearly. Nothing like a ring: Apple's Human Interface Guidelines
/// reserve the concentric-ring look for the system Activity control (Move/Exercise/Stand), and
/// app review rejects lookalikes under guideline 5.2.5.
struct DailyGoalsBarsView: View {
    /// [Séance du jour, Renfo & mobilité, Pas], each 0...1.
    var progress: [Double]
    var size: CGFloat = 96
    var radius: CGFloat? = nil
    /// When true, bars fill up from empty the first time this view appears instead of snapping
    /// straight to `progress` — used on `RingsView`'s hero widget so opening "Ta journée" reads
    /// as the bars filling in front of you, not a static picture.
    var animateOnAppear: Bool = false

    /// What's actually drawn — starts at 0 when `animateOnAppear` is set, then springs to
    /// `progress` in `onAppear`, so the existing per-bar `.animation(value:)` has something to
    /// animate between on first appearance (it only fires on a *change*, not an initial value).
    @State private var displayedProgress: [Double]

    init(progress: [Double], size: CGFloat = 96, radius: CGFloat? = nil, animateOnAppear: Bool = false) {
        self.progress = progress
        self.size = size
        self.radius = radius
        self.animateOnAppear = animateOnAppear
        _displayedProgress = State(initialValue: animateOnAppear ? progress.map { _ in 0 } : progress)
    }

    private var cornerRadius: CGFloat { radius ?? size * 0.26 }
    private var glyphSize: CGFloat { size * 0.93 }

    /// (x1, y1, x2, y2, fillColor) in the design's 100×100 viewBox — bars 2–4 of
    /// `AppMarkView.bars`. Computed, not a `static let`: `RUColor.rose`/`.rose2`/`.violet` are
    /// theme-aware, and a `let` would freeze their value at first access instead of re-reading it
    /// (and re-registering the Observation dependency) every time `body` runs.
    private static var bars: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] {
        [
            (29.25, 88, 36.75, 60, RUColor.rose2),
            (49.25, 88, 61.25, 36, RUColor.rose),
            (69.25, 88, 85.75, 12, RUColor.violet)
        ]
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 19 * (glyphSize / 100), lineCap: .round)
    }

    /// Each bar's fill color, in order — exposed so other views showing the same 3 goals (the
    /// legend dots in `RingsView`, the stat labels in `HomeView`) draw from this instead of
    /// keeping a second, driftable copy of the palette.
    static var fillColors: [Color] {
        bars.map { $0.4 }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RUColor.bg)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            .frame(width: size, height: size)
            .overlay(
                ZStack {
                    ForEach(Array(Self.bars.enumerated()), id: \.offset) { i, bar in
                        // Track: the goal, always full length, dim.
                        barPath(bar, to: 1).stroke(Color.white.opacity(0.12), style: strokeStyle)

                        // Fill: from the same start point, out to `pct` of the way along the
                        // track, in this bar's flat color.
                        let pct = max(0, min(1, i < displayedProgress.count ? displayedProgress[i] : 0))
                        barPath(bar, to: pct)
                            .stroke(bar.4, style: strokeStyle)
                            .animation(.easeOut(duration: 0.8), value: pct)
                    }
                }
                .frame(width: glyphSize, height: glyphSize)
            )
            .onAppear {
                if animateOnAppear { displayedProgress = progress }
            }
            .onChange(of: progress) { _, newValue in
                displayedProgress = newValue
            }
    }

    private func barPath(_ bar: (CGFloat, CGFloat, CGFloat, CGFloat, Color), to pct: Double) -> Path {
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
