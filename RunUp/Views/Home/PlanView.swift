import SwiftUI

/// Le plan complet. Les séances de la semaine en cours viennent des données générées par
/// `AdaptivePlanEngine`, adaptées une fois par semaine à partir du RPE moyen de la semaine
/// précédente (voir `refreshProgramForCurrentDate`) — jamais après une seule course. Les autres
/// semaines montrent un aperçu type généré de la même façon, annoncé comme tel puisque leur
/// difficulté exacte dépend d'une adaptation qui n'a pas encore eu lieu.
///
/// # Pourquoi trois groupes plutôt qu'une liste
///
/// L'écran empilait 8 à 16 cartes identiques, chacune repliable, chacune portant un chiffre, deux
/// lignes de texte et un glyphe. Un plan de 16 semaines devenait 16 boîtes qui se ressemblaient,
/// et la seule qui compte un jour donné — celle d'aujourd'hui — était noyée au milieu.
///
/// Les semaines sont maintenant séparées selon ce qu'on en fait :
/// - **la semaine en cours** est une carte à part, dépliée d'office, sans mécanique de pliage :
///   c'est l'écran qu'on vient consulter, il n'y a rien à déplier pour l'atteindre ;
/// - **les semaines à venir** sont des lignes calmes, groupées PAR PHASE sous un intertitre. Le
///   groupe porte l'information que 16 lignes répétaient une à une, et le plan se lit alors comme
///   sa structure réelle — Base, Spécifique, Affûtage — au lieu d'une numérotation ;
/// - **les semaines passées** sont derrière un seul dépliant, fermé par défaut. Neuf semaines
///   faites, c'était neuf lignes d'archive avant la première ligne utile.
struct PlanView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    @State private var expandedWeek: Int?
    /// Les semaines faites sont une archive : utile, mais pas ce qu'on ouvre l'écran pour voir.
    @State private var showPastWeeks = false
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

    private var pastWeeks: [WeekSummary] { weekSummaries.filter { $0.isDone } }
    private var currentWeek: WeekSummary? { weekSummaries.first { $0.isCurrent } }

    /// Les semaines à venir, groupées par phase et dans l'ordre. Un `Dictionary` perdrait
    /// justement ce qui fait l'intérêt du groupe : Base vient avant Spécifique, qui vient avant
    /// Affûtage, et une phase de récup peut revenir plusieurs fois au milieu.
    private var upcomingGroups: [(block: AdaptivePlanEngine.TrainingBlock, weeks: [WeekSummary])] {
        var groups: [(AdaptivePlanEngine.TrainingBlock, [WeekSummary])] = []
        for week in weekSummaries where !week.isDone && !week.isCurrent {
            if var last = groups.last, last.0 == week.block {
                last.1.append(week)
                groups[groups.count - 1] = last
            } else {
                groups.append((week.block, [week]))
            }
        }
        return groups.map { (block: $0.0, weeks: $0.1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                BackTitleHeaderView(eyebrow: String(localized: "Ton programme · \(profile.goalDisplay)"), title: "Le plan complet") {
                    appState.go(.home)
                }

                planShapeSection

                if let current = currentWeek {
                    VStack(alignment: .leading, spacing: 10) {
                        RUCardHeader(title: String(localized: "Cette semaine"))
                        currentWeekCard(current)
                    }
                }

                ForEach(Array(upcomingGroups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 10) {
                        RUCardHeader(title: groupTitle(group.block, weeks: group.weeks))
                        VStack(spacing: 8) {
                            ForEach(group.weeks) { week in
                                collapsibleWeekCard(week)
                            }
                        }
                    }
                }

                if !pastWeeks.isEmpty {
                    pastWeeksSection
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

    /// La forme du programme : la phrase d'explication et, quand il y a une date de course, la
    /// barre de phases. La phrase est courte — l'écran doit s'ouvrir sur le plan, pas sur un
    /// paragraphe.
    @ViewBuilder private var planShapeSection: some View {
        if let total = shape.totalWeeks {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(total) semaines en 3 phases, calées sur ta date de course. Le plan s'ajuste chaque semaine selon ta forme — pas séance par séance.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)
                PhaseProgressBar(phases: [
                    PhaseSegment(name: "Base", done: min(profile.weekNumber, shape.baseWeeks), total: shape.baseWeeks, color: RUColor.rose),
                    PhaseSegment(name: "Spécifique", done: max(0, min(profile.weekNumber - shape.baseWeeks, shape.specificWeeks)), total: shape.specificWeeks, color: RUColor.rose2),
                    PhaseSegment(name: "Affûtage", done: max(0, min(profile.weekNumber - shape.baseWeeks - shape.specificWeeks, shape.taperWeeks)), total: shape.taperWeeks, color: RUColor.violet)
                ])
            }
        } else {
            Text("Programme ouvert, sans date de fin — une semaine plus légère toutes les 4 semaines. Il s'ajuste chaque semaine selon ta forme.")
                .font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)
        }
    }

    /// « Spécifique · semaines 11 à 13 ». Le numéro n'a plus à être répété sur chaque ligne du
    /// groupe, et une phase d'une seule semaine ne dit pas « 14 à 14 ».
    private func groupTitle(_ block: AdaptivePlanEngine.TrainingBlock, weeks: [WeekSummary]) -> String {
        guard let first = weeks.first, let last = weeks.last else { return block.label }
        return first.number == last.number
            ? String(localized: "\(block.label) · semaine \(first.number)")
            : String(localized: "\(block.label) · semaines \(first.number) à \(last.number)")
    }

    /// La semaine en cours. Pas de bouton, pas de chevron, pas d'état déplié : elle est ouverte,
    /// parce que c'est elle qu'on vient voir. Le liseré rose et l'en-tête teinté qui la
    /// distinguaient d'un mur de cartes identiques ne servent plus à rien maintenant qu'elle est
    /// seule sous son propre intertitre — sa place dans la page suffit à dire ce qu'elle est.
    private func currentWeekCard(_ week: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("Semaine \(week.number)")
                        .font(RUFont.sans(17, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                    blockPill(week.block)
                    Spacer(minLength: 8)
                }
                Text("~\(week.estimatedKm) km · \(completedCount)/\(plannedCount) séances faites")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
            }

            VStack(spacing: 4) {
                ForEach(dayList(for: week), id: \.0) { letter, day, state in
                    dayRow(letter: letter, day: day, state: state)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    /// Une semaine à venir : une ligne, dépliable. Le nom de la phase vit dans l'intertitre du
    /// groupe, donc la ligne n'a plus à le porter — il ne reste que ce qui distingue vraiment une
    /// semaine de sa voisine, son numéro et son volume.
    private func collapsibleWeekCard(_ week: WeekSummary) -> some View {
        let isExpanded = expandedWeek == week.number
        return VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) { expandedWeek = isExpanded ? nil : week.number }
            }) {
                HStack(spacing: 12) {
                    Text("\(week.number)")
                        .font(RUFont.sans(13, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                        .frame(width: 32, height: 32)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("Semaine \(week.number)")
                        .font(RUFont.sans(13.5, weight: .semibold))
                        .foregroundColor(RUColor.textPrimary)
                    Spacer(minLength: 8)
                    Text("~\(week.estimatedKm) km")
                        .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RUColor.text3)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .accessibilityLabel(isExpanded ? String(localized: "Réduire") : String(localized: "Développer"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)

            if isExpanded {
                VStack(spacing: 4) {
                    Text(week.isDone
                         ? "Résumé type de cette semaine passée"
                         : "Aperçu — s'ajustera selon ta forme de la semaine précédente")
                        .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4).padding(.bottom, 2)
                    ForEach(dayList(for: week), id: \.0) { letter, day, state in
                        dayRow(letter: letter, day: day, state: state)
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 12)
            }
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    /// Les semaines faites, derrière un seul dépliant. Elles restent consultables — c'est le
    /// journal du programme — mais elles ne s'interposent plus entre l'ouverture de l'écran et la
    /// semaine en cours.
    private var pastWeeksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { withAnimation(.easeOut(duration: 0.2)) { showPastWeeks.toggle() } }) {
                RUCardHeader(title: pastWeeks.count > 1
                             ? String(localized: "\(pastWeeks.count) semaines faites")
                             : String(localized: "1 semaine faite")) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RUColor.text3)
                        .rotationEffect(.degrees(showPastWeeks ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(showPastWeeks ? String(localized: "Masquer les semaines faites")
                                              : String(localized: "Afficher les semaines faites"))

            if showPastWeeks {
                VStack(spacing: 8) {
                    ForEach(pastWeeks) { week in
                        collapsibleWeekCard(week).opacity(0.7)
                    }
                }
            }
        }
    }

    /// La phase, en pastille. Elle ne figure que sur la semaine en cours : ailleurs, c'est
    /// l'intertitre du groupe qui la porte.
    private func blockPill(_ block: AdaptivePlanEngine.TrainingBlock) -> some View {
        Text(block.label)
            .font(RUFont.sans(10, weight: .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundColor(RUColor.rose)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RUColor.rose.opacity(0.10), in: Capsule())
    }

    private var completedCount: Int { profile.weekSessions.filter(\.completed).count }
    private var plannedCount: Int { profile.weekSessions.filter { ($0.session?.durationMinutes ?? 0) > 0 }.count }

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
            Text(letter).font(RUFont.sans(11, weight: .semibold)).foregroundColor(RUColor.text3).frame(width: 30, alignment: .leading)
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
        .padding(.vertical, 12).padding(.horizontal, 10)
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 30, height: 30)
            .background(isToday ? RUColor.rose.opacity(0.12) : RUColor.bg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
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
