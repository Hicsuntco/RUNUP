import SwiftUI
import SwiftData

/// A dedicated "your week" moment — Strava's weekly email, but a full native screen reachable from
/// tapping the Sunday-evening local notification (`NotificationService.scheduleWeeklyRecapReminder`)
/// or the "Cette semaine" card in `StatsView`. `StatsView.weekCard` already surfaces this week's km
/// inline among many other trend cards; this exists because a recurring re-engagement push needs
/// somewhere worth actually opening — a real recap, not just a redirect back into the Stats tab.
/// Visual structure modeled on the "BILAN · ta semaine" reference (RUNUP 4.0 mockup, concept A ·
/// Midnight Rose): a colored 2×2 stat grid instead of one oversized hero number, a volume-per-day
/// bar chart, and a real personal-record callout — same 3 real metrics (km/séances/temps actif/
/// série) as before, no new data invented to match the mockup's own (different) stat set.
struct WeeklyRecapView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var allRuns: [RunRecord]
    @State private var chartRevealed = false
    private var profile: UserProfile { appState.profile }

    private var weekRange: Range<Date> { AdaptivePlanEngine.currentWeekRange() }
    private var weekRuns: [RunRecord] { allRuns.filter { weekRange.contains($0.date) } }

    private var lastWeekKm: Double {
        let lastWeekRange = AdaptivePlanEngine.currentWeekRange(from: (Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now))
        return allRuns.filter { lastWeekRange.contains($0.date) }.reduce(0) { $0 + $1.distanceKm }
    }

    private var totalKm: Double { weekRuns.reduce(0) { $0 + $1.distanceKm } }
    private var totalDurationSeconds: Int { weekRuns.reduce(0) { $0 + $1.durationSeconds } }

    private var avgPaceSecPerKm: Double? {
        let paces = weekRuns.compactMap { PaceModel.parseSecPerKm($0.avgPace) }
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / Double(paces.count)
    }

    /// True only when this week's real distance beats every other real week on record — mirrors
    /// the mockup's "TA MEILLEURE SEMAINE" title, but never claims it without the numbers to
    /// back it (a generic title otherwise, rather than always claiming "best week").
    private var isBestWeekEver: Bool {
        guard totalKm > 0 else { return false }
        var weekTotals: [Date: Double] = [:]
        for run in allRuns {
            let start = AdaptivePlanEngine.currentWeekRange(from: run.date).lowerBound
            weekTotals[start, default: 0] += run.distanceKm
        }
        let otherWeeksMax = weekTotals.filter { $0.key != weekRange.lowerBound }.values.max() ?? 0
        return totalKm > otherWeeksMax
    }

    private var weekDateRangeLabel: String {
        let start = weekRange.lowerBound
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(start.formatted(.dateTime.day()))-\(end.formatted(.dateTime.day().month(.wide)))"
    }

    /// A real, just-broken personal best inside this week's runs specifically (checked against
    /// every OTHER week's runs, so a record set earlier this same week doesn't get re-claimed on
    /// every visit) — prefers a pace record (the more universally exciting one for a runner) and
    /// falls back to a distance record. Nil, not a fabricated one, when neither happened.
    private var weekRecord: (label: String, value: String)? {
        let priorRuns = allRuns.filter { !weekRange.contains($0.date) }
        let priorBestPace = priorRuns.compactMap { PaceModel.parseSecPerKm($0.avgPace) }.min()
        let thisWeekBestPaceRun = weekRuns
            .compactMap { run -> (RunRecord, Double)? in PaceModel.parseSecPerKm(run.avgPace).map { (run, $0) } }
            .min(by: { $0.1 < $1.1 })
        if let priorBestPace, let (run, pace) = thisWeekBestPaceRun, pace < priorBestPace {
            return ("Nouveau record d'allure", "\(PaceModel.formatDuration(pace))/km sur \(String(format: "%.1f", run.distanceKm)) km")
        }
        let priorBestDistance = priorRuns.map(\.distanceKm).max() ?? 0
        if let longest = weekRuns.max(by: { $0.distanceKm < $1.distanceKm }), longest.distanceKm > priorBestDistance {
            return ("Nouveau record de distance", String(format: "%.1f km", longest.distanceKm))
        }
        return nil
    }

    /// Real per-weekday distance within this week's runs, Monday...Sunday — same weekday remap
    /// `AdaptivePlanEngine` uses elsewhere (`Calendar.component(.weekday)` is Sunday-first).
    private var dailyVolumes: [Double] {
        var totals = [Double](repeating: 0, count: 7)
        for run in weekRuns {
            let weekday = (Calendar.current.component(.weekday, from: run.date) + 5) % 7
            totals[weekday] += run.distanceKm
        }
        return totals
    }

    private var todayWeekdayIndex: Int {
        (Calendar.current.component(.weekday, from: .now) + 5) % 7
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.stats) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "Semaine \(profile.weekNumber) · \(weekDateRangeLabel)", color: RUColor.rose)
                        Text(isBestWeekEver ? "Ta meilleure semaine 🔥" : "Bilan de la semaine")
                            .displayStyle(24).foregroundColor(RUColor.textPrimary)
                    }
                }

                statsGrid

                volumeChart

                if let weekRecord {
                    recordCard(weekRecord)
                }

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

    /// 2×2 grid of equally-weighted stats, each its own color — replaces the old single oversized
    /// "distance totale" hero + a plain row of metrics underneath, matching the mockup's stat
    /// grid where the km figure is one cell among four, not a standalone hero.
    private var statsGrid: some View {
        let deltaKm = totalKm - lastWeekKm
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(value: String(format: "%.1f", totalKm), unit: "km", label: "PARCOURUS", color: RUColor.rose,
                         chip: lastWeekKm > 0 ? (deltaKm >= 0 ? "▲ \(String(format: "%.1f", deltaKm))" : "▼ \(String(format: "%.1f", -deltaKm))") : nil,
                         chipColor: deltaKm >= 0 ? RUColor.lime : RUColor.amber)
                statTile(value: "\(weekRuns.count)", unit: nil, label: "SÉANCES", color: RUColor.lime, chip: nil, chipColor: RUColor.lime)
            }
            HStack(spacing: 10) {
                statTile(value: PaceModel.formatTotalDuration(totalDurationSeconds), unit: nil, label: "TEMPS ACTIF", color: RUColor.cyan, chip: nil, chipColor: RUColor.cyan)
                statTile(value: "\(profile.streak)", unit: "j", label: "SÉRIE", color: RUColor.amber, chip: nil, chipColor: RUColor.amber)
            }
        }
    }

    private func statTile(value: String, unit: String?, label: String, color: Color, chip: String?, chipColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value).displayStyle(30).foregroundColor(color)
                if let unit {
                    Text(unit).font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                }
            }
            Text(label).font(RUFont.sans(9, weight: .bold)).tracking(1).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .ruCard()
        // Floats in a corner instead of sharing the vertical flow, so the one tile that has a
        // chip (the km delta vs. last week) doesn't push its own number down relative to the
        // other 3 tiles that don't.
        .overlay(alignment: .topTrailing) {
            if let chip {
                StatChip(text: chip, color: chipColor).padding(8)
            }
        }
    }

    private var volumeChart: some View {
        let bars = dailyVolumes
        let maxBar = max(bars.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Volume par jour (km)")
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(bars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == todayWeekdayIndex ? RUColor.rose : RUColor.line)
                        // Bars grow up from the baseline day-by-day on appear — same "revealed,
                        // not pre-drawn" treatment the Recap splits and the Home ring already get.
                        .frame(height: chartRevealed ? max(4, bars[i] / maxBar * 60) : 4)
                        .frame(maxWidth: .infinity)
                        .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.05), value: chartRevealed)
                }
            }
            .frame(height: 60, alignment: .bottom)
            .onAppear { chartRevealed = true }
            HStack {
                ForEach(DayStatus.letters, id: \.self) { letter in
                    Text(letter).font(RUFont.sans(9, weight: .bold)).foregroundColor(RUColor.text3).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .ruCard()
    }

    private func recordCard(_ record: (label: String, value: String)) -> some View {
        HStack(spacing: 12) {
            Text("🏅").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(record.label).font(RUFont.sans(12, weight: .bold)).foregroundColor(RUColor.textPrimary)
                // No "+120 XP" suffix — no record-specific XP is ever granted (the 120 is the
                // ordinary per-debrief award), so the label promised a bonus that doesn't exist.
                Text(record.value).foregroundColor(RUColor.violet).fontWeight(.bold)
                    .font(RUFont.sans(12))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RUColor.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.violet.opacity(0.3), lineWidth: RUSpacing.hairline))
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
