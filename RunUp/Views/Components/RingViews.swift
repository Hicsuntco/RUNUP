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

/// A single goal's progress as a "liquid fill" squircle — deliberately not a circular ring at
/// all, since Apple's Human Interface Guidelines reserve the concentric-ring look for the system
/// Activity control (Move/Exercise/Stand) and app review rejects lookalikes under guideline
/// 5.2.5. Fills bottom-to-top instead of tracing an arc, so it reads as a different mechanic, not
/// just a differently-colored ring.
struct GoalBadgeView<Content: View>: View {
    var pct: Double
    var color: Color
    var size: CGFloat = 72
    @ViewBuilder var content: Content

    private var corner: CGFloat { size * 0.28 }
    private var fillHeight: CGFloat { size * CGFloat(max(0, min(pct, 100)) / 100) }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(color.opacity(0.12))
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(color.gradient)
                .frame(height: fillHeight)
                .animation(.easeOut(duration: 1), value: pct)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1.5)
            content
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// A row of `GoalBadgeView`s, one per goal — see its doc comment for why squircles, not rings.
struct GoalBadgeRowView: View {
    var vals: [Double]
    var colors: [Color]
    var size: CGFloat = 72
    var spacing: CGFloat = 14

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(vals.indices, id: \.self) { i in
                GoalBadgeView(pct: vals[i], color: colors[i % colors.count], size: size) {
                    Text("\(Int(max(0, min(vals[i], 100))))%")
                        .font(RUFont.mono(size * 0.15, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2)
                }
            }
        }
    }
}
