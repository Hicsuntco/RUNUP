import SwiftUI
import SwiftData

/// Run history — mirrors `HistoryScreen` in screensC.jsx. Uses a real `@Query` over `RunRecord`
/// so newly completed runs appear automatically ahead of older ones (newest-first).
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.stats) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "\(runs.count) sorties", color: RUColor.rose)
                        Text("Historique").displayStyle(22).foregroundColor(.white)
                    }
                }
                .padding(.bottom, 8)

                ForEach(runs) { run in
                    runCard(run)
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private func runCard(_ run: RunRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(run.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                Spacer()
                Text("FC moy \(run.avgHeartRate)").font(RUFont.sans(11)).foregroundColor(RUColor.text3)
            }
            Text(run.title).font(RUFont.sans(15, weight: .semibold)).foregroundColor(.white)
            HStack(spacing: 20) {
                MetricColumn(value: String(format: "%.1f", run.distanceKm), label: "km", valueSize: 20)
                MetricColumn(value: AdaptivePlanEngine.fmt(Double(run.durationSeconds)), label: "temps", valueSize: 20)
                MetricColumn(value: run.avgPace, label: "allure moy", valueColor: RUColor.rose2, valueSize: 20)
            }
        }
        .padding(16)
        .ruCard()
    }
}
