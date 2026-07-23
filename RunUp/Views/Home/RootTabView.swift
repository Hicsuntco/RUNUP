import SwiftUI

/// Root screen switcher + floating tab bar. Mirrors the `SCREENS` map and tab-bar visibility
/// logic in app.jsx (`showBar = !['live','recap'].includes(screen)`).
struct RootTabView: View {
    @Environment(AppState.self) private var appState

    private var showBar: Bool {
        appState.screen != .live && appState.screen != .recap
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RUColor.bg.ignoresSafeArea()

            currentScreen
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .id(appState.screen)

            if showBar && appState.isRunActive {
                RunInProgressPill(elapsed: appState.liveRun.map { PaceModel.formatDuration($0.elapsedSeconds) } ?? "0:00") {
                    appState.go(.live)
                }
                .padding(.bottom, RUSpacing.tabBarBottomInset + RUSpacing.tabBarHeight + 14)
            }

            if showBar {
                TabBarView(
                    selected: appState.screen,
                    onSelect: { appState.go($0) },
                    onStartRun: {
                        if appState.isRunActive { appState.go(.live) } else { appState.startRun() }
                    }
                )
                .padding(.horizontal, RUSpacing.tabBarSideInset)
                .padding(.bottom, RUSpacing.tabBarBottomInset)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.screen)
        .sheet(isPresented: Binding(get: { appState.sessionDetailPresented }, set: { appState.sessionDetailPresented = $0 })) {
            SessionDetailSheet()
                .runUpSheetStyle()
        }
        .sheet(isPresented: Binding(get: { appState.programSettingsPresented }, set: { appState.programSettingsPresented = $0 })) {
            ProgramSettingsSheet()
                .runUpSheetStyle()
        }
        .sheet(isPresented: Binding(get: { appState.notificationsPresented }, set: { appState.notificationsPresented = $0 })) {
            NotificationsSheet()
                .runUpSheetStyle()
        }
        // Tapping the weekly-recap local notification lands here rather than wherever the app
        // happened to be left open — `NotificationService` can't reach `AppState` directly (it's a
        // plain singleton with no app-state reference), so it posts this instead.
        .onReceive(NotificationCenter.default.publisher(for: .runUpOpenWeeklyRecap)) { _ in
            appState.go(.weeklyRecap)
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch appState.screen {
        case .home: HomeView()
        case .plan: PlanView()
        case .rings: RingsView()
        case .readiness: ReadinessView()
        case .live: LiveRunView()
        case .recap: RecapView()
        case .coach: CoachView()
        case .stats: StatsView()
        case .club: ClubView()
        case .race: RaceGoalView()
        case .profile: ProfileView()
        case .history: HistoryView()
        case .weeklyRecap: WeeklyRecapView()
        }
    }
}
