import Foundation
import SwiftUI

/// Text-color styles for the share card, picked on the recap screen before sharing — the photo
/// underneath decides which one works (white over a dark evening run, black over snow/sky, the
/// brand gradient when she wants the RunUp identity front and center).
enum ShareCardTextColor: String, CaseIterable, Identifiable {
    case blanc, noir, runup
    var id: String { rawValue }
    var label: String {
        switch self {
        case .blanc: return String(localized: "Blanc")
        case .noir: return String(localized: "Noir")
        case .runup: return "Valta" // nom de marque
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
    /// True only when `RecapView` verified this run genuinely beat every prior real run (pace or
    /// distance) — never a guess made just for the card.
    var isPersonalRecord: Bool = false

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

    private var roseGlowOpacity: Double {
        switch textColor {
        case .blanc: return 0.12
        case .noir: return 0
        case .runup: return 0.16
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    /// Le tracé réel, normalisé dans un carré 0…1 — la MÊME forme que celle parcourue.
    ///
    /// La projection vit dans `RouteGeometry`, partagée avec la vignette de l'historique : le
    /// même parcours doit avoir la même forme aux deux endroits, et une seule implémentation est
    /// la seule façon de le garantir.
    private var normalizedRoutePoints: [CGPoint] {
        RouteGeometry.normalized(run.route)
    }

    var body: some View {
        // One compact, centered block with generous transparent margins around it — the previous
        // pass spread the content across the full 360×640 canvas, which covered the whole photo
        // once layered on a story. A tight sticker-like block over an untouched photo is the
        // instagramable shape.
        VStack(spacing: 0) {
            if isPersonalRecord {
                Text("🏆 NOUVEAU RECORD")
                    .font(RUFont.sans(12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(secondaryColor)
                    .modifier(OutlinedTextShadow(light: outlineIsLight))
                    .padding(.bottom, 10)
            }
            if normalizedRoutePoints.count > 1 {
                neonRouteTrace
                    // Carré, et non plus 160 pt de haut sur toute la largeur : le tracé ne peut
                    // occuper qu'un carré sans se déformer, donc réserver un bandeau large
                    // laissait de toute façon deux marges vides de part et d'autre. 200 pt tient
                    // dans les 360 pt de la carte tout en gardant au tracé son rôle de visuel
                    // principal.
                    .frame(width: 200, height: 200)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 16) {
                // `statBlock` rend son libellé par un `Text(String)` nu.
                statBlock(String(localized: "DISTANCE"), String(format: "%.2f km", locale: Locale.current, run.distanceKm), valueSize: 58)
                statBlock(String(localized: "ALLURE"), "\(run.avgPace) /km", valueSize: 40)
                statBlock(String(localized: "TEMPS"), PaceModel.formatDuration(Double(run.durationSeconds)), valueSize: 40)
            }

            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    AppMarkView(size: 22, radius: 6)
                    Text("VALTA").font(RUFont.bebas(15)).tracking(4).foregroundStyle(valueStyle)
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
                // A whisper of rose around white, a restrained one on the gradient style, none on
                // black — tuned down twice from the original 0.3, which read as too much.
                .shadow(color: Color(hex: 0xFF0F5B).opacity(roseGlowOpacity), radius: 20)
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
            // Softened from 0.85/0.45 — enough presence for legibility over a photo, without the
            // grey-black smudge the heavier version drew around every glyph.
            content
                .shadow(color: light ? .white.opacity(0.7) : .black.opacity(0.55), radius: 1.5, x: 0, y: light ? 0 : 1)
                .shadow(color: light ? .white.opacity(0.3) : .black.opacity(0.25), radius: 8, x: 0, y: light ? 0 : 2)
        }
    }

    /// A wide, blurred pass underneath a crisp pass — the same brand gradient (rose → violet) as
    /// the app mark, drawn thick enough to read as the card's real hero visual, not a thin line
    /// tucked in a box. `drawLayer` isolates the blur filter to just that pass, so it doesn't also
    /// smear the crisp stroke drawn after it.
    private var neonRouteTrace: some View {
        Canvas { context, size in
            let inset: CGFloat = 20
            // `normalizedRoutePoints` rend un CARRÉ unité : le parcours y est déjà centré et à
            // son vrai rapport de forme. L'étaler séparément sur la largeur et la hauteur du
            // canevas défaisait exactement ce travail — ce bloc fait ~360 pt de large pour 160 de
            // haut, donc la forme repartait étirée d'un facteur 2,2 en plus de la déformation de
            // longitude. On dessine donc dans le plus grand carré centré disponible : c'est la
            // seule mise à l'échelle qui conserve la forme.
            let side = max(min(size.width, size.height) - inset * 2, 1)
            let originX = (size.width - side) / 2
            let originY = (size.height - side) / 2
            let points = normalizedRoutePoints.map {
                CGPoint(x: originX + $0.x * side, y: originY + $0.y * side)
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
