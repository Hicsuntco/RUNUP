import SwiftUI
import SwiftData

/// A dedicated "your week" moment — Strava's weekly email, but a full native screen reachable from
/// tapping the Sunday-evening local notification (`NotificationService.scheduleWeeklyRecapReminder`)
/// or the "Cette semaine" card in `StatsView`. `StatsView.weekCard` already surfaces this week's km
/// inline among many other trend cards; this exists because a recurring re-engagement push needs
/// somewhere worth actually opening — a real recap, not just a redirect back into the Stats tab.
struct WeeklyRecapView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var allRuns: [RunRecord]
    private var profile: UserProfile { appState.profile }

    private var weekRange: Range<Date> { AdaptivePlanEngine.currentWeekRange() }
    private var weekRuns: [RunRecord] { allRuns.filter { weekRange.contains($0.date) } }

    private var lastWeekKm: Double {
        let lastWeekRange = AdaptivePlanEngine.currentWeekRange(from: (Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now))
        return allRuns.filter { lastWeekRange.contains($0.date) }.reduce(0) { $0 + $1.distanceKm }
    }

    private var totalKm: Double { weekRuns.reduce(0) { $0 + $1.distanceKm } }
    private var totalDurationSeconds: Int { weekRuns.reduce(0) { $0 + $1.durationSeconds } }
    private var totalKcal: Int { weekRuns.reduce(0) { $0 + $1.kcal } }

    private var avgPaceSecPerKm: Double? {
        let paces = weekRuns.compactMap { PaceModel.parseSecPerKm($0.avgPace) }
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / Double(paces.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.stats) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "Récap", color: RUColor.rose)
                        Text("Ta semaine").displayStyle(22).foregroundColor(RUColor.textPrimary)
                    }
                }

                heroCard

                HStack(spacing: 24) {
                    MetricColumn(value: "\(weekRuns.count)/\(profile.runningDays.count)", label: "séances", valueSize: 22)
                    MetricColumn(value: PaceModel.formatTotalDuration(totalDurationSeconds), label: "temps total", valueSize: 22)
                    MetricColumn(value: "\(totalKcal)", label: "kcal", valueColor: RUColor.cyan, valueSize: 22)
                    MetricColumn(value: "\(profile.streak)", label: "jours de série", valueColor: profile.streak > 0 ? RUColor.amber : RUColor.textPrimary, valueSize: 22)
                }
                .padding(16)
                .ruCard()

                if let avgPaceSecPerKm {
                    HStack {
                        EyebrowLabel(text: "Allure moyenne")
                        Spacer()
                        Text("\(PaceModel.formatDuration(avgPaceSecPerKm))/km").displayStyle(18).foregroundColor(RUColor.textPrimary)
                    }
                    .padding(16)
                    .ruCard()
                }

                EyebrowLabel(text: "Courses de la semaine", color: RUColor.text3).padding(.top, 6)

                if weekRuns.isEmpty {
                    Text("Pas encore de course cette semaine — tu as le temps.")
                        .font(RUFont.sans(12))
                        .foregroundColor(RUColor.text2)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ruCard()
                } else {
                    VStack(spacing: 8) {
                        ForEach(weekRuns) { run in
                            runRow(run)
                        }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(RUColor.bg)
    }

    private var heroCard: some View {
        let deltaKm = totalKm - lastWeekKm
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                EyebrowLabel(text: "Distance totale", color: RUColor.rose2)
                Spacer()
                if lastWeekKm > 0 {
                    StatChip(
                        text: deltaKm >= 0 ? "▲ +\(String(format: "%.1f", deltaKm)) km vs sem. dernière" : "▼ \(String(format: "%.1f", -deltaKm)) km vs sem. dernière",
                        color: deltaKm >= 0 ? RUColor.lime : RUColor.amber
                    )
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", totalKm)).displayStyle(52).foregroundColor(RUColor.textPrimary)
                Text("km").font(RUFont.sans(15)).foregroundColor(RUColor.text2)
            }
        }
        .padding(18)
        .ruHeroCard(radius: 20)
    }

    private func runRow(_ run: RunRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(run.title).font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                Text(run.date.formatted(.dateTime.weekday(.wide).day().month())).font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
            }
            Spacer()
            Text(String(format: "%.2f km", run.distanceKm)).font(RUFont.mono(12)).foregroundColor(RUColor.text2)
            Text(run.avgPace + "/km").font(RUFont.mono(12)).foregroundColor(RUColor.text2)
        }
        .padding(14)
        .ruCard(radius: 14)
    }
}
