import SwiftUI

/// Static counterpart to the app's `DailyGoalsBarsView` — same single-ring, 3-gapped-segment
/// geometry and angular-gradient sweep, minus the `@State`/`animateOnAppear` machinery: a widget
/// timeline entry is one frozen render, `.animation` modifiers have nothing to animate between.
struct WidgetRingView: View {
    var progress: [Double]
    var colors: [Color]
    var size: CGFloat
    /// Same reasoning as `DailyGoalsBarsView.lightTrackOpacity` — a saturated color at low opacity
    /// washes out more over a near-white background than over near-black, so light mode needs a
    /// touch more opacity to read as a clear track instead of barely-there.
    var isLight: Bool

    private static let canvasSize: CGFloat = 100
    /// Thinner than `DailyGoalsBarsView`'s 20 — the widget mockup's ring is a 10%-of-diameter
    /// stroke, more elegant at glance size than the app's chunky hero ring; this view is
    /// widget-only, so the app's ring keeps its own weight.
    private static let strokeWidth: CGFloat = 12
    private static let lightTrackOpacity = 0.36
    private static let darkTrackOpacity = 0.20

    var body: some View {
        ZStack {
            ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                let seg = RingSegmentGeometry.segment(at: i)
                let pct = max(0, min(1, i < progress.count ? progress[i] : 0))
                let fillEnd = seg.trimStart + (seg.trimEnd - seg.trimStart) * pct

                Circle()
                    .trim(from: seg.trimStart, to: seg.trimEnd)
                    .stroke(color.opacity(isLight ? Self.lightTrackOpacity : Self.darkTrackOpacity), style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))

                Circle()
                    .trim(from: seg.trimStart, to: fillEnd)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [color.darkened(0.28), color]), center: .center, startAngle: .degrees(seg.gradientStartDegrees), endAngle: .degrees(seg.gradientEndDegrees)),
                        style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round)
                    )
            }
        }
        .rotationEffect(.degrees(-90))
        .frame(width: Self.canvasSize, height: Self.canvasSize)
        .scaleEffect(size / Self.canvasSize)
        .frame(width: size, height: size)
    }
}
