import SwiftUI
import SwiftData

/// "Programme" home screen — mirrors `ProgScreen` in screensA.jsx.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \AppNotification.timestamp, order: .reverse) private var notifications: [AppNotification]

    private var profile: UserProfile { appState.profile }
    private var isFreeRun: Bool { profile.programPhase == .freerun }
    private var unreadCount: Int { notifications.filter { !$0.read }.count }

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
                    eyebrow: isFreeRun ? "Mode course libre" : "Semaine \(profile.weekNumber)",
                    title: "Salut \(profile.name)"
                ) {
                    HStack(spacing: 8) {
                        Button(action: { appState.openNotifications() }) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(RUColor.card)
                                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                                    .frame(width: 36, height: 36)
                                    .overlay(Image(systemName: "bell").font(.system(size: 15)).foregroundColor(.white))
                                if unreadCount > 0 {
                                    Circle().fill(RUColor.rose).frame(width: 8, height: 8)
                                        .overlay(Circle().stroke(RUColor.bg, lineWidth: 1.5))
                                }
                            }
                        }
                        .buttonStyle(PressableStyle())
                        AvatarButton(initial: String(profile.name.prefix(1))) { appState.go(.profile) }
                    }
                }

                Button(action: { appState.replayOnboarding() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 11))
                        Text("Revoir l'intro").font(RUFont.sans(10.5, weight: .semibold))
                    }
                    .foregroundColor(RUColor.text3)
                }
                .buttonStyle(PressableStyle())

                weekStrip

                readinessCard

                sessionCard

                ringsCard

                if isFreeRun {
                    Text("Pas de plan fixe — le coach te propose de quoi garder la forme, jour après jour.")
                        .font(RUFont.sans(11))
                        .foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                } else {
                    planTeaserCard
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
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
                .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: RUSpacing.hairline))
            }
        }
    }

    private var readinessMessage: String {
        switch profile.readiness {
        case 85...: return "Bien récupérée → séance relevée d'un palier aujourd'hui."
        case 65..<85: return "Forme correcte → séance du jour comme prévu."
        case 50..<65: return "Un peu de fatigue → écoute-toi sur l'intensité aujourd'hui."
        default: return "Fatigue accumulée → pense à une séance plus légère ou à du repos."
        }
    }

    private var readinessCard: some View {
        Button(action: { appState.go(.readiness) }) {
            HStack(spacing: 14) {
                RingView(pct: Double(profile.readiness), color: RUColor.lime, size: 64) {
                    Text("\(profile.readiness)").displayStyle(20).foregroundColor(RUColor.lime)
                }
                VStack(alignment: .leading, spacing: 5) {
                    EyebrowLabel(text: "Forme du jour · \(profile.readinessLabel)")
                    Text(readinessMessage)
                        .font(RUFont.sans(12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruHeroCard(radius: 20)
    }

    private var sessionCard: some View {
        let session = profile.todaySession
        let isRestDay = session.durationMinutes == 0
        return Button(action: { appState.openSessionDetail() }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    EyebrowLabel(text: isRestDay ? "Aujourd'hui" : "Séance clé", color: RUColor.rose)
                    Spacer()
                    if let adj = session.adjustment {
                        StatChip(text: adj, color: RUColor.rose2)
                    }
                }
                Text(session.title).displayStyle(23).foregroundColor(.white).padding(.top, 6)
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
        }
        .buttonStyle(PressableStyle())
        .ruCard()
        .sheet(isPresented: Binding(get: { appState.manualDebriefPresented }, set: { appState.manualDebriefPresented = $0 })) {
            if let run = appState.lastRun {
                DebriefSheet(run: run).runUpSheetStyle()
            }
        }
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
                    EyebrowLabel(text: "Tes objectifs · \(p.dailyGoalsDone)/3 bouclés")
                    HStack(spacing: 14) {
                        ringStat(value: p.seanceDoneToday ? "Faite" : "À faire", unit: "séance", color: goalColors[0])
                        ringStat(value: "\(Int(p.strengthMinutesToday))", unit: "/\(Int(p.strengthGoalMinutes)) MIN", color: goalColors[1])
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

    private func ringStat(value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).displayStyle(16).foregroundColor(color)
            Text(unit).font(RUFont.sans(8)).foregroundColor(RUColor.text2)
        }
    }

    private var planShape: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
    }

    private var planTeaserCard: some View {
        let shape = planShape
        let block = AdaptivePlanEngine.trainingBlock(forWeek: profile.weekNumber, shape: shape)
        return Button(action: { appState.go(.plan) }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    EyebrowLabel(text: "Objectif · \(profile.goalDisplay) · J-\(profile.daysUntilRace ?? 0)", color: RUColor.rose)
                    Spacer()
                    Text("→").foregroundColor(RUColor.rose2)
                }
                Text("Semaine \(profile.weekNumber) · Bloc \(block.rawValue)").displayStyle(17).foregroundColor(.white)
                if let total = shape.totalWeeks {
                    PhaseProgressBar(phases: [
                        PhaseSegment(name: "Base", done: min(profile.weekNumber, shape.baseWeeks), total: shape.baseWeeks, color: RUColor.rose),
                        PhaseSegment(name: "Spécifique", done: max(0, min(profile.weekNumber - shape.baseWeeks, shape.specificWeeks)), total: shape.specificWeeks, color: RUColor.rose2),
                        PhaseSegment(name: "Affûtage", done: max(0, min(profile.weekNumber - shape.baseWeeks - shape.specificWeeks, shape.taperWeeks)), total: shape.taperWeeks, color: RUColor.violet)
                    ], showLabels: false)
                    .padding(.top, 10)
                    Text("\(total) semaines · voir le plan complet").font(RUFont.sans(10)).foregroundColor(RUColor.text2).padding(.top, 7)
                } else {
                    Text("Programme ouvert · voir le plan complet").font(RUFont.sans(10)).foregroundColor(RUColor.text2).padding(.top, 7)
                }
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }
}
