import SwiftUI

/// Full plan — mirrors `PlanScreen` in screensA.jsx, now driven by real profile state.
/// The current week's sessions come straight from `AdaptivePlanEngine`-generated data, adapted
/// once per week from the previous week's average RPE (see `refreshProgramForCurrentDate`) —
/// never after a single run. Other weeks show a template preview generated the same way, labeled
/// as such since their exact difficulty depends on adaptation that hasn't happened yet.
struct PlanView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    @State private var expandedWeek: Int?

    private struct WeekSummary: Identifiable {
        var id: Int { number }
        var number: Int
        var block: AdaptivePlanEngine.TrainingBlock
        var estimatedKm: Int
        var isDone: Bool
        var isCurrent: Bool
    }

    /// Real program shape — a race goal periodizes toward the actual race date (variable length,
    /// not a fixed 9 weeks); every other goal is open-ended (`totalWeeks == nil`), so there's no
    /// fixed "whole plan" to show — the preview window below just looks a reasonable distance ahead.
    private var shape: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
    }

    private var weeksToShow: Int {
        shape.totalWeeks ?? max(profile.weekNumber + 7, 8)
    }

    private var weekSummaries: [WeekSummary] {
        (1...weeksToShow).map { number in
            let sessions = number == profile.weekNumber
                ? profile.weekSessions
                : AdaptivePlanEngine.generateWeekSessions(weekNumber: number, tier: profile.weekTier, profile: profile)
            return WeekSummary(
                number: number,
                block: AdaptivePlanEngine.trainingBlock(forWeek: number, shape: shape),
                estimatedKm: estimatedKm(for: sessions),
                isDone: number < profile.weekNumber,
                isCurrent: number == profile.weekNumber
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.home) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "Ton programme · \(profile.goalDisplay)", color: RUColor.rose)
                        Text("Le plan complet").displayStyle(22).foregroundColor(RUColor.textPrimary)
                    }
                }

                if let total = shape.totalWeeks {
                    Text("\(total) semaines · 3 phases, calées sur ta date de course. Il s'ajuste chaque semaine selon ta forme de la semaine passée — pas séance par séance.")
                        .font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)

                    PhaseProgressBar(phases: [
                        PhaseSegment(name: "Base", done: min(profile.weekNumber, shape.baseWeeks), total: shape.baseWeeks, color: RUColor.rose),
                        PhaseSegment(name: "Spécifique", done: max(0, min(profile.weekNumber - shape.baseWeeks, shape.specificWeeks)), total: shape.specificWeeks, color: RUColor.rose2),
                        PhaseSegment(name: "Affûtage", done: max(0, min(profile.weekNumber - shape.baseWeeks - shape.specificWeeks, shape.taperWeeks)), total: shape.taperWeeks, color: RUColor.violet)
                    ])
                } else {
                    Text("Programme ouvert, sans date de fin fixe — une semaine plus légère tous les 4 semaines pour récupérer. Il s'ajuste chaque semaine selon ta forme de la semaine passée.")
                        .font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)
                }

                VStack(spacing: 6) {
                    ForEach(weekSummaries) { week in
                        weekCard(week)
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .onAppear {
            if expandedWeek == nil { expandedWeek = profile.weekNumber }
        }
    }

    private func weekCard(_ week: WeekSummary) -> some View {
        let isExpanded = expandedWeek == week.number
        return VStack(spacing: 0) {
            Button(action: { withAnimation(.easeOut(duration: 0.2)) { expandedWeek = isExpanded ? nil : week.number } }) {
                weekHeader(week, isExpanded: isExpanded)
            }
            .buttonStyle(PressableStyle())

            if isExpanded {
                weekDayList(week)
            }
        }
        .background(week.isCurrent ? RUColor.card : RUColor.card2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(week.isCurrent ? RUColor.rose.opacity(0.3) : RUColor.line, lineWidth: RUSpacing.hairline))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func weekHeader(_ week: WeekSummary, isExpanded: Bool) -> some View {
        let isRaceWeek = week.number == shape.totalWeeks && (profile.goalId == .race || profile.goalId == .hyrox)
        let badge = isRaceWeek ? "🏁" : week.block == .affutage ? "▽" : week.isDone ? "✓" : "›"
        let color: Color = isRaceWeek ? RUColor.rose : week.block == .affutage ? RUColor.violet : week.isDone ? RUColor.text3 : RUColor.text2
        return HStack(spacing: 12) {
            Text("\(week.number)").displayStyle(14).foregroundColor(week.isCurrent ? .white : RUColor.textPrimary)
                .frame(width: 30, height: 30)
                .background(week.isCurrent ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(RUColor.line, lineWidth: week.isCurrent ? 0 : RUSpacing.hairline))
            VStack(alignment: .leading, spacing: 1) {
                Text("Semaine \(week.number) · \(week.block.rawValue)\(week.isCurrent ? " · en cours" : "")")
                    .font(RUFont.sans(13, weight: week.isCurrent ? .semibold : .medium)).foregroundColor(RUColor.textPrimary)
                Text("~\(week.estimatedKm) km" + (week.isCurrent ? " · \(completedCount)/\(plannedCount) séances faites" : ""))
                    .font(RUFont.sans(10)).foregroundColor(RUColor.text2)
            }
            Spacer()
            Text(isExpanded ? "▾" : badge).foregroundColor(isExpanded ? RUColor.rose2 : color).font(.system(size: 13))
        }
        .padding(13)
        .opacity(week.isDone && !week.isCurrent ? 0.6 : 1)
        .background(week.isCurrent ? RUColor.rose.opacity(0.08) : Color.clear)
    }

    private var completedCount: Int { profile.weekSessions.filter(\.completed).count }
    private var plannedCount: Int { profile.weekSessions.filter { ($0.session?.durationMinutes ?? 0) > 0 }.count }

    private func weekDayList(_ week: WeekSummary) -> some View {
        VStack(spacing: 0) {
            if !week.isCurrent {
                Text(week.isDone ? "Résumé type de cette semaine passée" : "Aperçu — s'ajustera selon ta forme de la semaine précédente")
                    .font(RUFont.sans(9.5, weight: .semibold)).foregroundColor(RUColor.text3)
                    .padding(.horizontal, 4).padding(.top, 8)
            }
            ForEach(dayList(for: week), id: \.0) { letter, day, state in
                dayRow(letter: letter, day: day, state: state)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 6)
    }

    private static let dayLetters = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]

    private func dayList(for week: WeekSummary) -> [(String, PlannedDay, DayStatus.State?)] {
        if week.isCurrent {
            return profile.weekSessions.map { day in
                (Self.dayLetters[day.weekday], day, profile.weekStrip.first { $0.weekday == day.weekday }?.state)
            }
        }
        let preview = AdaptivePlanEngine.generateWeekSessions(weekNumber: week.number, tier: profile.weekTier, profile: profile)
        return preview.map { (Self.dayLetters[$0.weekday], $0, nil) }
    }

    private func dayRow(letter: String, day: PlannedDay, state: DayStatus.State?) -> some View {
        let session = day.session
        let isRest = session == nil || session?.durationMinutes == 0
        let isToday = state == .today
        return HStack(spacing: 11) {
            Text(letter).displayStyle(10).foregroundColor(RUColor.text2).frame(width: 30, alignment: .leading)
            Circle().fill(isRest ? RUColor.text4 : RUColor.rose).opacity(day.completed ? 1 : 0.5).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(session?.title ?? "Repos")
                    .font(RUFont.sans(12.5, weight: isToday ? .semibold : .regular))
                    .foregroundColor(isRest ? RUColor.text3 : RUColor.textPrimary)
                if let subtitle = session?.subtitle, !isRest {
                    Text(subtitle).font(RUFont.sans(10)).foregroundColor(RUColor.text3).lineLimit(2)
                }
            }
            if isToday {
                StatChip(text: "aujourd'hui", color: RUColor.rose2)
            }
            Spacer(minLength: 8)
            if let session, !isRest {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(session.durationMinutes)′ · \(session.zone)").font(RUFont.mono(10)).foregroundColor(RUColor.text2)
                    Text("\(session.pace)/km").font(RUFont.mono(9)).foregroundColor(RUColor.text3)
                }
            }
            if day.completed {
                Text("✓").foregroundColor(RUColor.rose).font(.system(size: 11))
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 4)
    }

    private func paceMinutesPerKm(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
        return m + s / 60
    }

    private func estimatedKm(for sessions: [PlannedDay]) -> Int {
        let total = sessions.compactMap { day -> Double? in
            guard let session = day.session, session.durationMinutes > 0, let paceMin = paceMinutesPerKm(session.pace) else { return nil }
            return Double(session.durationMinutes) / paceMin
        }.reduce(0, +)
        return Int(total.rounded())
    }
}
