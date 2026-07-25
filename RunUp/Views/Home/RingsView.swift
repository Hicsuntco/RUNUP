import SwiftUI
import SwiftData

/// Daily goals detail — mirrors `RingsScreen` in screensA.jsx, redefined around 3 distinct daily
/// behaviors (Séance du jour / Calories actives / Pas) instead of 3 measures of the same run.
/// Also a day BROWSER, not just today's snapshot: < > navigation re-queries Santé for steps/
/// calories on any past date (Santé keeps that data indefinitely — RunUp just never asked for a
/// day other than today before) and checks History for a run that day, so "Ta journée" reads
/// correctly for any date, not only the one you happened to open the app on.
struct RingsView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]
    @State private var celebrationShown = false
    @State private var selectedDate: Date = .now
    @State private var historicalSteps: Double = 0
    @State private var historicalCalories: Double = 0
    @State private var isLoadingHistoricalDay = false

    private var p: UserProfile { appState.profile }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private var remainingSteps: Int { max(0, Int(p.stepsGoal - p.stepsToday)) }
    private var remainingActiveCalories: Int { max(0, Int(p.activeCaloriesGoal - p.activeCaloriesToday)) }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private var dayLabel: String {
        isToday ? "Aujourd'hui" : Self.dayFormatter.string(from: selectedDate).capitalized
    }

    private var selectedWeekday: Int { (Calendar.current.component(.weekday, from: selectedDate) + 5) % 7 }

    /// Whether a real run exists on the selected date — the one honest way to say "séance faite"
    /// for a day that isn't today (`weekSessions.completed` only exists for the CURRENT week).
    private var hasRunOnSelectedDate: Bool {
        runs.contains { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    /// Today reads the live, already-tracked rest-day flag; any other date falls back to the
    /// stable weekly running-days pattern (see `UserProfile.isRunningDay`) since past weeks'
    /// exact plan isn't retained.
    private var isRunningDayForSelected: Bool {
        isToday ? !p.isRestDayToday : p.isRunningDay(weekday: selectedWeekday)
    }

    private var displaySteps: Double { isToday ? p.stepsToday : historicalSteps }
    private var displayCalories: Double { isToday ? p.activeCaloriesToday : historicalCalories }

    private var displayProgress: [Double] {
        if isToday { return p.dailyGoalsProgress }
        return UserProfile.dailyGoalsProgress(
            sessionDone: isRunningDayForSelected ? hasRunOnSelectedDate : nil,
            steps: displaySteps, stepsGoal: p.stepsGoal,
            activeCalories: displayCalories, activeCaloriesGoal: p.activeCaloriesGoal
        )
    }
    private var displayDone: Int { displayProgress.filter { $0 >= 1 }.count }
    private var displayTotal: Int { isRunningDayForSelected ? 3 : 2 }

    /// [Séance, Calories actives, Pas] — same array `DailyGoalsBarsView` draws its bars in, so
    /// each row's legend dot always matches its bar's actual color.
    private var goalColors: [Color] { DailyGoalsBarsView.fillColors }

    /// The most useful thing to nudge about right now — first incomplete goal, in priority order.
    /// Only ever shown for today — nudging her about an already-past day makes no sense.
    private var coachNudge: String? {
        if !p.seanceDoneToday, p.todaySession.durationMinutes > 0 {
            return "Ta séance du jour t'attend : \(p.todaySession.title) (\(p.todaySession.durationMinutes)′)."
        }
        if p.activeCaloriesToday < p.activeCaloriesGoal {
            return "Encore \(remainingActiveCalories) kcal actives pour boucler l'objectif du jour."
        }
        if p.stepsToday < p.stepsGoal {
            return "Encore \(remainingSteps) pas pour boucler ton objectif — une petite marche ?"
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.home) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: isToday ? "Aujourd'hui" : "Journée passée", color: RUColor.rose)
                        Text("Ta journée").displayStyle(22).foregroundColor(RUColor.textPrimary)
                    }
                }

                dayNavigator

                ZStack {
                    DailyGoalsBarsView(progress: displayProgress, size: 168, animateOnAppear: true)
                        .opacity(isLoadingHistoricalDay ? 0.4 : 1)
                    VStack(spacing: 2) {
                        Text("\(displayDone) / \(displayTotal)").displayStyle(28).foregroundColor(RUColor.textPrimary)
                        Text("BOUCLÉS").font(RUFont.sans(10, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
                    }
                    .opacity(isLoadingHistoricalDay ? 0.4 : 1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .animation(.easeOut(duration: 0.2), value: isLoadingHistoricalDay)

                VStack(spacing: 9) {
                    seanceRow
                    ringRow(name: "Calories actives", color: goalColors[1], value: displayCalories, goal: p.activeCaloriesGoal, unit: "kcal")
                    ringRow(name: "Pas", color: goalColors[2], value: displaySteps, goal: p.stepsGoal, unit: "pas")
                }

                if isToday {
                    if let coachNudge {
                        HStack(spacing: 12) {
                            AppMarkView(size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                EyebrowLabel(text: "Coach", color: RUColor.rose2)
                                Text(coachNudge).font(RUFont.sans(12.5)).foregroundColor(RUColor.textPrimary)
                            }
                        }
                        .padding(15)
                        .ruHeroCard(radius: 18)
                    } else {
                        // The one genuine celebration state on this screen (all 3 goals done) — a
                        // spring scale-in gives it the "achievement unlocked" beat the static text
                        // didn't have, matching the ring's own animate-on-appear fill above.
                        VStack(spacing: 6) {
                            Text("JOURNÉE BOUCLÉE").displayStyle(26).foregroundColor(RUColor.textPrimary)
                            Text("Tes \(p.dailyGoalsTotal) objectifs du jour atteints 👏 +120 XP").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(RadialGradient(colors: [RUColor.rose.opacity(0.2), .clear], center: .top, startRadius: 0, endRadius: 200), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .scaleEffect(celebrationShown ? 1 : 0.85)
                        .opacity(celebrationShown ? 1 : 0)
                        .onAppear {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { celebrationShown = true }
                        }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .task(id: selectedDate) { await loadHistoricalDayIfNeeded() }
    }

    private var dayNavigator: some View {
        HStack(spacing: 10) {
            Button(action: { changeDay(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(RUColor.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(RUColor.card, in: Circle())
                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            }
            .buttonStyle(PressableStyle())

            Text(dayLabel)
                .font(RUFont.sans(13, weight: .semibold))
                .foregroundColor(RUColor.textPrimary)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button(action: { changeDay(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isToday ? RUColor.text3 : RUColor.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(RUColor.card, in: Circle())
                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            }
            .buttonStyle(PressableStyle())
            .disabled(isToday)
        }
    }

    private func changeDay(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        guard newDate <= .now else { return }
        Haptics.selection()
        selectedDate = newDate
    }

    private func loadHistoricalDayIfNeeded() async {
        guard !isToday else { return }
        isLoadingHistoricalDay = true
        historicalSteps = 0
        historicalCalories = 0
        async let steps = appState.healthKit.steps(on: selectedDate)
        async let calories = appState.healthKit.activeCalories(on: selectedDate)
        let (s, c) = await (steps, calories)
        guard !Task.isCancelled else { return }
        historicalSteps = s
        historicalCalories = c
        isLoadingHistoricalDay = false
    }

    private var seanceRow: some View {
        let color = goalColors[0]
        let restDay = !isRunningDayForSelected
        let done = isRunningDayForSelected && hasRunOnSelectedDate
        return HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10).shadow(color: color.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Séance").font(RUFont.sans(16, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    Spacer()
                    Text(restDay ? "Repos" : (done ? "Faite ✓" : (isToday ? "À faire" : "Non faite")))
                        .font(RUFont.sans(11, weight: .bold))
                        .foregroundColor(restDay ? RUColor.text2 : (done ? RUColor.lime : RUColor.text2))
                }
                LinearBar(fraction: displayProgress[0], color: restDay ? RUColor.text3 : color, height: 5)
            }
        }
        .padding(14)
        .ruCard()
    }

    private func ringRow(name: String, color: Color, value: Double, goal: Double, unit: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10).shadow(color: color.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(name).font(RUFont.sans(16, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    Spacer()
                    (Text(formattedValue(value)).font(RUFont.sans(11, weight: .bold)).foregroundColor(color)
                        + Text(" / \(formattedValue(goal)) \(unit)").font(RUFont.mono(11)).foregroundColor(RUColor.text2))
                }
                LinearBar(fraction: goal == 0 ? 0 : value / goal, color: color, height: 5)
            }
        }
        .padding(14)
        .ruCard()
    }

    private func formattedValue(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", locale: Locale(identifier: "fr_FR"), v)
    }
}
