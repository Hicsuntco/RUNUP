import SwiftUI

/// A real elevation profile from a run's own GPS altitude readings — a plain hand-rolled Canvas
/// area chart, same approach `WeeklyRecapView`'s volume chart already uses rather than pulling in
/// Charts for one view. Always check `hasData` before showing this: a route with no trustworthy
/// vertical-accuracy readings at all has nothing real to draw.
struct ElevationProfileView: View {
    var route: [RunRecord.RoutePoint]
    var lineColor: Color = RUColor.lime

    static func hasData(_ route: [RunRecord.RoutePoint]) -> Bool {
        route.compactMap(\.altitude).count >= 2
    }

    /// Carries the last known real altitude forward across a gap (a fix with untrustworthy
    /// vertical accuracy) instead of dropping the point — dropping would compress the x-axis and
    /// misplace WHERE along the route a climb actually happened.
    private var altitudes: [Double] {
        var last: Double?
        return route.map { point in
            if let a = point.altitude { last = a }
            return last ?? 0
        }
    }

    var body: some View {
        let values = altitudes
        let minAlt = values.min() ?? 0
        let maxAlt = values.max() ?? 0
        let range = max(maxAlt - minAlt, 1)

        Canvas { context, size in
            guard values.count > 1 else { return }
            let stepX = size.width / CGFloat(values.count - 1)
            let points = values.enumerated().map { i, v -> CGPoint in
                CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat((v - minAlt) / range) * size.height)
            }
            guard let first = points.first, let last = points.last else { return }

            var line = Path()
            line.move(to: first)
            for p in points.dropFirst() { line.addLine(to: p) }

            var fill = line
            fill.addLine(to: CGPoint(x: last.x, y: size.height))
            fill.addLine(to: CGPoint(x: first.x, y: size.height))
            fill.closeSubpath()

            context.fill(fill, with: .linearGradient(
                Gradient(colors: [lineColor.opacity(0.28), .clear]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)
            ))
            context.stroke(line, with: .color(lineColor), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
