import SwiftUI
import UIKit
import SwiftData
import CoreLocation

/// Post-run recap + "Ressenti" debrief. Mirrors `RecapScreen` in screensA.jsx — this is the
/// entry point to the adaptive-plan mechanic (submitting RPE recalculates the next session).
struct RecapView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date) private var allRuns: [RunRecord]
    @State private var showDebrief = false
    /// The "instagrammable" share card (route trace + Strava-style stacked stats on a fully
    /// transparent background — see `RunShareCardView`), rendered off-screen once via
    /// `ImageRenderer` shortly after the recap appears — a share sheet needs a ready item to
    /// present, and rendering this small a view is fast enough that eager beats on-demand.
    @State private var shareImage: Image?
    /// Drives the staggered split-bar reveal — flipped in `onAppear`, after which each bar's own
    /// per-index delay takes over.
    @State private var splitsRevealed = false
    /// Text-color style for the share card — re-rendered on the spot when a chip is tapped.
    @State private var shareTextColor: ShareCardTextColor = .blanc

    private var run: RunRecord? { appState.lastRun }

    /// A genuine personal record vs every OTHER real run on file — pace (2 km+ runs only, same
    /// honest floor `StatsView.bestRecentPerformance` uses so a short jog can't "beat" a real
    /// long run's pace by comparison quirk) or raw distance. Never true against an empty history:
    /// there's nothing to have beaten yet, so a first-ever run is just a first run, not a record.
    private func isPersonalRecord(_ run: RunRecord) -> Bool {
        let priorRuns = allRuns.filter { $0 !== run }
        let priorBestPace = priorRuns.filter { $0.distanceKm >= 2 }.compactMap { PaceModel.parseSecPerKm($0.avgPace) }.min()
        let priorBestDistance = priorRuns.map(\.distanceKm).max() ?? 0
        var isPaceRecord = false
        if run.distanceKm >= 2, let pace = PaceModel.parseSecPerKm(run.avgPace), let priorBestPace {
            isPaceRecord = pace < priorBestPace
        }
        let isDistanceRecord = run.distanceKm > 0 && priorBestDistance > 0 && run.distanceKm > priorBestDistance
        return isPaceRecord || isDistanceRecord
    }

    /// A best time on a familiar loop, even when it's nowhere near an all-time PR — "same route"
    /// is a real (if approximate) match: starts within 150 m of each other and total distance
    /// within 15%, both GPS facts, not a guess about which streets were actually run.
    private func isRoutePersonalRecord(_ run: RunRecord) -> Bool {
        guard let first = run.route.first, run.distanceKm >= 1, let pace = PaceModel.parseSecPerKm(run.avgPace) else { return false }
        let startLocation = CLLocation(latitude: first.lat, longitude: first.lng)
        let similarRuns = allRuns.filter { other in
            guard other !== run, let otherFirst = other.route.first, other.distanceKm > 0 else { return false }
            let start = CLLocation(latitude: otherFirst.lat, longitude: otherFirst.lng)
            guard startLocation.distance(from: start) < 150 else { return false }
            let ratio = other.distanceKm / run.distanceKm
            return ratio > 0.85 && ratio < 1.15
        }
        guard let priorBestPace = similarRuns.compactMap({ PaceModel.parseSecPerKm($0.avgPace) }).min() else { return false }
        return pace < priorBestPace
    }

    private enum RecordKind { case overall, route }
    private func recordKind(for run: RunRecord) -> RecordKind? {
        if isPersonalRecord(run) { return .overall }
        if isRoutePersonalRecord(run) { return .route }
        return nil
    }

    var body: some View {
        if let run {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader(run)

                    if let kind = recordKind(for: run) {
                        recordBanner(kind)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            statTile(String(format: "%.2f", locale: Locale(identifier: "fr_FR"), run.distanceKm), "KM", index: 0)
                            statTile(PaceModel.formatDuration(Double(run.durationSeconds)), "TEMPS", index: 1)
                            statTile(run.avgPace, "ALLURE MOY", index: 2)
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            statTile(run.avgHeartRate > 0 ? "\(run.avgHeartRate)" : "—", "FC MOY", RUColor.rose, index: 3)
                            statTile("\(run.kcal)", "KCAL", RUColor.cyan, index: 4)
                            statTile(run.elevationGainM > 0 ? "+\(run.elevationGainM)" : "—", "D+ (m)", RUColor.lime, index: 5)
                        }

                        // Only when real per-km timings exist — a manual entry or a GPS run under
                        // 1 km has none, and `buildRunRecord` no longer fabricates a stand-in set.
                        if !run.splits.isEmpty {
                            EyebrowLabel(text: "Splits par km", color: RUColor.text3).padding(.top, 8)

                            VStack(spacing: 5) {
                                let fractions = splitFractions(run.splits)
                                ForEach(run.splits.indices, id: \.self) { i in
                                    splitRow(index: i, time: run.splits[i], fraction: fractions[i], isLast: i == run.splits.count - 1)
                                }
                            }
                        }

                        if ElevationProfileView.hasData(run.route) {
                            EyebrowLabel(text: "Profil d'élévation", color: RUColor.text3).padding(.top, 8)
                            elevationCard(run)
                        }

                        // One share action, not two — the transparent card covers both uses
                        // (shared as-is on a story, or layered over a photo), so the old
                        // opaque-card/transparent-card button pair collapsed into this. The
                        // preview shows the actual rendered PNG (on the app background, since
                        // the card itself is transparent), and the chips re-render it with
                        // the picked text color before sharing. The section is ALWAYS laid out
                        // (spinner in the preview slot until the deferred render lands) — it used
                        // to pop into the middle of the scroll ~half a second in, shifting
                        // content under her finger.
                        VStack(spacing: 10) {
                            EyebrowLabel(text: "Partage ta course", color: RUColor.text3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Group {
                                if let shareImage {
                                    shareImage
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    ProgressView().tint(RUColor.text2)
                                }
                            }
                            .frame(height: 230)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RUColor.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                            HStack(spacing: 7) {
                                ForEach(ShareCardTextColor.allCases) { style in
                                    SelectableChip(label: style.label, selected: shareTextColor == style) {
                                        shareTextColor = style
                                        renderShareCard(for: run)
                                    }
                                }
                            }
                            if let shareImage {
                                ShareLink(
                                    item: shareImage,
                                    preview: SharePreview("Ma course sur RunUp", image: shareImage)
                                ) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("PARTAGER MA COURSE")
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            } else {
                                Button(action: {}) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("PARTAGER MA COURSE")
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(true)
                                .opacity(0.5)
                            }
                            if let gpxURL = GPXExporter.fileURL(for: run) {
                                ShareLink(item: gpxURL) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down.doc")
                                        Text("EXPORTER EN GPX")
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                        .padding(.top, 10)

                        Button("DONNER MON RESSENTI") {
                            Haptics.selection()
                            showDebrief = true
                        }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, RUSpacing.pagePadding)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(RUColor.bg)
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $showDebrief) {
                DebriefSheet(run: run)
                    .runUpSheetStyle()
            }
            .onAppear {
                splitsRevealed = true
                if recordKind(for: run) != nil { Haptics.success() }
                guard shareImage == nil else { return }
                // ImageRenderer is main-actor-bound, so the 3x-scale render can't move off the
                // main thread — but it doesn't have to run during the entrance transition either,
                // which is exactly when it used to stutter the screen every run ended at.
                // Deferring it past the transition costs nothing visible: the share button only
                // renders once the image exists, ~half a second after arrival.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    renderShareCard(for: run)
                }
            }
        } else {
            Color.clear.onAppear { appState.go(.home) }
        }
    }

    private func recordBanner(_ kind: RecordKind) -> some View {
        HStack(spacing: 10) {
            Text("🏆").font(.system(size: 20))
            Text(kind == .overall ? "Nouveau record personnel !" : "Meilleur temps sur ce parcours !")
                .font(RUFont.sans(13, weight: .bold))
                .foregroundColor(RUColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RUColor.heroGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func elevationCard(_ run: RunRecord) -> some View {
        let altitudes = run.route.compactMap(\.altitude)
        let minAlt = altitudes.min() ?? 0
        let maxAlt = altitudes.max() ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            ElevationProfileView(route: run.route)
                .frame(height: 80)
            HStack {
                Text("\(Int(minAlt.rounded())) m").font(RUFont.mono(11)).foregroundColor(RUColor.text2)
                Spacer()
                Text("+\(run.elevationGainM) m D+").font(RUFont.sans(11, weight: .bold)).foregroundColor(RUColor.lime)
                Spacer()
                Text("\(Int(maxAlt.rounded())) m").font(RUFont.mono(11)).foregroundColor(RUColor.text2)
            }
        }
        .padding(14)
        .ruCard()
    }

    private func heroHeader(_ run: RunRecord) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [RUColor.bg2, RUColor.bg], startPoint: .top, endPoint: .bottom)
            if !run.route.isEmpty {
                RunRouteMapView(route: run.route)
                    .opacity(0.85)
            } else {
                // No GPS behind this run (manual entry, no-GPS "Marquer comme faite") — a
                // decorative shape rather than an empty map.
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.82))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.9, y: size.height * 0.12),
                        control1: CGPoint(x: size.width * 0.25, y: size.height * 0.35),
                        control2: CGPoint(x: size.width * 0.55, y: size.height * 0.5)
                    )
                    context.stroke(path, with: .color(RUColor.rose), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
            }
            LinearGradient(colors: [.clear, RUColor.bg], startPoint: .init(x: 0.5, y: 0.4), endPoint: .init(x: 0.5, y: 1))
            HStack {
                FrostedBackButton { appState.go(.home) }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .frame(maxHeight: .infinity, alignment: .top)
            VStack(alignment: .leading, spacing: 3) {
                EyebrowLabel(text: "✓ Séance terminée", color: RUColor.lime)
                Text(run.title).displayStyle(26).foregroundColor(RUColor.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        // Was a fixed `.frame(height: 190)` + `.clipped()` — fine for the run title at normal
        // text sizes, but at larger accessibility Dynamic Type sizes a long title wraps to 2
        // lines and `.clipped()` sliced it off entirely. `minHeight` lets the card grow to fit a
        // wrapped title instead of cropping it; the gradient/route-trace backgrounds already fill
        // whatever height they're given, so a taller card at large text sizes still looks right.
        .frame(minHeight: 190)
    }

    private func renderShareCard(for run: RunRecord) {
        let renderer = ImageRenderer(content: RunShareCardView(run: run, textColor: shareTextColor, isPersonalRecord: recordKind(for: run) != nil))
        renderer.scale = 3 // retina-quality output at the card's 360×640pt logical size
        // `isOpaque` defaults to false, which is exactly what the card needs — anything left
        // unpainted in the view keeps its alpha in the rendered UIImage, so the PNG layers
        // cleanly over any photo.
        guard let uiImage = renderer.uiImage else { return }
        shareImage = Image(uiImage: uiImage)
    }

    /// Tiles pop in one after the other (riding the same `splitsRevealed` flag as the split bars
    /// below them) — the run's numbers are the emotional payoff of the whole screen, and they used
    /// to just be there, fully formed, before the entrance transition even settled.
    private func statTile(_ value: String, _ label: String, _ color: Color = RUColor.textPrimary, index: Int = 0) -> some View {
        VStack(spacing: 3) {
            Text(value).displayStyle(24).foregroundColor(color)
            Text(label).font(RUFont.sans(8, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .ruCard(radius: 14)
        .opacity(splitsRevealed ? 1 : 0)
        .scaleEffect(splitsRevealed ? 1 : 0.92)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: splitsRevealed)
    }

    private func splitRow(index: Int, time: String, fraction: Double, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)").font(RUFont.mono(11)).foregroundColor(RUColor.text2).frame(width: 16)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(RUColor.card)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isLast ? RUColor.rose : RUColor.text4)
                        // Bars sweep in one after the other (40ms stagger per row) instead of the
                        // whole list appearing pre-drawn — same "revealed, not dumped" read as the
                        // Home ring's animate-on-appear fill, on the screen every run ends at.
                        .frame(width: geo.size.width * fraction * (splitsRevealed ? 1 : 0))
                        .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.04), value: splitsRevealed)
                }
            }
            .frame(height: 22)
            // minWidth, not a fixed width — a plain "m:ss" fits 38pt at the default text size, but
            // larger Dynamic Type sizes need the row to grow rather than truncate the split time.
            Text(time).displayStyle(14).foregroundColor(isLast ? RUColor.rose2 : RUColor.textPrimary).frame(minWidth: 38, alignment: .trailing)
        }
    }

    /// Bar length relative to this run's own fastest/slowest split — was previously
    /// `0.45 + index * 0.07`, a shape that grew with the split's position in the list regardless
    /// of whether the runner actually sped up or slowed down.
    private func splitFractions(_ splits: [String]) -> [Double] {
        let seconds = splits.map { PaceModel.parseSecPerKm($0) }
        let known = seconds.compactMap { $0 }
        guard let minSec = known.min(), let maxSec = known.max(), maxSec > minSec else {
            return splits.map { _ in 0.6 }
        }
        return seconds.map { sec in
            guard let sec else { return 0.6 }
            let t = (sec - minSec) / (maxSec - minSec) // 0 = fastest split ... 1 = slowest
            return 0.35 + (1 - t) * 0.6
        }
    }
}
