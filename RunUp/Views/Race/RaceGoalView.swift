import SwiftUI

/// Race/objective detail — mirrors `RaceScreen` in screensB.jsx. Title/date/pace/prep are all
/// dynamic, computed from the real profile state (race target, `PaceModel`, `AdaptivePlanEngine`)
/// instead of a fixed 10K pacing table shown regardless of the actual goal or distance.
struct RaceGoalView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    private var shape: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
    }

    /// Real target pace (seconds/km) implied by the goal chrono over the goal distance — falls
    /// back to the reference threshold pace `PaceModel` already seeds the plan from when there's
    /// no race chrono (progress/weight/restart/health goals).
    private var racePaceSecPerKm: Double? {
        guard let chrono = profile.raceChrono,
              let km = profile.effectiveRaceDistanceKm,
              let totalSeconds = PaceModel.parseChronoSeconds(chrono, distance: profile.raceDistance),
              km > 0
        else { return nil }
        return totalSeconds / km
    }

    private var targetPaceLabel: String {
        PaceModel.formatDuration(racePaceSecPerKm ?? PaceModel.zones(for: profile).thresholdSecPerKm)
    }

    /// Splits the real goal distance into 3-4 pacing phases around the real target pace, instead
    /// of a fixed "1-3 / 4-8 / 9 / 10 km @ 4:52.../4:20" table that only ever made sense for a 10K.
    private var pacingPlan: [(String, String, String)] {
        let km = profile.effectiveRaceDistanceKm ?? 10
        let base = racePaceSecPerKm ?? PaceModel.zones(for: profile).thresholdSecPerKm
        let totalKm = max(3, Int(km.rounded()))
        let startEnd = max(1, Int((Double(totalKm) * 0.2).rounded()))
        let cruiseEnd = min(totalKm - 1, max(startEnd + 1, Int((Double(totalKm) * 0.75).rounded())))

        func rangeLabel(_ a: Int, _ b: Int) -> String { a == b ? "\(a) km" : "\(a)-\(b) km" }

        var plan: [(String, String, String)] = [
            (rangeLabel(1, startEnd), String(localized: "Départ contrôlé"), PaceModel.formatDuration(base + 8)),
            (rangeLabel(startEnd + 1, cruiseEnd), String(localized: "Rythme cible"), PaceModel.formatDuration(base))
        ]
        if cruiseEnd + 1 < totalKm {
            plan.append((rangeLabel(cruiseEnd + 1, totalKm - 1), String(localized: "Relance"), PaceModel.formatDuration(max(60, base - 5))))
        }
        plan.append((rangeLabel(totalKm, totalKm), String(localized: "Sprint final"), PaceModel.formatDuration(max(60, base - 20))))
        return plan
    }

    /// Real structural race-day guidance for HYROX — no fake per-km split table (the format isn't
    /// a continuous run), but real pace/effort advice grounded in what actually determines a HYROX
    /// result: running under accumulated station fatigue, not raw running speed alone.
    private var hyroxStrategy: [(String, String)] {
        [
            (String(localized: "Segments course (8 × 1 km)"), String(localized: "vise \(targetPaceLabel) /km sur chaque segment, même sous fatigue — pas l'allure d'un 8 km isolé")),
            (String(localized: "Stations"), String(localized: "technique avant vitesse — un geste propre coûte moins cher qu'un geste rapide et cassé")),
            (String(localized: "Gestion globale"), String(localized: "les 4 premiers km + stations posent le rythme, les 4 derniers décident du chrono"))
        ]
    }

    /// Only `.race`/`.hyrox` have a real race day with a distance/chrono to pace against — for
    /// `.progress`/`.restart`/`.weight`/`.health` this screen used to show a "JOURS" countdown to
    /// nothing, a fabricated "ALLURE" from `PaceModel`'s generic threshold, and a full race-day
    /// pacing table built on a hardcoded 10 km fallback (`?? 10` above) — all meaningless for a
    /// goal with no actual race.
    private var hasRealRaceDay: Bool { profile.goalId == .race || profile.goalId == .hyrox }

    private var goalTitle: String {
        profile.goalDisplay.contains("·") ? String(profile.goalDisplay.split(separator: "·").first ?? "").trimmingCharacters(in: .whitespaces) : profile.goalDisplay
    }

    private var goalTarget: String {
        guard let part = profile.goalDisplay.split(separator: "·").last else { return profile.goalDisplay }
        return String(part).trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BackTitleHeaderView(eyebrow: "Ton objectif", title: goalTitle, titleSize: 24) { appState.go(.profile) }
                Text(dateLine).font(RUFont.sans(.body)).foregroundColor(RUColor.text2).padding(.leading, 34)

                if hasRealRaceDay {
                    HStack(spacing: 10) {
                        tile(profile.daysUntilRace.map(String.init) ?? "—", String(localized: "JOUR\((profile.daysUntilRace ?? 2) > 1 ? "S" : "")"), highlighted: true)
                        tile(goalTarget, "OBJECTIF", highlighted: false)
                        tile(targetPaceLabel, "ALLURE", highlighted: false)
                    }
                } else {
                    HStack(spacing: 10) {
                        tile("\(profile.weekNumber)", "SEMAINE", highlighted: true)
                        tile(goalTarget, "OBJECTIF", highlighted: false)
                        tile("\(profile.streak)", "SÉRIE", highlighted: false)
                    }
                }

                VStack(spacing: 10) {
                    HStack {
                        RUCardHeader(icon: "calendar", tint: RUColor.rose, title: "Préparation")
                        if let total = shape.totalWeeks {
                            StatChip(text: String(localized: "Semaine \(min(profile.weekNumber, total))/\(total)"), color: RUColor.lime)
                        }
                    }
                    if let total = shape.totalWeeks {
                        LinearBar(fraction: min(1, Double(profile.weekNumber) / Double(total)), color: RUColor.rose, height: 8, gradient: LinearGradient(colors: [RUColor.rose, RUColor.lime], startPoint: .leading, endPoint: .trailing))
                        HStack {
                            phaseLabel(String(localized: "Base"), state: phaseState(endWeek: shape.baseWeeks))
                            Spacer()
                            phaseLabel(String(localized: "Spécifique"), state: phaseState(endWeek: shape.baseWeeks + shape.specificWeeks))
                            Spacer()
                            phaseLabel(String(localized: "Affûtage"), state: phaseState(endWeek: total))
                        }
                    } else {
                        Text("Programme ouvert, sans date de fin fixe.")
                            .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    }
                }
                .padding(14)
                .ruCard()

                // A per-km pacing table with a "Sprint final" phase only makes sense for a
                // continuous road-race distance — HYROX alternates running with functional
                // stations, so it gets its own honest, structural strategy instead of a fake
                // per-km split table over a format that isn't a straight run.
                if !hasRealRaceDay {
                    VStack(alignment: .leading, spacing: 8) {
                        RUCardHeader(icon: "location.fill", tint: RUColor.violet, title: "Où tu en es")
                        Text(LocalizedStringKey(progressSummary))
                            .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
                    }
                    .padding(14)
                    .ruCard()
                } else if profile.goalId == .hyrox {
                    RUCardHeader(icon: "flag.checkered", tint: RUColor.rose2, title: "Stratégie · jour J")
                    VStack(spacing: 6) {
                        ForEach(hyroxStrategy.indices, id: \.self) { i in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: RUSpacing.radiusBar).fill(RUColor.text4).frame(width: 3, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(hyroxStrategy[i].0).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                    Text(hyroxStrategy[i].1).font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                        }
                    }
                } else {
                    RUCardHeader(icon: "speedometer", tint: RUColor.rose2, title: "Stratégie d'allure · jour J")
                    VStack(spacing: 6) {
                        ForEach(pacingPlan.indices, id: \.self) { i in
                            let isLast = i == pacingPlan.count - 1
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: RUSpacing.radiusBar).fill(isLast ? RUColor.rose : RUColor.text4).frame(width: 3, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pacingPlan[i].1).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                    Text(pacingPlan[i].0).font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                                }
                                Spacer()
                                (Text(pacingPlan[i].2).font(RUFont.display(18)).foregroundColor(isLast ? RUColor.rose2 : RUColor.textPrimary)
                                    + Text(" /km").font(RUFont.sans(.micro)).foregroundColor(RUColor.text2))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                        }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private var progressSummary: String {
        switch profile.goalId {
        case .weight: return "Pas de date fixe pour ce genre d'objectif — le programme ajuste ton volume semaine après semaine pour que la charge reste tenable dans la durée."
        case .health: return "Pas de course à préparer ici — le coach cale un rythme régulier, adapté à ta forme du jour, pour construire l'habitude sur la durée."
        case .restart: return "Reprise en douceur : le programme remonte le volume progressivement pour éviter la blessure, avant de repartir sur un rythme plus soutenu."
        default: return "Objectif ouvert, sans date de fin fixe — le programme continue de progresser semaine après semaine selon ta forme."
        }
    }

    private var dateLine: String {
        guard let date = profile.raceDate else { return String(localized: "Date à définir") }
        return Self.dateFormatter.string(from: date)
    }

    private enum PhaseState { case done, current, upcoming }

    /// A phase reads "done" once the program has moved past its last week, "current" while the
    /// program is inside it, "upcoming" otherwise — replaces a fixed "Base ✓ / Spécifique ● /
    /// Affûtage" that never actually reflected which block the program was in.
    private func phaseState(endWeek: Int) -> PhaseState {
        if profile.weekNumber > endWeek { return .done }
        let block = AdaptivePlanEngine.trainingBlock(forWeek: profile.weekNumber, shape: shape)
        let isCurrent = (block == .base && endWeek == shape.baseWeeks)
            || (block == .specifique && endWeek == shape.baseWeeks + shape.specificWeeks)
            || (block == .affutage && endWeek == (shape.totalWeeks ?? endWeek))
        return isCurrent ? .current : .upcoming
    }

    private func phaseLabel(_ name: String, state: PhaseState) -> some View {
        let suffix: String
        switch state {
        case .done: suffix = " ✓"
        case .current: suffix = " ●"
        case .upcoming: suffix = ""
        }
        return Text("\(name)\(suffix)").font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
    }

    private func tile(_ value: String, _ label: String, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            // Free-text values ("Sous 1h30", a custom chrono) must shrink in a third-of-screen
            // tile, not wrap or clip on 320-375pt phones.
            Text(value).displayStyle(30).foregroundColor(highlighted ? RUColor.rose2 : RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .padding(.horizontal, 6)
            // Was a bare `Text(label)` — never resolved through the String Catalog (pre-existing
            // gap on JOURS/OBJECTIF/ALLURE too), fixed in passing since this function was already
            // touched for the new SEMAINE/SÉRIE tiles.
            Text(LocalizedStringKey(label)).font(RUFont.sans(.micro, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(highlighted ? RUColor.rose.opacity(0.12) : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusLarge, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusLarge, style: .continuous).stroke(highlighted ? RUColor.rose.opacity(0.3) : RUColor.line, lineWidth: RUSpacing.hairline))
    }
}
