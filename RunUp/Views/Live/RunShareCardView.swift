import SwiftUI

/// Text-color styles for the share card, picked on the recap screen before sharing — the photo
/// underneath decides which one works (white over a dark evening run, black over snow/sky, the
/// brand gradient when she wants the RunUp identity front and center).
enum ShareCardTextColor: String, CaseIterable, Identifiable {
    case blanc, noir, runup
    var id: String { rawValue }
    var label: String {
        switch self {
        case .blanc: return "Blanc"
        case .noir: return "Noir"
        case .runup: return "RunUp"
        }
    }
}

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
    var textColor: ShareCardTextColor = .blanc

    /// The big stat values — a flat color, or the brand rose→violet sweep for the `runup` style
    /// (fixed hexes, same stops as the route trace, deliberately not the in-app theme tokens: the
    /// exported image shouldn't change with an unrelated app setting).
    private var valueStyle: AnyShapeStyle {
        switch textColor {
        case .blanc: return AnyShapeStyle(Color.white)
        case .noir: return AnyShapeStyle(Color(hex: 0x0E0E14))
        case .runup: return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF3D7F), Color(hex: 0x8A5CFF)], startPoint: .leading, endPoint: .trailing))
        }
    }

    /// Labels, wordmark and date — a quieter companion to `valueStyle`.
    private var secondaryColor: Color {
        switch textColor {
        case .blanc: return .white.opacity(0.9)
        case .noir: return Color(hex: 0x0E0E14).opacity(0.9)
        case .runup: return Color(hex: 0xFF3D7F)
        }
    }

    /// Dark text needs a LIGHT halo to hold up over dark photos, and vice versa.
    private var outlineIsLight: Bool { textColor == .noir }

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
        // One compact, centered block with generous transparent margins around it — the previous
        // pass spread the content across the full 360×640 canvas, which covered the whole photo
        // once layered on a story. A tight sticker-like block over an untouched photo is the
        // instagramable shape.
        VStack(spacing: 0) {
            if normalizedRoutePoints.count > 1 {
                neonRouteTrace
                    .frame(height: 160)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 16) {
                statBlock("DISTANCE", String(format: "%.2f km", run.distanceKm), valueSize: 58)
                statBlock("ALLURE", "\(run.avgPace) /km", valueSize: 40)
                statBlock("TEMPS", PaceModel.formatDuration(Double(run.durationSeconds)), valueSize: 40)
            }

            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    AppMarkView(size: 22, radius: 6)
                    Text("RUNUP").font(RUFont.bebas(15)).tracking(4).foregroundStyle(valueStyle)
                }
                Text(Self.dateFormatter.string(from: run.date))
                    .font(RUFont.mono(9.5))
                    .tracking(1)
                    .foregroundColor(secondaryColor.opacity(0.85))
            }
            .modifier(OutlinedTextShadow(light: outlineIsLight))
            .padding(.top, 22)
        }
        .frame(width: 360, height: 640)
    }

    /// One Strava-style stacked stat — small tracked label over a big Bebas value, centered.
    private func statBlock(_ label: String, _ value: String, valueSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(RUFont.sans(11.5, weight: .bold))
                .tracking(2.5)
                .foregroundColor(secondaryColor)
                .modifier(OutlinedTextShadow(light: outlineIsLight))
            Text(value)
                .font(RUFont.bebas(valueSize))
                .foregroundStyle(valueStyle)
                .modifier(OutlinedTextShadow(light: outlineIsLight))
                // Rose neon glow only on the brand-gradient style, where it belongs to the look —
                // around plain white (or black) text it read as too much.
                .shadow(color: Color(hex: 0xFF0F5B).opacity(textColor == .runup ? 0.3 : 0), radius: 22)
        }
        .frame(maxWidth: .infinity)
    }

    /// Legibility over ANY photo without a background veil: a tight, near-opaque shadow hugging
    /// the glyphs (reads as an outline, the trick text-over-video apps use) plus a wider soft
    /// halo. `light` flips the halo to white for the black-text style — a dark outline under dark
    /// text would vanish over a dark photo.
    private struct OutlinedTextShadow: ViewModifier {
        var light: Bool = false

        func body(content: Content) -> some View {
            content
                .shadow(color: light ? .white.opacity(0.9) : .black.opacity(0.85), radius: 1.5, x: 0, y: light ? 0 : 1)
                .shadow(color: light ? .white.opacity(0.5) : .black.opacity(0.45), radius: 10, x: 0, y: light ? 0 : 3)
        }
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
