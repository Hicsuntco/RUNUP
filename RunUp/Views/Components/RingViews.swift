import SwiftUI

/// Single progress ring. Mirrors `Ring` in ui.jsx.
struct RingView<Content: View>: View {
    var pct: Double
    var color: Color
    var size: CGFloat = 96
    var strokeWidth: CGFloat = 6
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(RUColor.line, lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: max(0, min(pct, 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Used everywhere a ring fills (Home's readiness ring, the rings card, Readiness,
                // Rings, the onboarding building screen) — respects Reduce Motion instead of
                // sweeping the fill unconditionally every time one of those screens opens.
                .animation(reduceMotion ? nil : .easeOut(duration: 1), value: pct)
            content
        }
        .frame(width: size, height: size)
    }
}

