import SwiftUI
import SwiftData

/// "Programme" home screen — mirrors `ProgScreen` in screensA.jsx.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    // Scoped to unread only — this query exists solely to badge the bell icon with a count, but
    // an unscoped `@Query` fetched every notification ever created (unbounded, grows for the
    // app's whole lifetime) just to filter it back down to unread right after. NotificationsSheet
    // has its own separate `@Query` for the full list it actually displays.
    @Query(filter: #Predicate<AppNotification> { !$0.read }) private var unreadNotifications: [AppNotification]
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]

    private var profile: UserProfile { appState.profile }
    private var isFreeRun: Bool { profile.programPhase == .freerun }
    private var unreadCount: Int { unreadNotifications.count }

    var body: some View {
        Group {
            switch profile.programPhase {
            case .recovery: RecoveryView()
            case .choice: ChoiceView()
            default: mainContent
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HeaderView(
                    eyebrow: isFreeRun ? "Mode course libre" : weekEyebrow,
                    title: "Salut \(profile.name)"
                ) {
                    HStack(spacing: 8) {
                        streakChip
                        Button(action: { appState.openNotifications() }) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(RUColor.card)
                                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                                    .frame(width: 36, height: 36)
                                    .overlay(Image(systemName: "bell").font(.system(size: 15)).foregroundColor(RUColor.textPrimary))
                                if unreadCount > 0 {
                                    Circle().fill(RUColor.rose).frame(width: 8, height: 8)
                                        .overlay(Circle().stroke(RUColor.bg, lineWidth: 1.5))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(unreadCount > 0 ? "Notifications, \(unreadCount) non lues" : "Notifications")
                        AvatarButton(initial: String(profile.name.prefix(1)), imageData: profile.avatarImageData) { appState.go(.profile) }
                    }
                }

                // Opens the same "nouvel objectif" wizard as Profil/Plus de réglages and
                // ChoiceView's end-of-program screen — only replaces goal/distance/allure/jours,
                // nothing about her (nom, blessures, cycle...). No confirmation needed here: a
                // new program restarting at semaine 1 is the expected, obvious outcome of asking
                // for a new program, unlike the old "Refaire l'onboarding" which silently re-asked
                // everything just to change the plan.
                Button(action: { appState.newGoalWizardPresented = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 11))
                        Text("Refaire un programme").font(RUFont.sans(10.5, weight: .semibold))
                    }
                    .foregroundColor(RUColor.text3)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())

                programWeekCard

                ringsCard

                sessionCard

                weeklyDistanceCard

                if isFreeRun {
                    Text("Pas de plan fixe — le coach te propose de quoi garder la forme, jour après jour.")
                        .font(RUFont.sans(11))
                        .foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    /// The week strip and the program teaser, merged into ONE card (owner's call — they're two
    /// halves of the same information, "où j'en suis cette semaine / dans le programme", and
    /// lived at opposite ends of the screen). Tapping anywhere opens the full plan. In course
    /// libre there's no program to tease, so the card is just the days, not tappable.
    private var programWeekCard: some View {
        let shape = planShape
        let block = AdaptivePlanEngine.trainingBlock(forWeek: profile.weekNumber, shape: shape)
        return Button(action: { appState.go(.plan) }) {
            VStack(alignment: .leading, spacing: 12) {
                // Combined separately from `weekStrip` below — that already exposes one element
                // per day (see `dayAccessibilityLabel`); flattening it into this same combine would
                // undo that per-day granularity instead of adding to it.
                Group {
                    if !isFreeRun {
                        HStack {
                            EyebrowLabel(text: profile.daysUntilRace.map { "Objectif · \(profile.goalDisplay) · J-\($0)" } ?? "Objectif · \(profile.goalDisplay)", color: RUColor.rose)
                            Spacer()
                            Text("→").foregroundColor(RUColor.rose2)
                        }
                        Text("Semaine \(profile.weekNumber) · Bloc \(block.rawValue)").displayStyle(17).foregroundColor(RUColor.textPrimary)
                    }
                }
                .accessibilityElement(children: .combine)
                weekStrip
                if !isFreeRun {
                    if let total = shape.totalWeeks {
                        PhaseProgressBar(phases: [
                            PhaseSegment(name: "Base", done: min(profile.weekNumber, shape.baseWeeks), total: shape.baseWeeks, color: RUColor.rose),
                            PhaseSegment(name: "Spécifique", done: max(0, min(profile.weekNumber - shape.baseWeeks, shape.specificWeeks)), total: shape.specificWeeks, color: RUColor.rose2),
                            PhaseSegment(name: "Affûtage", done: max(0, min(profile.weekNumber - shape.baseWeeks - shape.specificWeeks, shape.taperWeeks)), total: shape.taperWeeks, color: RUColor.violet)
                        ], showLabels: false)
                        Text("\(total) semaines · voir le plan complet").font(RUFont.sans(10)).foregroundColor(RUColor.text2)
                    } else {
                        Text("Programme ouvert · voir le plan complet").font(RUFont.sans(10)).foregroundColor(RUColor.text2)
                    }
                }
            }
            .padding(14)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
        .disabled(isFreeRun)
    }

    /// Shows the real date number (today circled), not just the bare weekday letter — so it's
    /// unambiguous which real calendar day each cell is, instead of an abstract L/M/M/J/V/S/D
    /// that says nothing about "today" until you count.
    private var weekStrip: some View {
        HStack(spacing: 5) {
            ForEach(profile.weekStrip) { day in
                let (bg, border, color): (Color, Color, Color) = {
                    switch day.state {
                    case .done: return (RUColor.rose, RUColor.rose, .white)
                    case .today: return (RUColor.rose.opacity(0.12), RUColor.rose.opacity(0.5), RUColor.rose2)
                    case .rest: return (RUColor.card, RUColor.line, RUColor.text4)
                    case .upcoming: return (RUColor.card, RUColor.line, RUColor.text2)
                    }
                }()
                VStack(spacing: 5) {
                    Text(day.letter).displayStyle(11).foregroundColor(color)
                    ZStack {
                        if day.state == .today {
                            Circle().stroke(RUColor.rose2, lineWidth: 1.5).frame(width: 19, height: 19)
                        }
                        if day.state == .done {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(color)
                        } else {
                            Text("\(Calendar.current.component(.day, from: day.date))")
                                .font(RUFont.sans(11, weight: day.state == .today ? .bold : .regular))
                                .foregroundColor(color)
                        }
                    }
                    .frame(width: 19, height: 19)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                // Each cell (weekday letter + a date number or checkmark, colored by state) was
                // 2-3 separate disconnected VoiceOver stops with no indication of which day is
                // today, done, or a rest day — that information lived only in color/border, never
                // announced.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(dayAccessibilityLabel(day))
                .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: RUSpacing.hairline))
            }
        }
    }

    private func dayAccessibilityLabel(_ day: DayStatus) -> String {
        let dayNumber = Calendar.current.component(.day, from: day.date)
        let name = "\(DayStatus.fullNames[day.weekday]) \(dayNumber)"
        switch day.state {
        case .today: return "\(name), aujourd'hui"
        case .done: return "\(name), séance faite"
        case .rest: return "\(name), repos"
        case .upcoming: return "\(name), à venir"
        }
    }

    /// Was one big `Button` wrapping the FAIT/DÉMARRER buttons INSIDE it — nested SwiftUI buttons
    /// have unreliable hit-testing (the outer button can swallow or fight taps meant for the
    /// inner ones), which is almost certainly why the FAIT/DÉMARRER row felt inconsistent to tap.
    /// A plain `VStack` with `.onTapGesture` for "open the detail sheet" opens exactly the same
    /// way, but SwiftUI correctly gives priority to the real `Button`s nested inside a tap-gesture
    /// container (unlike inside an actual `Button`), so FAIT/DÉMARRER get their own reliable taps.
    private var sessionCard: some View {
        let session = profile.todaySession
        let isRestDay = session.durationMinutes == 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                EyebrowLabel(text: isRestDay ? "Aujourd'hui" : "Séance clé", color: RUColor.rose)
                Spacer()
                if let adj = session.adjustment {
                    StatChip(text: adj, color: RUColor.rose2)
                }
            }
            Text(session.title).displayStyle(23).foregroundColor(RUColor.textPrimary).padding(.top, 6)
            Text(session.subtitle).font(RUFont.sans(11)).foregroundColor(RUColor.text2).padding(.top, 4)

            if isRestDay {
                Text("Pas de séance prévue — profite-en pour récupérer.")
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text3)
                    .padding(.top, 14)
            } else if profile.seanceDoneToday {
                Text("Séance faite aujourd'hui ✓")
                    .font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.lime)
                    .padding(.top, 14)
            } else {
                HStack(spacing: 16) {
                    MetricColumn(value: "\(session.durationMinutes)′", label: "Durée")
                    MetricColumn(value: session.pace, label: "Allure")
                    MetricColumn(value: session.zone, label: "Zone", valueColor: RUColor.rose2)
                }
                .padding(.top, 14)

                HStack(spacing: 8) {
                    // For a strength session, a treadmill run, or just forgetting to hit
                    // record — logging it shouldn't require the full GPS flow.
                    Button(action: { appState.markTodaySessionDone() }) {
                        HStack { Image(systemName: "checkmark"); Text("FAIT") }
                            // Matches DÉMARRER's PrimaryButtonStyle typography (bebas display
                            // font) so the two read as one paired control, not two mismatched
                            // buttons — the outline vs. filled chrome from SecondaryButtonStyle
                            // is what should carry the "lower emphasis" signal, not the font.
                            .font(RUFont.bebas(16))
                            .tracking(1)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: { appState.startRun() }) {
                        HStack { Image(systemName: "play.fill"); Text("DÉMARRER") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.top, 15)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture { appState.openSessionDetail() }
        .ruCard()
        // The manual-debrief sheet presents from RootTabView now — anchored here it could only
        // ever appear while this specific card was mounted on screen.
    }

    /// Replaces the old "forme du jour" readiness ring — that score barely moved week to week and
    /// wasn't tied to anything she could act on. Total km run this week, compared against last
    /// week, is the number every runner already watches and tries to beat — real, concrete, and
    /// it visibly changes after every run instead of drifting inside a narrow band.
    private func weeklyKm(weeksAgo: Int) -> Double {
        let cal = Calendar.current
        let thisWeekStart = AdaptivePlanEngine.currentWeekRange().lowerBound
        guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeekStart) else { return 0 }
        let range = AdaptivePlanEngine.currentWeekRange(from: weekStart)
        return runs.filter { range.contains($0.date) }.reduce(0) { $0 + $1.distanceKm }
    }

    private var weeklyDistanceCard: some View {
        let thisWeek = weeklyKm(weeksAgo: 0)
        let lastWeek = weeklyKm(weeksAgo: 1)
        let delta = thisWeek - lastWeek
        return Button(action: { appState.go(.stats) }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    EyebrowLabel(text: "Cette semaine", color: RUColor.cyan)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", locale: Locale(identifier: "fr_FR"), thisWeek)).displayStyle(26).foregroundColor(RUColor.textPrimary)
                        Text("km").font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.text2)
                    }
                    Text(weeklyComparisonText(delta: delta, lastWeek: lastWeek))
                        .font(RUFont.sans(12))
                        .foregroundColor(weeklyComparisonColor(delta: delta, lastWeek: lastWeek))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(RUColor.text3)
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    private func weeklyComparisonText(delta: Double, lastWeek: Double) -> String {
        guard lastWeek > 0 else {
            return "Semaine dernière : pas de course enregistrée."
        }
        let deltaText = String(format: "%.1f", locale: Locale(identifier: "fr_FR"), abs(delta))
        if delta > 0.05 { return "+\(deltaText) km vs la semaine dernière" }
        if delta < -0.05 { return "-\(deltaText) km vs la semaine dernière" }
        return "Comme la semaine dernière"
    }

    private func weeklyComparisonColor(delta: Double, lastWeek: Double) -> Color {
        guard lastWeek > 0, delta > 0.05 else { return RUColor.text2 }
        return RUColor.lime
    }

    private var ringsCard: some View {
        let p = profile
        // Same array `DailyGoalsBarsView` draws its bars in, so each stat's color always matches
        // its bar's actual color.
        let goalColors = DailyGoalsBarsView.fillColors
        return Button(action: { appState.go(.rings) }) {
            HStack(spacing: 16) {
                DailyGoalsBarsView(progress: p.dailyGoalsProgress, size: 72)
                VStack(alignment: .leading, spacing: 8) {
                    EyebrowLabel(text: "Tes objectifs · \(p.dailyGoalsDone)/\(p.dailyGoalsTotal) bouclés")
                    HStack(spacing: 14) {
                        ringStat(value: p.isRestDayToday ? "Repos" : (p.seanceDoneToday ? "Faite" : "À faire"), unit: "séance", color: goalColors[0])
                        ringStat(value: "\(Int(p.activeCaloriesToday))", unit: "/\(Int(p.activeCaloriesGoal)) KCAL", color: goalColors[1])
                        ringStat(value: "\(Int(p.stepsToday))", unit: "/\(Int(p.stepsGoal)) PAS", color: goalColors[2])
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    /// `profile.streak` was already tracked (`AdaptivePlanEngine.applyDebrief`) and shown deep in
    /// Stats/Readiness/Club, but never on Home — the screen actually opened every day, where a
    /// visible streak does the most to make her not want to break it.
    private var streakChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").font(.system(size: 12))
            Text("\(profile.streak)").font(RUFont.sans(13, weight: .bold))
        }
        .foregroundColor(profile.streak > 0 ? RUColor.amber : RUColor.text3)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RUColor.card, in: Capsule())
        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        // Was just "5" to VoiceOver with no context — the flame icon that gives it meaning
        // visually carries no information for someone who can't see it.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Série, \(profile.streak) jour\(profile.streak > 1 ? "s" : "")")
    }

    private func ringStat(value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).displayStyle(16).foregroundColor(color)
            Text(unit).font(RUFont.sans(8)).foregroundColor(RUColor.text2)
        }
        // Was two disconnected stops ("45" then, later, "/60 KCAL") — combined so a value and its
        // unit/goal read as one thing.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value), \(unit)")
    }

    /// "Semaine 4/9" when the program has a real end (a race goal periodizes toward one), else
    /// just "Semaine 4" — matches the mockup's "SEM. 4/9" without claiming a total for the
    /// open-ended goals (progress/weight/restart/health) that genuinely don't have one.
    private var weekEyebrow: String {
        if let total = planShape.totalWeeks {
            return "Semaine \(profile.weekNumber)/\(total)"
        }
        return "Semaine \(profile.weekNumber)"
    }

    private var planShape: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
    }

}
