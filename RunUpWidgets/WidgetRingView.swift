import SwiftUI

/// Static counterpart to the app's `DailyGoalsBarsView` — same single-ring, 3-gapped-segment
/// geometry and angular-gradient sweep, minus the `@State`/`animateOnAppear` machinery: a widget
/// timeline entry is one frozen render, `.animation` modifiers have nothing to animate between.
struct WidgetRingView: View {
    var progress: [Double]
    var colors: [Color]
    var size: CGFloat

    private static let canvasSize: CGFloat = 100
    private static let strokeWidth: CGFloat = 20
    private static let gapDegrees: Double = 14

    var body: some View {
        ZStack {
            ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                let start = Double(i) / 3
                let span = (120 - Self.gapDegrees) / 360
                let startDeg = Double(i) * 120
                let endDeg = startDeg + (120 - Self.gapDegrees)
                let pct = max(0, min(1, i < progress.count ? progress[i] : 0))

                Circle()
                    .trim(from: start, to: start + span)
                    .stroke(color.opacity(0.22), style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))

                Circle()
                    .trim(from: start, to: start + span * pct)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [color.darkened(0.28), color]), center: .center, startAngle: .degrees(startDeg), endAngle: .degrees(endDeg)),
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
