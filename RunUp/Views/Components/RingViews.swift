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

/// A single goal's progress drawn as a running track — an oval "capsule" a runner traces a lap
/// around, filling from the start line. Deliberately nothing like a circle: Apple's Human
/// Interface Guidelines reserve the concentric-ring look for the system Activity control
/// (Move/Exercise/Stand), and app review rejects lookalikes under guideline 5.2.5. This leans
/// into the running theme instead of reaching for another generic progress shape.
struct TrackProgressView<Content: View>: View {
    var pct: Double
    var color: Color
    var width: CGFloat = 120
    var height: CGFloat = 40
    var strokeWidth: CGFloat = 10
    @ViewBuilder var content: Content

    private var fraction: CGFloat { CGFloat(max(0, min(pct, 100))) / 100 }

    var body: some View {
        ZStack {
            Capsule()
                .stroke(Color.white.opacity(0.09), lineWidth: strokeWidth)
            Capsule()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .animation(.easeOut(duration: 1), value: pct)
            HStack {
                Text("🏃").font(.system(size: strokeWidth * 1.5))
                Spacer(minLength: 4)
                content
            }
            .padding(.horizontal, strokeWidth * 1.1)
        }
        .frame(width: width, height: height)
    }
}

/// A stack of `TrackProgressView`s, one per goal — see its doc comment for why tracks, not rings.
struct TrackProgressStackView: View {
    var vals: [Double]
    var colors: [Color]
    var width: CGFloat = 130
    var height: CGFloat = 26
    var spacing: CGFloat = 8

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(vals.indices, id: \.self) { i in
                TrackProgressView(pct: vals[i], color: colors[i % colors.count], width: width, height: height, strokeWidth: height * 0.32) {
                    Text("\(Int(max(0, min(vals[i], 100))))%")
                        .font(RUFont.mono(height * 0.34, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}
