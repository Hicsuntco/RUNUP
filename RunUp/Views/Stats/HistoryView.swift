import SwiftUI
import SwiftData

/// Run history — mirrors `HistoryScreen` in screensC.jsx. Uses a real `@Query` over `RunRecord`
/// so newly completed runs appear automatically ahead of older ones (newest-first).
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]
    @State private var showAddRun = false
    @State private var pendingDelete: RunRecord?

    var body: some View {
        // A plain ScrollView/VStack can't do real swipe-to-delete — .swipeActions only works on
        // List rows — so this is a List dressed up to look like the same card-based layout
        // (clear row backgrounds, hidden separators/insets) rather than a stock List.
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if runs.isEmpty {
                Text("Aucune course pour l'instant — termine une sortie ou ajoutes-en une manuellement.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    .padding(.horizontal, RUSpacing.pagePadding)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(runs) { run in
                runCard(run)
                    .listRowInsets(EdgeInsets(top: 4, leading: RUSpacing.pagePadding, bottom: 4, trailing: RUSpacing.pagePadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button("Supprimer", role: .destructive) { pendingDelete = run }
                    }
                    .contextMenu {
                        Button("Supprimer", role: .destructive) { pendingDelete = run }
                    }
            }

            Color.clear.frame(height: 130)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RUColor.bg)
        .sheet(isPresented: $showAddRun) { AddRunSheet() }
        .alert(
            "Supprimer cette course ?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Supprimer", role: .destructive) {
                if let run = pendingDelete {
                    // A deleted run that was today's "séance faite" shouldn't leave the daily
                    // goals gauge claiming it's done with nothing left backing it.
                    if Calendar.current.isDateInToday(run.date) {
                        AdaptivePlanEngine.undoTodaySessionCompletion(appState.profile)
                    }
                    modelContext.delete(run)
                }
                pendingDelete = nil
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Cette action est définitive.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BackChevronButton { appState.go(.stats) }
            VStack(alignment: .leading, spacing: 1) {
                EyebrowLabel(text: "\(runs.count) sortie\(runs.count > 1 ? "s" : "")", color: RUColor.rose)
                Text("Historique").displayStyle(22).foregroundColor(RUColor.textPrimary)
            }
            Spacer()
            Button(action: { showAddRun = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(RUColor.card, in: Circle())
                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Ajouter une course")
        }
        .padding(.horizontal, RUSpacing.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func runCard(_ run: RunRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(run.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                Spacer()
                // A manually-logged run has no real heart-rate reading — 0 would just be a fake
                // number dressed up as data, so the line is dropped entirely instead.
                if run.avgHeartRate > 0 {
                    Text("FC moy \(run.avgHeartRate)").font(RUFont.sans(11)).foregroundColor(RUColor.text3)
                }
            }
            Text(run.title).font(RUFont.sans(15, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            HStack(spacing: 20) {
                MetricColumn(value: String(format: "%.1f", locale: Locale(identifier: "fr_FR"), run.distanceKm), label: "km", valueSize: 20)
                MetricColumn(value: PaceModel.formatDuration(Double(run.durationSeconds)), label: "temps", valueSize: 20)
                MetricColumn(value: run.avgPace, label: "allure moy", valueColor: RUColor.rose2, valueSize: 20)
            }
        }
        .padding(16)
        .ruCard()
    }
}
