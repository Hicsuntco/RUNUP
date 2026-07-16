import SwiftUI
import SwiftData

/// Progression analytics — real computations from `RunRecord` history and the same `PaceModel`
/// that seeds the training plan, replacing what used to be entirely fabricated numbers (a fixed
/// "VO2max 52.4" that never moved, 3 fixed race predictions, a fake training-load curve) with no
/// connection whatsoever to any real run.
struct StatsView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]
    private var profile: UserProfile { appState.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HeaderView(eyebrow: "Analyse · progression", title: runs.isEmpty ? "Ta progression démarre ici" : "Ta forme évolue") {
                    Button(action: { appState.go(.history) }) {
                        HStack(spacing: 5) {
                            Text("Historique").font(RUFont.sans(11, weight: .semibold))
                            Text("›")
                        }
                        .foregroundColor(RUColor.text2)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }

                paceCard
                predictionCard
                loadCard
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private func paceSecPerKm(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    // MARK: Pace trend — was a fixed "VO2max 52.4" that never actually moved

    private var recentPacesSecPerKm: [Double] {
        runs.prefix(8).reversed().compactMap { paceSecPerKm($0.avgPace) }
    }

    private var recentAvgPace: Double? {
        let last5 = runs.prefix(5).compactMap { paceSecPerKm($0.avgPace) }
        guard !last5.isEmpty else { return nil }
        return last5.reduce(0, +) / Double(last5.count)
    }

    private var previousAvgPace: Double? {
        let previous5 = runs.dropFirst(5).prefix(5).compactMap { paceSecPerKm($0.avgPace) }
        guard !previous5.isEmpty else { return nil }
        return previous5.reduce(0, +) / Double(previous5.count)
    }

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: "Allure moyenne récente")
            if let recentAvgPace {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(PaceModel.formatDuration(recentAvgPace)).displayStyle(44).foregroundColor(.white)
                    Text("/km").font(RUFont.sans(14)).foregroundColor(RUColor.text2)
                    if let previousAvgPace {
                        let deltaSeconds = previousAvgPace - recentAvgPace // positive = faster now
                        StatChip(
                            text: deltaSeconds >= 0 ? "▲ \(Int(deltaSeconds.rounded()))″/km" : "▼ \(Int(-deltaSeconds.rounded()))″/km",
                            color: deltaSeconds >= 0 ? RUColor.lime : RUColor.amber
                        )
                    }
                }
                Text("Sur tes \(min(5, runs.count)) dernières courses").font(RUFont.sans(11)).foregroundColor(RUColor.text2)

                if recentPacesSecPerKm.count >= 2 {
                    Canvas { context, size in
                        let points = recentPacesSecPerKm
                        let minPace = points.min() ?? 0
                        let maxPace = points.max() ?? 1
                        let range = max(1, maxPace - minPace)
                        let stepX = size.width / CGFloat(points.count - 1)
                        var line = Path()
                        var fill = Path()
                        fill.move(to: CGPoint(x: 0, y: size.height))
                        for (i, p) in points.enumerated() {
                            let t = CGFloat((p - minPace) / range) // 0 = fastest ... 1 = slowest
                            let point = CGPoint(x: CGFloat(i) * stepX, y: size.height * (0.15 + 0.7 * t))
                            if i == 0 { line.move(to: point) } else { line.addLine(to: point) }
                            fill.addLine(to: point)
                        }
                        fill.addLine(to: CGPoint(x: size.width, y: size.height))
                        fill.closeSubpath()
                        context.fill(fill, with: .linearGradient(Gradient(colors: [RUColor.rose.opacity(0.35), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                        context.stroke(line, with: .color(RUColor.rose), lineWidth: 2.5)
                    }
                    .frame(height: 70)
                    .padding(.top, 6)
                }
            } else {
                Text("Termine quelques courses pour voir ton allure évoluer ici.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .ruCard()
    }

    // MARK: Race predictions — was 3 fixed fake times regardless of any real performance

    /// The fastest real run of at least 2km, if any — the most credible reference to project
    /// race times from. Falls back to the same threshold-pace anchor already seeding the plan
    /// (target time / best recent perf / level) when there's no run history yet.
    private var bestRecentPerformance: (km: Double, secPerKm: Double)? {
        let candidates = runs.prefix(10).compactMap { run -> (Double, Double)? in
            guard run.distanceKm >= 2, let pace = paceSecPerKm(run.avgPace) else { return nil }
            return (run.distanceKm, pace)
        }
        return candidates.min(by: { $0.1 < $1.1 }).map { (km: $0.0, secPerKm: $0.1) }
    }

    private var predictionReferenceKm: Double { bestRecentPerformance?.km ?? 10 }
    private var predictionReferenceSecPerKm: Double {
        bestRecentPerformance?.secPerKm ?? PaceModel.zones(for: profile).thresholdSecPerKm
    }

    private func predictedSeconds(forKm targetKm: Double) -> Double {
        PaceModel.projectedPace(fromSecPerKm: predictionReferenceSecPerKm, fromKm: predictionReferenceKm, toKm: targetKm) * targetKm
    }

    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Prédiction de course", color: RUColor.rose2)
            HStack(spacing: 8) {
                predictionTile("5 KM", PaceModel.formatDuration(predictedSeconds(forKm: 5)), highlighted: false)
                predictionTile("10 KM", PaceModel.formatDuration(predictedSeconds(forKm: 10)), highlighted: true)
                predictionTile("SEMI", PaceModel.formatDuration(predictedSeconds(forKm: 21.0975)), highlighted: false)
            }
            if bestRecentPerformance == nil {
                Text("Estimation basée sur ton profil — termine une course pour une prédiction plus précise.")
                    .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
            } else if profile.goalId == .race,
                      let raceKm = profile.raceDistance?.km,
                      let chrono = profile.raceChrono,
                      let targetSeconds = PaceModel.parseChronoSeconds(chrono, distance: profile.raceDistance) {
                let deltaSeconds = targetSeconds - predictedSeconds(forKm: raceKm)
                Text("Objectif \(profile.goalDisplay) → ")
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                    + Text(deltaSeconds >= 0 ? "en avance de \(Int(deltaSeconds))″" : "\(Int(-deltaSeconds))″ à gagner")
                        .font(RUFont.sans(11, weight: .bold)).foregroundColor(deltaSeconds >= 0 ? RUColor.lime : RUColor.amber)
                    + Text(" sur ton objectif.").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
            }
        }
        .padding(16)
        .ruHeroCard(radius: 20)
    }

    private func predictionTile(_ label: String, _ value: String, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(RUFont.sans(8, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
            Text(value).displayStyle(22).foregroundColor(highlighted ? RUColor.rose2 : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(highlighted ? RUColor.rose.opacity(0.14) : RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(highlighted ? RUColor.rose.opacity(0.3) : RUColor.line, lineWidth: RUSpacing.hairline))
    }

    // MARK: Training load — was a fixed fake bar chart + fake "ratio charge 1.1"

    private var weeklyDistances: [Double] {
        let cal = Calendar.current
        var weekTotals: [Date: Double] = [:]
        for run in runs {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: run.date)?.start else { continue }
            weekTotals[weekStart, default: 0] += run.distanceKm
        }
        let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return (0..<8).reversed().compactMap { offset in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) else { return nil }
            return weekTotals[weekStart] ?? 0
        }
    }

    /// Acute (last 7 days) vs. chronic (last 28 days weekly average) training load — a standard,
    /// real workload-ratio calculation (values around 0.8–1.3 are typically considered a "sweet
    /// spot"; consistently above ~1.5 is a common overload signal) computed from actual run dates
    /// instead of a fixed "1.1" shown regardless of anyone's real training.
    private var acuteChronicRatio: Double? {
        let cal = Calendar.current
        guard let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: .now),
              let twentyEightDaysAgo = cal.date(byAdding: .day, value: -28, to: .now)
        else { return nil }
        let last7 = runs.filter { $0.date >= sevenDaysAgo }.reduce(0) { $0 + $1.distanceKm }
        let last28 = runs.filter { $0.date >= twentyEightDaysAgo }.reduce(0) { $0 + $1.distanceKm }
        let chronicWeeklyAvg = last28 / 4
        guard chronicWeeklyAvg > 0 else { return nil }
        return last7 / chronicWeeklyAvg
    }

    private func loadZoneLabel(_ ratio: Double) -> String {
        if ratio > 1.5 { return "Charge élevée" }
        if ratio < 0.8 { return "Charge faible" }
        return "Zone optimale"
    }

    private var loadCard: some View {
        let bars = weeklyDistances
        let maxBar = max(bars.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Charge · 8 sem.")
                Spacer()
                if let ratio = acuteChronicRatio {
                    StatChip(text: loadZoneLabel(ratio), color: ratio > 1.5 ? RUColor.amber : RUColor.cyan)
                }
            }
            if runs.isEmpty {
                Text("Ta charge d'entraînement s'affichera ici après tes premières courses.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
            } else {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(bars.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(i == bars.count - 1 ? RUColor.rose : Color.white.opacity(0.14))
                            .frame(height: max(4, bars[i] / maxBar * 70))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 70, alignment: .bottom)
                HStack {
                    Text("S-7").font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                    Spacer()
                    if let ratio = acuteChronicRatio {
                        Text("ratio charge \(String(format: "%.1f", ratio))").font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                    }
                    Spacer()
                    Text("Cette sem.").font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                }
            }
        }
        .padding(16)
        .ruCard()
    }
}
