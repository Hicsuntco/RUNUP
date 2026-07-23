import SwiftUI

/// Thin segmented progress bar at the top of onboarding (3px tall segments).
struct OnboardingProgressBar: View {
    var step: Int
    var total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? RUColor.rose : RUColor.line)
                    .frame(height: 3)
                    .animation(.easeOut(duration: 0.3), value: step)
            }
        }
    }
}

/// A single thin rounded fill bar — class `.bar`/`i`.
struct LinearBar: View {
    var fraction: Double
    var color: Color
    var background: Color = RUColor.line
    var height: CGFloat = 5
    var gradient: LinearGradient? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(background)
                Group {
                    if let gradient {
                        Capsule().fill(gradient)
                    } else {
                        Capsule().fill(color)
                    }
                }
                .frame(width: geo.size.width * max(0, min(fraction, 1)))
                // `RingView` (the circular counterpart used for the same kind of goal/XP progress)
                // animates its fill; this had none at all, so every screen using `LinearBar`
                // instead — Club's XP bar, challenge progress, RingsView's goal rows, weekly stat
                // tiles — snapped straight to the new value instead of filling in front of you.
                .animation(.easeOut(duration: 0.8), value: fraction)
            }
        }
        .frame(height: height)
    }
}

/// One phase segment: label, done/total sessions, proportional width, own fill color.
struct PhaseSegment: Identifiable {
    let id = UUID()
    var name: String
    var done: Int
    var total: Int
    var color: Color
}

/// The 3-segment Base/Spécifique/Affûtage phase bar, segment widths proportional to `total`
/// (mirrors CSS `flex: t` in the prototype).
struct PhaseProgressBar: View {
    var phases: [PhaseSegment]
    var showLabels: Bool = true

    private var weightSum: Double { max(1, phases.reduce(0) { $0 + $1.total }.doubleValue) }
    private let gap: CGFloat = 4

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let available = geo.size.width - gap * CGFloat(max(0, phases.count - 1))
                HStack(spacing: gap) {
                    ForEach(phases) { phase in
                        LinearBar(fraction: phase.total == 0 ? 0 : Double(phase.done) / Double(phase.total), color: phase.color)
                            .frame(width: available * (phase.total.doubleValue / weightSum))
                    }
                }
            }
            .frame(height: 5)
            if showLabels {
                HStack(spacing: gap) {
                    ForEach(phases) { phase in
                        Text(phase.name)
                            .font(RUFont.sans(8, weight: .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundColor(RUColor.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private extension Int {
    var doubleValue: Double { Double(self) }
}
