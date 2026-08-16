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
    /// Cached snapshot of `computeWeekSummaries()` — populated once in `.onAppear` and refreshed
    /// only when the week actually advances (`.onChange(of: profile.weekNumber)`), instead of a
    /// plain computed property that re-ran `AdaptivePlanEngine.generateWeekSessions` for every
    /// week 1...weeksToShow on *any* local state change in this view — including just tapping a
    /// week row to expand/collapse it (`expandedWeek` has nothing to do with what's generated).
    @State private var weekSummaries: [WeekSummary] = []

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

    private func computeWeekSummaries() -> [WeekSummary] {
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
                BackTitleHeaderView(eyebrow: String(localized: "Ton programme · \(profile.goalDisplay)"), title: "Le plan complet") {
                    appState.go(.home)
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
                    Text("Programme ouvert, sans date de fin fixe — une semaine plus légère toutes les 4 semaines pour récupérer. Il s'ajuste chaque semaine selon ta forme de la semaine passée.")
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
            weekSummaries = computeWeekSummaries()
        }
        .onChange(of: profile.weekNumber) { _, _ in
            weekSummaries = computeWeekSummaries()
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
        // Toutes les semaines sur `card`. Avec `card2` pour les semaines non courantes, leur
        // fond disparaissait sur la page (1,03:1) et il ne restait que le trait : un plan de
        // 9 à 16 semaines devenait 8 à 15 boîtes vides sous une seule carte pleine. La semaine
        // en cours se distingue déjà par son liseré rose et sa teinte d'en-tête.
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                // Deux phrases entières plutôt qu'un suffixe français recollé dans l'interpolation :
                // un fragment collé de l'extérieur ne passe jamais par le catalogue.
                Text(week.isCurrent
                     ? String(localized: "Semaine \(week.number) · \(week.block.label) · en cours")
                     : String(localized: "Semaine \(week.number) · \(week.block.label)"))
                    .font(RUFont.sans(13, weight: week.isCurrent ? .semibold : .medium)).foregroundColor(RUColor.textPrimary)
                Text(week.isCurrent
                     ? String(localized: "~\(week.estimatedKm) km · \(completedCount)/\(plannedCount) séances faites")
                     : String(localized: "~\(week.estimatedKm) km"))
                    .font(RUFont.sans(10)).foregroundColor(RUColor.text2)
            }
            Spacer()
            Text(isExpanded ? "▾" : badge)
                .foregroundColor(isExpanded ? RUColor.rose2 : color)
                .font(.system(size: 13))
                // Was read as the raw glyph description ("triangle down", "checkmark"...) instead
                // of what it actually means out of visual context.
                .accessibilityLabel(isExpanded ? String(localized: "Réduire")
                                    : isRaceWeek ? String(localized: "Semaine de course")
                                    : week.block == .affutage ? String(localized: "Phase d'affûtage")
                                    : week.isDone ? String(localized: "Semaine terminée")
                                    : String(localized: "Développer"))
        }
        .padding(13)
        .opacity(week.isDone && !week.isCurrent ? 0.6 : 1)
        .background(week.isCurrent ? RUColor.rose.opacity(0.08) : Color.clear)
        .accessibilityElement(children: .combine)
    }

    private var completedCount: Int { profile.weekSessions.filter(\.completed).count }
    private var plannedCount: Int { profile.weekSessions.filter { ($0.session?.durationMinutes ?? 0) > 0 }.count }

    private func weekDayList(_ week: WeekSummary) -> some View {
        // 2 pt entre les lignes (au lieu de 0) : la ligne du jour porte maintenant un fond teinté
        // (`.sesh.active` de la maquette), qui a besoin d'un filet d'air pour se lire comme une
        // ligne détachée et pas comme un bloc collé à ses voisines.
        VStack(spacing: 2) {
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

    /// Rendues par un `Text(String)` nu (elles transitent par un tuple), donc localisées ici :
    /// une abréviation de jour n'est pas la même dans les trois langues.
    private static let dayLetters = [
        String(localized: "Lun"), String(localized: "Mar"), String(localized: "Mer"),
        String(localized: "Jeu"), String(localized: "Ven"), String(localized: "Sam"),
        String(localized: "Dim")
    ]

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
        return HStack(spacing: 10) {
            Text(letter).displayStyle(10).foregroundColor(RUColor.text2).frame(width: 26, alignment: .leading)
            dayIcon(session: session, isRest: isRest, completed: day.completed, isToday: isToday)
            VStack(alignment: .leading, spacing: 1) {
                Text(session?.displayTitle ?? String(localized: "Repos"))
                    .font(RUFont.sans(12.5, weight: isToday ? .semibold : .regular))
                    .foregroundColor(isRest ? RUColor.text3 : RUColor.textPrimary)
                if let subtitle = session?.displaySubtitle, !isRest {
                    Text(subtitle).font(RUFont.sans(10)).foregroundColor(RUColor.text3).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let session, !isRest {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(session.durationMinutes)′ · \(session.zone)").font(RUFont.mono(10)).foregroundColor(RUColor.text2)
                    Text("\(session.pace)/km").font(RUFont.mono(9)).foregroundColor(RUColor.text3)
                }
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 10)
        // `.sesh.active` de la maquette : la ligne du jour se détache par un fond très légèrement
        // teinté + un liseré rose, au lieu d'une puce "aujourd'hui" posée au milieu de la ligne
        // qui poussait le titre de la séance et décalait la colonne durée/allure d'un jour à
        // l'autre. Teinte, pas aplat — l'accent reste un liseré et une icône.
        .background(isToday ? RUColor.rose.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isToday ? RUColor.rose.opacity(0.3) : Color.clear, lineWidth: RUSpacing.hairline)
        )
        .contentShape(Rectangle())
        // La maquette déplie le détail de la séance du jour directement sous sa ligne
        // (`.sesh-detail` : échauffement / corps de séance / retour au calme). L'app a déjà mieux
        // que ça — `SessionDetailSheet` dérive cette structure par archétype (footing continu vs
        // fractionné vs tempo, plus les formats HYROX) au lieu du même gabarit pour tout — donc on
        // ouvre cette feuille plutôt que d'en dupliquer une version appauvrie ici. Seule la ligne
        // d'aujourd'hui réagit : c'est la seule séance dont `todaySession` décrit vraiment le
        // contenu.
        .onTapGesture { if isToday { appState.openSessionDetail() } }
        // Chaque ligne était 3 à 5 arrêts VoiceOver sans lien (jour, titre, sous-titre, durée,
        // allure), et "aujourd'hui" / "faite" ne vivaient plus que dans la couleur depuis que la
        // puce et le ✓ ont fusionné dans l'icône de type.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dayRowAccessibilityLabel(day: day, isToday: isToday, isRest: isRest))
        .accessibilityAddTraits(isToday ? .isButton : [])
    }

    /// L'icône `.sesh-icon` de la maquette : une tuile qui annonce le TYPE du jour d'un coup
    /// d'œil, là où il n'y avait qu'une pastille de 6 pt rose ou grise ne distinguant que
    /// "course / repos". Le type vient de `WorkoutSession.isIntervalSession`, la seule
    /// classification que le modèle expose réellement (déjà partagée par `SessionDetailSheet` et
    /// l'écran Live) — aucune catégorie inventée au-delà de repos / endurance / fractionné.
    private func dayIcon(session: WorkoutSession?, isRest: Bool, completed: Bool, isToday: Bool) -> some View {
        let symbol: String
        if completed { symbol = "checkmark" }
        else if isRest { symbol = "moon.zzz.fill" }
        else if session?.isIntervalSession == true { symbol = "bolt.fill" }
        else { symbol = "figure.run" }

        let tint: Color = completed || isToday ? RUColor.rose : isRest ? RUColor.text3 : RUColor.text2
        return Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 26, height: 26)
            .background(isToday ? RUColor.rose.opacity(0.12) : RUColor.bg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func dayRowAccessibilityLabel(day: PlannedDay, isToday: Bool, isRest: Bool) -> String {
        var parts: [String] = [isToday ? String(localized: "\(DayStatus.fullNames[day.weekday]), aujourd'hui") : DayStatus.fullNames[day.weekday]]
        parts.append(isRest ? String(localized: "repos") : (day.session?.displayTitle ?? String(localized: "repos")))
        if let session = day.session, !isRest {
            parts.append(String(localized: "\(session.durationMinutes) minutes, \(session.zone), allure \(session.pace) par kilomètre"))
        }
        if day.completed { parts.append(String(localized: "séance faite")) }
        return parts.joined(separator: ", ")
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
