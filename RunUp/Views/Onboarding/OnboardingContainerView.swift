import SwiftUI

/// Hosts the pre-onboarding welcome screen + the 9-step wizard. Mirrors the top-level
/// `Onboarding` component in onboarding.jsx.
struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = OnboardingViewModel()

    var body: some View {
        ZStack {
            RadialGradient(colors: [RUColor.rose.opacity(vm.showWelcome ? 0.22 : 0.16), .clear], center: .top, startRadius: 0, endRadius: 420)
            RUColor.bg

            if vm.showWelcome {
                // The top of the funnel every other onboarding number is a percentage of — the app
                // has no other way to tell "opened it and never started" apart from "started and
                // dropped at step 3", which are two completely different problems.
                WelcomeView(onStart: {
                    vm.showWelcome = false
                    Analytics.shared.track(.onboardingStarted)
                })
            } else {
                VStack(spacing: 0) {
                    Spacer().frame(height: 12)
                    // Back navigation — the wizard used to be forward-only, so a mistyped
                    // birthdate or a mis-picked goal could only be fixed by finishing onboarding
                    // and replaying the whole thing from Profil. Hidden on the first step (nothing
                    // to go back to) and the final "building" step (the program is generating).
                    HStack {
                        if vm.step > 0 && vm.step < OnboardingViewModel.totalSteps - 1 {
                            BackChevronButton { vm.step -= 1; vm.saveDraft() }
                        } else {
                            Color.clear.frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    ObProgress(step: vm.step, total: OnboardingViewModel.totalSteps)
                    currentStep
                        .id(vm.step)
                        .transition(.opacity)
                        // `.id(vm.step)` already gives each step its own identity, so this fires
                        // exactly once per step entered — including a step re-entered via the back
                        // chevron, which is itself worth seeing (a step people go back to is a step
                        // that asked the question badly).
                        .onAppear { Analytics.shared.track(.onboardingStepViewed, stepProps()) }
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: vm.step)
        .animation(.easeInOut(duration: 0.3), value: vm.showWelcome)
        // Belt-and-braces alongside the per-step saves in `advance()`/the back button: catches
        // answers typed *within* a step (a name, a weight) that would otherwise be lost if she's
        // interrupted — a call, the app switcher, a low-battery kill — before ever tapping Continuer.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { vm.saveDraft() }
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch vm.step {
        case 0: NameStepView(vm: vm) { advance() }
        case 1: BirthdateStepView(vm: vm) { advance() }
        case 2: GoalStepView(vm: vm) { advance() }
        case 3:
            if vm.isRace {
                RaceDetailsStepView(vm: vm) { advance() }
            } else if vm.isHyrox {
                HyroxDetailsStepView(vm: vm) { advance() }
            } else {
                DeepDiveStepView(vm: vm) { advance() }
            }
        case 4: WellbeingStepView(vm: vm) { advance() }
        case 5: RunningDaysStepView(vm: vm) { advance() }
        case 6: LevelStepView(vm: vm) { advance() }
        case 7: HealthConnectStepView(vm: vm) { advance() }
        default: BuildingProgramView(vm: vm) { finish() }
        }
    }

    private func advance() {
        // Recorded BEFORE the index moves, so the event names the step that was actually answered.
        // Paired with `onboarding_step_viewed`, viewed-minus-completed per step is the drop-off
        // curve — the one number that says which question is losing people.
        Analytics.shared.track(.onboardingStepCompleted, stepProps())
        vm.step = min(vm.step + 1, OnboardingViewModel.totalSteps - 1)
        vm.saveDraft()
    }

    /// `step` (the index, for ordering a funnel chart) plus `name` (stable, for reading it) —
    /// the index alone would silently re-point at a different question the day a step is inserted.
    private func stepProps() -> [String: AnalyticsValue] {
        ["step": .int(vm.step), "name": .string(stepName(vm.step))]
    }

    /// Mirrors the `currentStep` switch above, including its branch at step 3 (the deep-dive
    /// question differs by goal, and lumping the three together would hide a drop-off specific to
    /// one of them).
    private func stepName(_ step: Int) -> String {
        switch step {
        case 0: return "name"
        case 1: return "birthdate"
        case 2: return "goal"
        case 3: return vm.isRace ? "race_details" : (vm.isHyrox ? "hyrox_details" : "deep_dive")
        case 4: return "wellbeing"
        case 5: return "running_days"
        case 6: return "level"
        case 7: return "health_connect"
        default: return "building_program"
        }
    }

    private func finish() {
        // The bottom of the funnel: a real, generated program. Carries the three answers that
        // shape every plan the engine builds, so a drop-off (or a retention gap) can be read
        // against the goal/level/rhythm it belongs to instead of as one undifferentiated number.
        Analytics.shared.track(.onboardingFinished, [
            "goal": .string(vm.goal?.rawValue ?? "unknown"),
            "level": .string(vm.level.rawValue),
            "running_days": .int(vm.runningDays.count),
        ])
        vm.clearDraft()
        AdaptivePlanEngine.applyOnboarding(vm.buildResult(), to: appState.profile)
        let profile = appState.profile
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
        let message = shape.totalWeeks.map { String(localized: "Ton programme de \($0) semaines est prêt") } ?? String(localized: "Ton programme sur mesure est prêt")
        Haptics.success()
        appState.toast(message)
        // `coachNotificationsEnabled` defaults to true, but the system permission itself was
        // never actually requested yet — do it once here so the daily reminder can work out of
        // the box, matching the toggle's default state, rather than silently doing nothing until
        // she happens to visit Profil and re-toggle it.
        Task {
            await NotificationService.shared.requestAuthorization()
            NotificationService.shared.rescheduleDailyReminder(for: profile)
        }
    }
}
