import SwiftUI

/// A flat-sided hexagon "medal" outline — badge tiles used a plain rounded square before this,
/// same as every other card in the app. A hexagon reads as an actual achievement/medal shape,
/// distinct from the rounded rectangles used everywhere else, without introducing a new color
/// or font — just a shape swap on an existing component.
struct HexagonBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let points: [CGPoint] = [
            CGPoint(x: rect.minX + w * 0.5, y: rect.minY),
            CGPoint(x: rect.minX + w, y: rect.minY + h * 0.25),
            CGPoint(x: rect.minX + w, y: rect.minY + h * 0.75),
            CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h),
            CGPoint(x: rect.minX, y: rect.minY + h * 0.75),
            CGPoint(x: rect.minX, y: rect.minY + h * 0.25)
        ]
        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}
