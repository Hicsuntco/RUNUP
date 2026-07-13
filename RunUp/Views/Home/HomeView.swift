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

    private var weekStrip: some View {
        HStack(spacing: 5) {
            ForEach(profile.weekStrip) { day in
                let (bg, border, color, mark): (Color, Color, Color, String) = {
                    switch day.state {
                    case .done: return (RUColor.rose, RUColor.rose, .white, "✓")
                    case .today: return (RUColor.rose.opacity(0.12), RUColor.rose.opacity(0.5), RUColor.rose2, "")
                    case .rest: return (RUColor.card, RUColor.line, RUColor.text4, "·")
                    case .upcoming: return (RUColor.card, RUColor.line, RUColor.text2, "")
                    }
                }()
                VStack(spacing: 5) {
                    Text(day.letter).displayStyle(11).foregroundColor(color)
                    Text(mark).font(RUFont.sans(11)).foregroundColor(color)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: RUSpacing.hairline))
            }
        }
    }

    private var readinessCard: some View {
        Button(action: { appState.go(.rings) }) {
            HStack(spacing: 14) {
                RingView(pct: Double(profile.readiness), color: RUColor.lime, size: 64) {
                    Text("\(profile.readiness)").displayStyle(20).foregroundColor(RUColor.lime)
                }
                VStack(alignment: .leading, spacing: 5) {
                    EyebrowLabel(text: "Forme du jour · excellente")
                    Text("Bien récupérée → séance relevée d'un palier aujourd'hui.")
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
        return Button(action: { appState.openSessionDetail() }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    EyebrowLabel(text: "Séance clé", color: RUColor.rose)
                    Spacer()
                    if let adj = session.adjustment {
                        StatChip(text: adj, color: RUColor.rose2)
                    }
                }
                Text(session.title).displayStyle(23).foregroundColor(.white).padding(.top, 6)
                Text(session.subtitle).font(RUFont.sans(11)).foregroundColor(RUColor.text2).padding(.top, 4)
                HStack(spacing: 16) {
                    MetricColumn(value: "\(session.durationMinutes)′", label: "Durée")
                    MetricColumn(value: session.pace, label: "Allure")
                    MetricColumn(value: session.zone, label: "Zone", valueColor: RUColor.rose2)
                }
                .padding(.top, 14)

                Button(action: { appState.startRun() }) {
                    HStack { Image(systemName: "play.fill"); Text("DÉMARRER") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 15)
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    private var ringsCard: some View {
        let p = profile
        return Button(action: { appState.go(.rings) }) {
            HStack(spacing: 16) {
                Rings3View(vals: [p.moveValue / p.moveGoal * 100, p.activeValue / p.activeGoal * 100, p.runValue / p.runGoal * 100], size: 72, strokeWidth: 6, gap: 3) { EmptyView() }
                VStack(alignment: .leading, spacing: 8) {
                    EyebrowLabel(text: "Tes anneaux · \(p.ringsDone)/3 bouclés")
                    HStack(spacing: 14) {
                        ringStat(value: "\(Int(p.moveValue))", unit: "/\(Int(p.moveGoal)) KCAL", color: RUColor.rose)
                        ringStat(value: "\(Int(p.activeValue))", unit: "/\(Int(p.activeGoal)) MIN", color: RUColor.lime)
                        ringStat(value: String(format: "%.1f", p.runValue), unit: "/\(Int(p.runGoal)) KM", color: RUColor.cyan)
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

    private var planTeaserCard: some View {
        Button(action: { appState.go(.plan) }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    EyebrowLabel(text: "Objectif · \(profile.goalDisplay) · J-\(profile.daysUntilRace ?? 0)", color: RUColor.rose)
                    Spacer()
                    Text("→").foregroundColor(RUColor.rose2)
                }
                Text("Semaine \(profile.weekNumber) · Bloc VMA").displayStyle(17).foregroundColor(.white)
                PhaseProgressBar(phases: [
                    PhaseSegment(name: "Base", done: 3, total: 3, color: RUColor.rose),
                    PhaseSegment(name: "Spécifique", done: 1, total: 4, color: RUColor.rose2),
                    PhaseSegment(name: "Affûtage", done: 0, total: 2, color: RUColor.violet)
                ], showLabels: false)
                .padding(.top, 10)
                Text("9 semaines · voir le plan complet").font(RUFont.sans(10)).foregroundColor(RUColor.text2).padding(.top, 7)
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }
}
