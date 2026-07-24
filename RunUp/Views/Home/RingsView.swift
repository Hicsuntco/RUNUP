import SwiftUI

/// Daily goals detail — mirrors `RingsScreen` in screensA.jsx, redefined around 3 distinct daily
/// behaviors (Séance du jour / Calories actives / Pas) instead of 3 measures of the same run.
struct RingsView: View {
    @Environment(AppState.self) private var appState
    @State private var celebrationShown = false
    private var p: UserProfile { appState.profile }

    private var remainingSteps: Int { max(0, Int(p.stepsGoal - p.stepsToday)) }
    private var remainingActiveCalories: Int { max(0, Int(p.activeCaloriesGoal - p.activeCaloriesToday)) }

    private static var todayLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().locale(Locale(identifier: "fr_FR")))
    }

    /// [Séance, Calories actives, Pas] — same array `DailyGoalsBarsView` draws its bars in, so
    /// each row's legend dot always matches its bar's actual color.
    private var goalColors: [Color] { DailyGoalsBarsView.fillColors }

    /// The most useful thing to nudge about right now — first incomplete goal, in priority order.
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
                        EyebrowLabel(text: "Aujourd'hui · \(Self.todayLabel)", color: RUColor.rose)
                        Text("Ta journée").displayStyle(22).foregroundColor(RUColor.textPrimary)
                    }
                }

                ZStack {
                    DailyGoalsBarsView(progress: p.dailyGoalsProgress, size: 168, animateOnAppear: true)
                    VStack(spacing: 2) {
                        Text("\(p.dailyGoalsDone) / \(p.dailyGoalsTotal)").displayStyle(28).foregroundColor(RUColor.textPrimary)
                        Text("BOUCLÉS").font(RUFont.sans(10, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                VStack(spacing: 9) {
                    seanceRow
                    ringRow(name: "Calories actives", color: goalColors[1], value: p.activeCaloriesToday, goal: p.activeCaloriesGoal, unit: "kcal")
                    ringRow(name: "Pas", color: goalColors[2], value: p.stepsToday, goal: p.stepsGoal, unit: "pas")
                }

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
                        Text("Les 3 objectifs atteints 👏 +120 XP").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
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
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private var seanceRow: some View {
        let color = goalColors[0]
        return HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10).shadow(color: color.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Séance du jour").font(RUFont.sans(16, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    Spacer()
                    Text(p.isRestDayToday ? "Repos" : (p.seanceDoneToday ? "Faite ✓" : "À faire"))
                        .font(RUFont.sans(11, weight: .bold))
                        .foregroundColor(p.isRestDayToday ? RUColor.text2 : (p.seanceDoneToday ? RUColor.lime : RUColor.text2))
                }
                LinearBar(fraction: p.dailyGoalsProgress[0], color: p.isRestDayToday ? RUColor.text3 : color, height: 5)
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
