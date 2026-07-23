import SwiftUI

/// The share card — Strava-style stacked stats (label over big value, centered) floating on a
/// fully transparent background, with the real route trace as a glowing neon signature above and
/// RunUp branding below. Rendered off-screen (via `ImageRenderer` in `RecapView`) into a `UIImage`
/// with alpha preserved, so the exported PNG layers cleanly over any photo (Instagram Stories,
/// Snapchat, any editor). There used to be two variants (an opaque dark card + this transparent
/// one, two separate share buttons) — one transparent card covers both uses: it reads fine shared
/// as-is on a dark story background, and it's the only version that works over a photo. Every
/// element carries a strong drop shadow so legibility doesn't depend on what ends up underneath.
struct RunShareCardView: View {
    var run: RunRecord

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    /// Route points normalized into a 0...1 square, preserving aspect ratio (a route that's
    /// mostly north-south — or east-west — keeps its real shape instead of being stretched to
    /// fill a square canvas). Longitude isn't corrected for latitude compression: this is a
    /// stylized trace for a share card, not a scaled map, same spirit as Strava's own.
    private var normalizedRoutePoints: [CGPoint] {
        guard run.route.count > 1 else { return [] }
        let lats = run.route.map(\.lat)
        let lngs = run.route.map(\.lng)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max()
        else { return [] }
        let latRange = maxLat - minLat
        let lngRange = maxLng - minLng
        let range = max(latRange, lngRange, 0.00001)
        return run.route.map { point in
            let x = (point.lng - minLng - (range - lngRange) / 2) / range
            // Latitude increases northward; y increases downward on screen — flip it.
            let y = 1 - (point.lat - minLat - (range - latRange) / 2) / range
            return CGPoint(x: x, y: y)
        }
    }

    private var textShadow: Color { .black.opacity(0.65) }

    var body: some View {
        VStack(spacing: 0) {
            if normalizedRoutePoints.count > 1 {
                neonRouteTrace
                    .frame(height: 230)
                    .padding(.top, 26)
            } else {
                // No GPS behind this run (manually logged) — no trace to fake; the stats just
                // breathe in the extra space.
                Spacer().frame(height: 90)
            }

            Spacer(minLength: 12)

            VStack(spacing: 22) {
                statBlock("DISTANCE", String(format: "%.2f km", run.distanceKm), valueSize: 66)
                statBlock("ALLURE", "\(run.avgPace) /km", valueSize: 46)
                statBlock("TEMPS", PaceModel.formatDuration(Double(run.durationSeconds)), valueSize: 46)
            }

            Spacer(minLength: 12)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    AppMarkView(size: 26, radius: 7)
                    Text("RUNUP").font(RUFont.bebas(17)).tracking(4).foregroundColor(.white)
                }
                Text(Self.dateFormatter.string(from: run.date))
                    .font(RUFont.mono(10))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.55))
            }
            .shadow(color: textShadow, radius: 6)
            .padding(.bottom, 34)
        }
        .frame(width: 360, height: 640)
    }

    /// One Strava-style stacked stat — small tracked label over a big Bebas value, centered.
    private func statBlock(_ label: String, _ value: String, valueSize: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(RUFont.sans(11, weight: .bold))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.65))
                .shadow(color: textShadow, radius: 5)
            Text(value)
                .font(RUFont.bebas(valueSize))
                .foregroundColor(.white)
                .shadow(color: textShadow, radius: 8)
                .shadow(color: Color(hex: 0xFF0F5B).opacity(0.3), radius: 24)
        }
        .frame(maxWidth: .infinity)
    }

    /// A wide, blurred pass underneath a crisp pass — the same brand gradient (rose → violet) as
    /// the app mark, drawn thick enough to read as the card's real hero visual, not a thin line
    /// tucked in a box. `drawLayer` isolates the blur filter to just that pass, so it doesn't also
    /// smear the crisp stroke drawn after it.
    private var neonRouteTrace: some View {
        Canvas { context, size in
            let inset: CGFloat = 20
            let points = normalizedRoutePoints.map {
                CGPoint(x: inset + $0.x * (size.width - inset * 2), y: inset + $0.y * (size.height - inset * 2))
            }
            guard let first = points.first, let last = points.last else { return }
            var path = Path()
            path.move(to: first)
            for p in points.dropFirst() { path.addLine(to: p) }

            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color(hex: 0xFF3D7F), Color(hex: 0x8A5CFF)]),
                startPoint: first,
                endPoint: last
            )
            let style = StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 14))
                glow.opacity = 0.65
                glow.stroke(path, with: gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            }
            context.stroke(path, with: gradient, style: style)

            context.fill(Path(ellipseIn: CGRect(x: first.x - 4, y: first.y - 4, width: 8, height: 8)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: last.x - 5, y: last.y - 5, width: 10, height: 10)), with: .color(.white))
        }
    }
}
