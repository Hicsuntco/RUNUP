import SwiftUI

/// RunUp's signature graphic motif — a row of bars pulsing rhythmically, standing in for the
/// generic progress-ring language most fitness apps already use. Deliberately ambient/decorative
/// (a rhythm, not a number) — it never claims to represent a specific live metric like cadence
/// unless a real per-run sensor value backs it, which the app doesn't track yet. Used as: the
/// coach's "typing" indicator, and a divider/accent behind hero numbers.
struct TempoBarsView: View {
    var barCount: Int = 40
    var color: Color = RUColor.rose
    var amplitude: CGFloat = 0.85
    var thin: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fixed per-launch, not re-rolled every render — each bar keeps its own offset so the row
    // pulses like a rhythm section instead of every bar moving in lockstep.
    private static let seeds: [Double] = (0..<64).map { _ in Double.random(in: 0...1) }

    var body: some View {
        TimelineView(reduceMotion ? .animation(minimumInterval: 100, paused: true) : .animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                guard barCount > 0, size.width > 0, size.height > 0 else { return }
                let gap = size.width / CGFloat(barCount)
                let barWidth = gap * (thin ? 0.28 : 0.42)
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                for i in 0..<barCount {
                    let seed = Self.seeds[i % Self.seeds.count]
                    let phase = t * 1.8 + Double(i) * 0.4
                    let base = 0.35 + 0.65 * abs(sin(phase + seed * 2))
                    let barHeight = size.height * CGFloat(base) * amplitude
                    let x = CGFloat(i) * gap + (gap - barWidth) / 2
                    let y = (size.height - barHeight) / 2
                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = RoundedRectangle(cornerRadius: barWidth / 2).path(in: rect)
                    ctx.opacity = 0.35 + 0.65 * base
                    ctx.fill(path, with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
