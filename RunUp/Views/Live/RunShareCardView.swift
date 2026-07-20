import SwiftUI

/// The "instagrammable" share card — real route trace, real distance/pace/time, RunUp branding.
/// Rendered off-screen (via `ImageRenderer` in `RecapView`) into a `UIImage` and handed to the
/// system share sheet; never actually pushed on screen as a navigable view itself. Mirrors what
/// Strava's post-run share card does, minus any third-party SDK — a plain image into the native
/// share sheet already reaches Instagram Stories (and everything else) with zero extra
/// integration or API keys.
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

    var body: some View {
        ZStack {
            // Deliberately fixed dark, not `RUColor.bg` — this card is rendered once into a
            // shareable image (Instagram Stories etc.), independent of whatever app theme she
            // currently has selected. A share card that quietly went light/dark depending on an
            // unrelated in-app setting would be an inconsistent, unbranded artifact once posted.
            LinearGradient(colors: [Color(hex: 0x1A0B2E), Color(hex: 0x0E0E14)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [RUColor.rose.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 420)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    AppMarkView(size: 30, radius: 9)
                    Text("RUNUP").font(RUFont.bebas(20)).tracking(3).foregroundColor(.white)
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.horizontal, 28)

                Spacer(minLength: 20)

                if normalizedRoutePoints.count > 1 {
                    routeTrace
                        .frame(height: 260)
                        .padding(.horizontal, 32)
                } else {
                    // No GPS behind this run (manually logged) — no trace to fake, just more
                    // breathing room around the stats instead.
                    Spacer().frame(height: 260)
                }

                Spacer(minLength: 20)

                Text(run.title)
                    .font(RUFont.sans(15, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .padding(.bottom, 8)

                HStack(spacing: 30) {
                    shareStat(String(format: "%.2f", run.distanceKm), "KM")
                    shareStat(run.avgPace, "MIN/KM")
                    shareStat(AdaptivePlanEngine.fmt(Double(run.durationSeconds)), "TEMPS")
                }
                .padding(.bottom, 10)

                Text(Self.dateFormatter.string(from: run.date))
                    .font(RUFont.mono(11))
                    .foregroundColor(Color.white.opacity(0.32))
                    .padding(.bottom, 36)
            }
        }
        .frame(width: 360, height: 640)
    }

    private var routeTrace: some View {
        Canvas { context, size in
            let inset: CGFloat = 12
            let points = normalizedRoutePoints.map {
                CGPoint(x: inset + $0.x * (size.width - inset * 2), y: inset + $0.y * (size.height - inset * 2))
            }
            var path = Path()
            path.move(to: points[0])
            for p in points.dropFirst() { path.addLine(to: p) }
            // Same brand gradient as the app mark (rose → violet) rather than a plain white
            // trace — ties the route visually to the logo right above it.
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [RUColor.rose, RUColor.violet]),
                    startPoint: points.first ?? .zero,
                    endPoint: points.last ?? .zero
                ),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func shareStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).displayStyle(28).foregroundColor(.white)
            Text(label).font(RUFont.sans(9, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
        }
    }
}
