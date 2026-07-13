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

/// Three concentric activity rings (move/rose, active/lime, run/cyan). Mirrors `Rings3` in ui.jsx.
struct Rings3View<Content: View>: View {
    var vals: [Double]
    var size: CGFloat = 200
    var strokeWidth: CGFloat = 16
    var gap: CGFloat = 5
    @ViewBuilder var content: Content

    private let colors = [RUColor.rose, RUColor.lime, RUColor.cyan]

    var body: some View {
        ZStack {
            ForEach(vals.indices, id: \.self) { i in
                let inset = strokeWidth / 2 + CGFloat(i) * (strokeWidth + gap)
                let col = colors[i % colors.count]
                Circle()
                    .stroke(col.opacity(0.16), lineWidth: strokeWidth)
                    .padding(inset)
                Circle()
                    .trim(from: 0, to: max(0, min(vals[i], 100)) / 100)
                    .stroke(col, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
                    .animation(.easeOut(duration: 1.1), value: vals[i])
            }
            content
        }
        .frame(width: size, height: size)
    }
}

extension RingView where Content == EmptyView {
    init(pct: Double, color: Color, size: CGFloat = 96, strokeWidth: CGFloat = 6) {
        self.init(pct: pct, color: color, size: size, strokeWidth: strokeWidth) { EmptyView() }
    }
}
