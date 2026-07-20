import SwiftUI

/// The "3 daily goals" widget — one ring, split into 3 colored arc segments, instead of 3
/// separate bars. Deliberately one ring with segments, not 3 concentric rings: Apple's Human
/// Interface Guidelines reserve the concentric-ring look for the system Activity control
/// (Move/Exercise/Stand), and app review rejects lookalikes under guideline 5.2.5. Each goal gets
/// 120° of the circle minus a small gap on either side, so the 3 goals stay clearly distinct even
/// though they now share one ring. Colors are the app's 3 core accent tones (`RUColor.rose2` →
/// `.rose` → `.violet`, theme-aware) — the same logo gradient stops as before, drawn as flat
/// per-segment colors rather than a continuous gradient so each segment reads as one unambiguous
/// color instead of shifting hue as it fills. Every legend dot (`RingsView`, `HomeView`) reads
/// `fillColors` below, so they can never drift out of sync with what's actually drawn here.
/// Drawn in a fixed 100×100 space then `scaleEffect`-ed to `size`, so stroke width and gaps stay
/// in the same proportion to the ring at every size this is used at.
struct DailyGoalsBarsView: View {
    /// [Séance du jour, Calories actives, Pas], each 0...1.
    var progress: [Double]
    var size: CGFloat = 96
    /// When true, the ring fills up from empty the first time this view appears instead of
    /// snapping straight to `progress` — used on `RingsView`'s hero widget so opening "Ta journée"
    /// reads as the ring filling in front of you, not a static picture.
    var animateOnAppear: Bool = false

    /// What's actually drawn — starts at 0 when `animateOnAppear` is set, then springs to
    /// `progress` in `onAppear`. `.trim`'s `from`/`to` are themselves animatable, so
    /// `.animation(value:)` on the trimmed shape interpolates smoothly with no custom `Shape`
    /// needed (unlike the old bar geometry, which did need one).
    @State private var displayedProgress: [Double]

    init(progress: [Double], size: CGFloat = 96, animateOnAppear: Bool = false) {
        self.progress = progress
        self.size = size
        self.animateOnAppear = animateOnAppear
        _displayedProgress = State(initialValue: animateOnAppear ? progress.map { _ in 0 } : progress)
    }

    /// Each segment's fill color, in goal order — exposed so other views showing the same 3 goals
    /// (the legend dots in `RingsView`, the stat labels in `HomeView`) draw from this instead of
    /// keeping a second, driftable copy of the palette.
    static var fillColors: [Color] { [RUColor.rose2, RUColor.rose, RUColor.violet] }

    private static let canvasSize: CGFloat = 100
    private static let strokeWidth: CGFloat = 20
    /// Degrees of empty space between adjacent segments. Round line caps eat into this visually,
    /// so the actual gap reads narrower than this number.
    private static let gapDegrees: Double = 14

    var body: some View {
        ZStack {
            ForEach(Array(Self.fillColors.enumerated()), id: \.offset) { i, color in
                let start = Double(i) / 3
                let span = (120 - Self.gapDegrees) / 360
                let pct = max(0, min(1, i < displayedProgress.count ? displayedProgress[i] : 0))

                // Track: the goal, always the full segment length, dim.
                Circle()
                    .trim(from: start, to: start + span)
                    .stroke(RUColor.line, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))

                // Fill: from the same start point, out to `pct` of the way along the segment, in
                // this goal's own flat color.
                Circle()
                    .trim(from: start, to: start + span * pct)
                    .stroke(color, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
                    .animation(.easeOut(duration: 0.9), value: pct)
            }
        }
        // A circle's own trim starts at 3 o'clock; rotate so segment 0 starts at 12, going clockwise.
        .rotationEffect(.degrees(-90))
        .frame(width: Self.canvasSize, height: Self.canvasSize)
        .scaleEffect(size / Self.canvasSize)
        .frame(width: size, height: size)
        .onAppear {
            if animateOnAppear { displayedProgress = progress }
        }
        .onChange(of: progress) { _, newValue in
            displayedProgress = newValue
        }
    }
}

#Preview {
    DailyGoalsBarsView(progress: [1, 0.6, 0.12], size: 180)
        .padding()
        .background(RUColor.bg)
}
