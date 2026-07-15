import SwiftUI

/// Single progress ring. Mirrors `Ring` in ui.jsx.
struct RingView<Content: View>: View {
    var pct: Double
    var color: Color
    var size: CGFloat = 96
    var strokeWidth: CGFloat = 6
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: max(0, min(pct, 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1), value: pct)
            content
        }
        .frame(width: size, height: size)
    }
}

/// A row of separate (not nested/concentric) progress rings, one per metric — deliberately not a
/// shared-center multi-ring control, since Apple's Human Interface Guidelines reserve that
/// specific look for the system Activity control (Move/Exercise/Stand) and app review rejects
/// lookalikes under guideline 5.2.5. Each ring here has its own center and frame.
struct RingRowView: View {
    var vals: [Double]
    var colors: [Color]
    var size: CGFloat = 72
    var strokeWidth: CGFloat = 8
    var spacing: CGFloat = 14

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(vals.indices, id: \.self) { i in
                RingView(pct: vals[i], color: colors[i % colors.count], size: size, strokeWidth: strokeWidth) {
                    Text("\(Int(max(0, min(vals[i], 100))))%")
                        .font(RUFont.mono(size * 0.15, weight: .medium))
                        .foregroundColor(colors[i % colors.count])
                }
            }
        }
    }
}
