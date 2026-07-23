import SwiftUI

/// The "instagrammable" share card — real route trace as a glowing neon line, a huge hero
/// distance number, real pace/time/elevation, RunUp branding. Rendered off-screen (via
/// `ImageRenderer` in `RecapView`) into a `UIImage` and handed to the system share sheet; never
/// actually pushed on screen as a navigable view itself.
struct RunShareCardView: View {
    var run: RunRecord
    /// When true, skips the card's own background entirely — `ImageRenderer` preserves alpha for
    /// anything left unpainted, so the exported PNG has a transparent background with just the
    /// glowing route trace + stats floating over it. Meant to be layered on top of her own photo
    /// (Instagram Stories' own sticker/layer tools, or any photo editor) rather than shared as a
    /// self-contained card. Text/trace keep their glow and gain a drop shadow either way, so
    /// legibility doesn't depend on what photo ends up underneath.
    var transparentBackground: Bool = false

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

    private var textShadow: Color { .black.opacity(transparentBackground ? 0.65 : 0.4) }

    var body: some View {
        ZStack {
            if !transparentBackground {
                // Deliberately fixed dark, not `RUColor.bg` — this card is rendered once into a
                // shareable image (Instagram Stories etc.), independent of whatever app theme she
                // currently has selected. A share card that quietly went light/dark depending on
                // an unrelated in-app setting would be an inconsistent, unbranded artifact once
                // posted.
                LinearGradient(
                    colors: [Color(hex: 0x2A0E36), Color(hex: 0x0D0B14), Color(hex: 0x08070C)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(colors: [Color(hex: 0xFF0F5B).opacity(0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 460)
            }

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    AppMarkView(size: 22, radius: 6)
                    Text("RUNUP").font(RUFont.bebas(13)).tracking(3).foregroundColor(.white)
                    Spacer()
                }
                .shadow(color: textShadow, radius: 6)
                .padding(.top, 30)
                .padding(.horizontal, 26)

                if normalizedRoutePoints.count > 1 {
                    neonRouteTrace
                        .frame(height: 300)
                        .padding(.top, 6)
                } else {
                    // No GPS behind this run (manually logged) — no trace to fake, just more
                    // breathing room around the hero stat instead.
                    Spacer().frame(height: 300)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f", run.distanceKm))
                        .font(RUFont.bebas(88))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: 0xFF0F5B).opacity(transparentBackground ? 0.35 : 0.55), radius: 30)
                    Text("KILOMÈTRES")
                        .font(RUFont.mono(12))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.55))
                        .shadow(color: textShadow, radius: 6)
                    Text(run.title)
                        .font(RUFont.sans(13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(color: textShadow, radius: 6)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 20)

                VStack(spacing: 14) {
                    Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1)
                    HStack {
                        shareStat(run.avgPace, "ALLURE MOY")
                        Spacer()
                        shareStat(PaceModel.formatDuration(Double(run.durationSeconds)), "TEMPS")
                        Spacer()
                        shareStat("+\(run.elevationGainM) M", "D+")
                    }
                }
                .padding(.horizontal, 26)
                .shadow(color: textShadow, radius: 6)

                Text(Self.dateFormatter.string(from: run.date))
                    .font(RUFont.mono(10))
                    .foregroundColor(.white.opacity(0.4))
                    .shadow(color: textShadow, radius: 6)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
            }
        }
        .frame(width: 360, height: 640)
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

    private func shareStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(RUFont.bebas(20)).foregroundColor(.white)
            Text(label).font(RUFont.sans(8.5, weight: .bold)).tracking(1.2).foregroundColor(.white.opacity(0.45))
        }
    }
}
