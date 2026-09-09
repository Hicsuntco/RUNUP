import SwiftUI
import UIKit

/// Root screen switcher + floating tab bar. Mirrors the `SCREENS` map and tab-bar visibility
/// logic in app.jsx (`showBar = !['live','recap'].includes(screen)`).
struct RootTabView: View {
    @Environment(AppState.self) private var appState

    private var showBar: Bool {
        appState.screen != .live && appState.screen != .recap
    }

    /// Quel onglet la barre affiche comme actif — ce n'est pas toujours l'écran courant. Depuis
    /// que Profil est le 5e onglet, Club et Amis (`SocialView`) sont des destinations SOUS le
    /// Profil, ouvertes par ses deux cartes. Sans cette translation, entrer dans son club
    /// éteignait la barre entière : cinq onglets dont aucun sélectionné, alors qu'on est bien
    /// quelque part.
    private var tabSelection: AppScreen {
        appState.screen == .club ? .profile : appState.screen
    }

    /// Les écrans qui reçoivent du texte À MÊME LA PAGE.
    ///
    /// PARTOUT AILLEURS, UN ENCART DE CLAVIER N'A AUCUN SENS. Il n'y a rien à y taper : s'il en
    /// arrive un, c'est un reste — le clavier d'un écran qu'on vient de quitter, ou d'une feuille
    /// système qu'on vient de refermer. Et il ne se voit pas comme un clavier, il se voit comme
    /// une page cassée : trois cents points de vide en bas, la barre d'onglets échouée au milieu
    /// de l'écran, et la carte du programme coupée en deux dessous.
    ///
    /// Ces deux-là gardent le comportement d'origine — tout remonte avec le clavier, barre
    /// d'onglets comprise, et le champ reste au-dessus.
    ///
    /// LA LISTE SE LIT DANS `currentScreen`, et « à même la page » en est la moitié importante :
    /// une feuille est une hiérarchie séparée, que ce modificateur n'atteint pas. Les champs de
    /// `AddShoeSheet`, `LogSessionSheet`, `MoreSettingsView` ou `AddRunSheet` continuent donc de
    /// remonter tout seuls, et ces écrans-là ne sont pas dans la liste. Restent le Coach, et le
    /// social — `SocialView` affiche `ClubView` et `FriendsView` en place, tous deux avec un
    /// champ de recherche ou de code d'invitation.
    private var typesText: Bool { appState.screen == .coach || appState.screen == .club }

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
                    selected: tabSelection,
                    onSelect: { appState.go($0) },
                    onStartRun: {
                        if appState.isRunActive { appState.go(.live) } else { appState.startRun() }
                    }
                )
                .padding(.horizontal, RUSpacing.tabBarSideInset)
                .padding(.bottom, RUSpacing.tabBarBottomInset)
            }
        }
        // Un jeu de bords VIDE plutôt qu'un `if` autour du modificateur : la valeur change, pas
        // la structure de la vue. Un `if` en donnerait deux différentes, et SwiftUI recréerait
        // tout l'arbre — donc l'écran courant — à chaque passage sur le Coach.
        .ignoresSafeArea(.keyboard, edges: typesText ? [] : .bottom)
        .animation(.easeInOut(duration: 0.25), value: appState.screen)
        // Un seul point d'émission pour toute l'app : chaque écran passe par ce `switch`, donc
        // rien ne peut être oublié ni compté deux fois. `onChange` plutôt qu'un `onAppear` par
        // écran, qui se serait redéclenché à chaque retour de feuille modale.
        .onAppear { Analytics.shared.track(.screenViewed, ["screen": .string(appState.screen.rawValue)]) }
        .onChange(of: appState.screen) { _, screen in
            // LE CLAVIER NE SUIT PAS L'ÉCRAN QUI L'A OUVERT. En quittant le Coach pendant qu'on
            // écrit, la vue est détruite avec son champ encore actif — `currentScreen` porte un
            // `.id(appState.screen)`. iOS referme bien le clavier, mais l'encart de sécurité qui
            // l'accompagnait reste parfois posé sur la hiérarchie. Le refermer AVANT de changer
            // d'écran supprime le cas à la source ; le `ignoresSafeArea` ci-dessus n'est là que
            // pour qu'il ne puisse plus rien casser s'il revenait par un autre chemin.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
            Analytics.shared.track(.screenViewed, ["screen": .string(screen.rawValue)])
        }
        .sheet(isPresented: Binding(get: { appState.sessionDetailPresented }, set: { appState.sessionDetailPresented = $0 })) {
            SessionDetailSheet()
                .runUpSheetStyle()
        }
        .sheet(isPresented: Binding(get: { appState.moveSessionPresented }, set: { appState.moveSessionPresented = $0 })) {
            MoveSessionSheet()
                .runUpSheetStyle()
        }
        .sheet(isPresented: Binding(get: { appState.logSessionPresented }, set: { appState.logSessionPresented = $0 })) {
            LogSessionSheet()
                .runUpSheetStyle(detents: [.medium])
        }
        .sheet(isPresented: Binding(get: { appState.programSettingsPresented }, set: { appState.programSettingsPresented = $0 })) {
            ProgramSettingsSheet()
                .runUpSheetStyle()
        }
        .sheet(isPresented: Binding(get: { appState.notificationsPresented }, set: { appState.notificationsPresented = $0 })) {
            NotificationsSheet()
                .runUpSheetStyle()
        }
        // Presented from the ROOT, same reasoning as the debrief sheet above — "Refaire un
        // programme" is reachable from Profil's "Plus de réglages" sheet, so this must be able to
        // open on top of it, not nested one level inside where dismissing would fight it.
        .fullScreenCover(isPresented: Binding(get: { appState.newGoalWizardPresented }, set: { appState.newGoalWizardPresented = $0 })) {
            NewGoalWizardView()
        }
        // Presented from the ROOT, not HomeView's session card — a debrief can be triggered while
        // she's on any tab (a run arriving from the Apple Watch, "Marquer comme faite" flows),
        // and a sheet anchored inside a view that isn't currently mounted simply never appears
        // (the RPE, streak and plan adaptation were then silently lost).
        // `.sheet(item:)`, not `.sheet(isPresented:)` — keyed on the run itself so a second run
        // arriving while this one is still showing (see `AppState.pendingDebriefs`) tears down and
        // recreates `DebriefSheet`'s state instead of silently swapping its content underneath an
        // already-picked RPE. Dismissing (swipe-down or VALIDER, both call `dismiss()`, which
        // clears the binding) pops the front of the queue, presenting the next one if any.
        .sheet(item: Binding(
            get: { appState.pendingDebriefs.first },
            set: { newValue in if newValue == nil, !appState.pendingDebriefs.isEmpty { appState.pendingDebriefs.removeFirst() } }
        )) { run in
            DebriefSheet(run: run).runUpSheetStyle()
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
        case .live: LiveRunView()
        case .recap: RecapView()
        case .coach: CoachView()
        case .stats: StatsView()
        case .club: SocialView()
        case .race: RaceGoalView()
        case .profile: ProfileView()
        case .history: HistoryView()
        case .weeklyRecap: WeeklyRecapView()
        case .shoes: ShoesView()
        case .heatmap: HeatmapView()
        }
    }
}
