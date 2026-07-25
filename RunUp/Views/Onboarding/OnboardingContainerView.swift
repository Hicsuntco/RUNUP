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
                WelcomeView(onStart: { vm.showWelcome = false })
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
        vm.step = min(vm.step + 1, OnboardingViewModel.totalSteps - 1)
        vm.saveDraft()
    }

    private func finish() {
        vm.clearDraft()
        AdaptivePlanEngine.applyOnboarding(vm.buildResult(), to: appState.profile)
        let profile = appState.profile
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
        let message = shape.totalWeeks.map { "Ton programme de \($0) semaines est prêt" } ?? "Ton programme sur mesure est prêt"
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
