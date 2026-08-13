import SwiftUI

/// The "3 daily goals" widget — one ring, split into 3 colored arc segments, instead of 3
/// separate bars. Takes a little of its polish from Apple's Fitness/Activity rings (a glossy
/// per-ring gradient sweep, a color-tinted track instead of flat gray) without
/// copying the actual design: Apple's is 3 CONCENTRIC full rings in fixed Move/Exercise/Stand
/// colors, this is a SINGLE ring split into 3 gapped arc segments in the app's own brand colors —
/// a different principle, not just a different palette. The concentric-ring look itself is also
/// reserved for the system Activity control by Apple's Human Interface Guidelines, and app review
/// rejects lookalikes under guideline 5.2.5, so staying single-ring isn't just aesthetic. Each
/// goal gets 120° of the circle minus a small gap on either side, so the 3 goals stay clearly
/// distinct even though they now share one ring. Colors are the app's 3 core accent tones
/// (`RUColor.rose2` → `.rose` → `.violet`, theme-aware) — the same logo gradient stops as before.
/// Every legend dot (`RingsView`, `HomeView`) reads `fillColors` below, so they can never drift
/// out of sync with what's actually drawn here. Drawn in a fixed 100×100 space then
/// `scaleEffect`-ed to `size`, so stroke width, gaps, and shadow all stay in the same proportion
/// to the ring at every size this is used at.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    /// Same 12%-of-diameter stroke as `WidgetRingView` — the app used to draw a chunkier 20 with
    /// a heavy lift shadow, and next to the widget the thick version read muddy (owner compared
    /// them side by side and preferred the widget's ring); both surfaces now render identically.
    private static let strokeWidth: CGFloat = 12
    /// La piste doit dire « objectif pas encore atteint », donc rester nettement en dessous du
    /// remplissage. Elle était à 0,36 en clair, calibrée quand l'anneau faisait 72 pt : à 96 pt,
    /// une journée à 0/3 dessinait un anneau rose et lavande PLEIN, qui contredisait sa propre
    /// légende « 0/2 bouclés ». Un anneau vide doit se lire vide — c'est la seule chose que cet
    /// écran a à dire quand rien n'est fait.
    ///
    /// Le clair reste un peu au-dessus du sombre : une couleur saturée à faible opacité se dilue
    /// davantage sur du blanc que sur du noir.
    private static let lightTrackOpacity = 0.15
    private static let darkTrackOpacity = 0.20

    var body: some View {
        ZStack {
            ForEach(Array(Self.fillColors.enumerated()), id: \.offset) { i, color in
                let seg = RingSegmentGeometry.segment(at: i)
                let pct = max(0, min(1, i < displayedProgress.count ? displayedProgress[i] : 0))
                let fillEnd = seg.trimStart + (seg.trimEnd - seg.trimStart) * pct

                // Track: the goal, always the full segment length — a dim tint of this segment's
                // own color (like Apple's rings), not a neutral gray, so even the empty part hints
                // at which goal it belongs to.
                Circle()
                    .trim(from: seg.trimStart, to: seg.trimEnd)
                    .stroke(color.opacity(RUColor.isLight ? Self.lightTrackOpacity : Self.darkTrackOpacity), style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))

                // Fill: from the same start point, out to `pct` of the way along the segment. The
                // gradient sweep spans the segment's full angular range (not just the filled
                // part), so the trim below reveals progressively more of the same fixed sweep —
                // early progress reads a touch muted, filling all the way to the goal reaches the
                // fully saturated color, the same "brightens as it completes" read Apple's rings
                // have, without animating the gradient itself (only `trim` — a `Shape`'s own
                // `animatableData` — needs to interpolate for this to animate smoothly).
                Circle()
                    .trim(from: seg.trimStart, to: fillEnd)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [color.darkened(0.28), color]), center: .center, startAngle: .degrees(seg.gradientStartDegrees), endAngle: .degrees(seg.gradientEndDegrees)),
                        style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round)
                    )
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.9), value: pct)
            }
        }
        // A circle's own trim starts at 3 o'clock; rotate so segment 0 starts at 12, going clockwise.
        // No lift shadow — the widget's ring doesn't have one, and at hero size the shadow was a
        // big part of the smeared "ghost ring" look in the screenshot that prompted this change.
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
