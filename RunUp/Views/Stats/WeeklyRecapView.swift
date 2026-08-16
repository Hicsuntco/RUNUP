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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        return "\(start.formatted(.dateTime.day().locale(Locale.current)))-\(end.formatted(.dateTime.day().month(.wide).locale(Locale.current)))"
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
            return (String(localized: "Nouveau record d'allure"), String(localized: "\(PaceModel.formatDuration(pace))/km sur \(String(format: "%.1f", locale: Locale.current, run.distanceKm)) km"))
        }
        let priorBestDistance = priorRuns.map(\.distanceKm).max() ?? 0
        if let longest = weekRuns.max(by: { $0.distanceKm < $1.distanceKm }), longest.distanceKm > priorBestDistance {
            return (String(localized: "Nouveau record de distance"), String(format: "%.1f km", locale: Locale.current, longest.distanceKm))
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
                // Was a hand-rolled copy of `BackTitleHeaderView` — the exact same
                // `HStack(spacing: 12) { BackChevronButton; VStack(spacing: 1) { eyebrow; title } }`
                // the component already renders, down to the 24pt title. Identical output (the
                // component adds a trailing `Spacer()`, which changes nothing inside a leading-
                // aligned VStack), and it picks up the catalog lookup the component does on its
                // title for free — both strings below are already keys in Localizable.xcstrings,
                // and a bare `Text(String)` never resolves through it (see `EyebrowLabel`).
                BackTitleHeaderView(
                    eyebrow: String(localized: "Semaine \(profile.weekNumber) · \(weekDateRangeLabel)"),
                    title: isBestWeekEver ? "Ta meilleure semaine 🔥" : "Bilan de la semaine",
                    titleSize: 24
                ) {
                    appState.go(.stats)
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
        .onAppear {
            // The one genuinely verified achievement moment on this screen (a real best week, or
            // a real PR) — deserves a stronger confirmation than the plain page-open every other
            // stats screen gets.
            if isBestWeekEver || weekRecord != nil { Haptics.success() }
        }
    }

    /// 2×2 grid of equally-weighted stats, each its own color — replaces the old single oversized
    /// "distance totale" hero + a plain row of metrics underneath, matching the mockup's stat
    /// grid where the km figure is one cell among four, not a standalone hero.
    private var statsGrid: some View {
        let deltaKm = totalKm - lastWeekKm
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(value: String(format: "%.1f", locale: Locale.current, totalKm), unit: "km", label: String(localized: "PARCOURUS"), color: RUColor.rose,
                         chip: lastWeekKm > 0 ? (deltaKm >= 0 ? "▲ \(String(format: "%.1f", locale: Locale.current, deltaKm))" : "▼ \(String(format: "%.1f", locale: Locale.current, -deltaKm))") : nil,
                         chipColor: deltaKm >= 0 ? RUColor.lime : RUColor.amber)
                statTile(value: "\(weekRuns.count)", unit: nil, label: String(localized: "SÉANCES"), color: RUColor.lime, chip: nil, chipColor: RUColor.lime)
            }
            HStack(spacing: 10) {
                statTile(value: PaceModel.formatTotalDuration(totalDurationSeconds), unit: nil, label: String(localized: "TEMPS ACTIF"), color: RUColor.cyan, chip: nil, chipColor: RUColor.cyan)
                statTile(value: "\(profile.streak)", unit: String(localized: "j"), label: String(localized: "SÉRIE"), color: RUColor.amber, chip: nil, chipColor: RUColor.amber)
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
                        // Dégradé rose2 → rose sur la barre du jour (comme `.db.today .b2` dans
                        // la maquette), au lieu d'un aplat : c'est le même dégradé que le bouton
                        // RUN et le sélecteur de période des Stats, donc la barre "aujourd'hui"
                        // se rattache au vocabulaire d'accent de l'app plutôt qu'à une couleur
                        // plate isolée.
                        .fill(
                            i == todayWeekdayIndex
                                ? AnyShapeStyle(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(RUColor.line)
                        )
                        // Bars grow up from the baseline day-by-day on appear — same "revealed,
                        // not pre-drawn" treatment the Recap splits and the Home ring already get.
                        .frame(height: chartRevealed ? max(4, bars[i] / maxBar * 60) : 4)
                        .frame(maxWidth: .infinity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(Double(i) * 0.05), value: chartRevealed)
                        // No per-day km value was exposed, and "today" (when this week includes
                        // it) was marked by color alone.
                        .accessibilityLabel(i == todayWeekdayIndex ? String(localized: "\(DayStatus.fullNames[i]), aujourd'hui") : DayStatus.fullNames[i])
                        .accessibilityValue("\(String(format: "%.1f", locale: Locale.current, bars[i])) km")
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

    /// La `.pr-banner` de la maquette : médaillon circulaire teinté avec un trophée, titre en
    /// gras, valeur en sous-titre. L'emoji 🏅 rendait la seule vraie récompense de l'écran plus
    /// petite et moins nette que n'importe quelle icône de l'app (un emoji ne suit ni le poids ni
    /// la couleur d'accent, et son rendu change d'une version d'iOS à l'autre) ; le médaillon lui
    /// donne la présence d'une banderole. Teinte rose comme la maquette — c'est l'accent de
    /// l'app, et le violet servait ici sans raison particulière.
    private func recordCard(_ record: (label: String, value: String)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(RUColor.rose)
                .frame(width: 38, height: 38)
                .background(RUColor.rose.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(record.label).font(RUFont.sans(12.5, weight: .bold)).foregroundColor(RUColor.textPrimary)
                // No "+120 XP" suffix — no record-specific XP is ever granted (the 120 is the
                // ordinary per-debrief award), so the label promised a bonus that doesn't exist.
                Text(record.value)
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RUColor.rose.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.rose.opacity(0.26), lineWidth: RUSpacing.hairline))
        // Le trophée et le fond teinté sont décoratifs ; sans regroupement, VoiceOver lit le
        // libellé et sa valeur comme deux arrêts, sans dire qu'il s'agit d'un record.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.label), \(record.value)")
    }

    private func runRow(_ run: RunRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(run.title).font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                Text(run.date.formatted(.dateTime.weekday(.wide).day().month().locale(Locale.current))).font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
            }
            Spacer()
            Text(String(format: "%.2f km", locale: Locale.current, run.distanceKm)).font(RUFont.mono(12)).foregroundColor(RUColor.text2)
            Text(run.avgPace + "/km").font(RUFont.mono(12)).foregroundColor(RUColor.text2)
        }
        .padding(14)
        .ruCard(radius: 14)
    }
}
