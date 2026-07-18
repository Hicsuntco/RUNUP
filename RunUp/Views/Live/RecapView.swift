import SwiftUI
import UIKit

/// Post-run recap + "Ressenti" debrief. Mirrors `RecapScreen` in screensA.jsx — this is the
/// entry point to the adaptive-plan mechanic (submitting RPE recalculates the next session).
struct RecapView: View {
    @Environment(AppState.self) private var appState
    @State private var showDebrief = false
    /// The "instagrammable" share card (real route trace + distance/pace), rendered off-screen
    /// once via `ImageRenderer` as soon as the recap appears — a share sheet needs a ready item
    /// to present, and rendering this small a view is fast enough that eager beats on-demand
    /// (no visible delay when tapping "Partager", no separate render-then-share double tap).
    @State private var shareImage: Image?

    private var run: RunRecord? { appState.lastRun }

    var body: some View {
        if let run {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader(run)

                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            statTile(String(format: "%.2f", run.distanceKm), "KM")
                            statTile(AdaptivePlanEngine.fmt(Double(run.durationSeconds)), "TEMPS")
                            statTile(run.avgPace, "ALLURE MOY")
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            statTile("\(run.avgHeartRate)", "FC MOY", RUColor.rose)
                            statTile("\(run.kcal)", "KCAL", RUColor.cyan)
                            statTile("+\(run.elevationGainM)", "D+ (m)", RUColor.lime)
                        }

                        EyebrowLabel(text: "Splits par km", color: RUColor.text3).padding(.top, 8)

                        VStack(spacing: 5) {
                            let fractions = splitFractions(run.splits)
                            ForEach(run.splits.indices, id: \.self) { i in
                                splitRow(index: i, time: run.splits[i], fraction: fractions[i], isLast: i == run.splits.count - 1)
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
                            .padding(.top, 6)
                        }

                        Button("DONNER MON RESSENTI") { showDebrief = true }
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
                guard shareImage == nil else { return }
                renderShareCard(for: run)
            }
        } else {
            Color.clear.onAppear { appState.go(.home) }
        }
    }

    private func heroHeader(_ run: RunRecord) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(hex: 0x12121A), RUColor.bg], startPoint: .top, endPoint: .bottom)
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
                Text(run.title).displayStyle(26).foregroundColor(.white)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(height: 190)
        .clipped()
    }

    private func renderShareCard(for run: RunRecord) {
        let renderer = ImageRenderer(content: RunShareCardView(run: run))
        renderer.scale = 3 // retina-quality output at the card's 360×640pt logical size
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    private func statTile(_ value: String, _ label: String, _ color: Color = .white) -> some View {
        VStack(spacing: 3) {
            Text(value).displayStyle(24).foregroundColor(color)
            Text(label).font(RUFont.sans(8, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .ruCard(radius: 14)
    }

    private func splitRow(index: Int, time: String, fraction: Double, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)").font(RUFont.mono(11)).foregroundColor(RUColor.text2).frame(width: 16)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isLast ? RUColor.rose : Color.white.opacity(0.14))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 22)
            Text(time).displayStyle(14).foregroundColor(isLast ? RUColor.rose2 : .white).frame(width: 38, alignment: .trailing)
        }
    }

    private func splitPaceSeconds(_ time: String) -> Double? {
        let parts = time.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// Bar length relative to this run's own fastest/slowest split — was previously
    /// `0.45 + index * 0.07`, a shape that grew with the split's position in the list regardless
    /// of whether the runner actually sped up or slowed down.
    private func splitFractions(_ splits: [String]) -> [Double] {
        let seconds = splits.map { splitPaceSeconds($0) }
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
