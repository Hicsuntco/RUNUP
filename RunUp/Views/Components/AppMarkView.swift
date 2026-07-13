import SwiftUI

/// The app's logo mark — a rounded-square tile filled with the brand gradient, containing a
/// circular progress-ring arc (270° sweep) with a small dot at its leading edge. Echoes the
/// Rings feature rather than a generic running icon. See README § Assets.
struct AppMarkView: View {
    var size: CGFloat = 24
    var radius: CGFloat? = nil
    var color: Color = .white

    private var cornerRadius: CGFloat { radius ?? size * 0.3 }
    private var glyphSize: CGFloat { size * 0.56 }
    private var strokeWidth: CGFloat { glyphSize * 0.125 }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RUColor.brandGradient)
            .frame(width: size, height: size)
            .overlay(
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(color)
                        .frame(width: strokeWidth * 1.4, height: strokeWidth * 1.4)
                        .offset(y: -glyphSize / 2)
                }
                .frame(width: glyphSize, height: glyphSize)
            )
    }
}

#Preview {
    AppMarkView(size: 88, radius: 26)
        .padding()
        .background(RUColor.bg)
}
