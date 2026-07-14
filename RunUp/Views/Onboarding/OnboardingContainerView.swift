import SwiftUI

/// Hosts the pre-onboarding welcome screen + the 8-step wizard. Mirrors the top-level
/// `Onboarding` component in onboarding.jsx.
struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = OnboardingViewModel()

    var body: some View {
        ZStack {
            RadialGradient(colors: [RUColor.rose.opacity(vm.showWelcome ? 0.22 : 0.16), .clear], center: .top, startRadius: 0, endRadius: 420)
            RUColor.bg

            if vm.showWelcome {
                WelcomeView(onStart: { vm.showWelcome = false })
            } else {
                VStack(spacing: 0) {
                    Spacer().frame(height: 44)
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
            } else {
                DeepDiveStepView(vm: vm) { advance() }
            }
        case 4: RunningDaysStepView(vm: vm) { advance() }
        case 5: LevelStepView(vm: vm) { advance() }
        case 6: HealthConnectStepView(vm: vm) { advance() }
        default: BuildingProgramView(vm: vm) { finish() }
        }
    }

    private func advance() {
        vm.step = min(vm.step + 1, OnboardingViewModel.totalSteps - 1)
    }

    private func finish() {
        AdaptivePlanEngine.applyOnboarding(vm.buildResult(), to: appState.profile)
        appState.toast("Ton programme de 9 semaines est prêt")
    }
}
