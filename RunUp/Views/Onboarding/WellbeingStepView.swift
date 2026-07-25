import SwiftUI

/// Step 4 — injury/blessure to watch + cycle-tracking opt-in, shared across every goal branch.
/// Used to be silently appended to the bottom of step 3 (`DeepDiveStepView`/`RaceDetailsStepView`/
/// `HyroxDetailsStepView`): the progress bar counted it as part of "step 3 of 8" even though it's
/// really its own separate question, not a footnote to the goal-specific one — split into an
/// honest step of its own.
struct WellbeingStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    ObTitle(eyebrow: "Étape 4 · un mot sur toi", title: "AVANT DE CONTINUER", subtitle: "Pour un plan qui colle vraiment à ta réalité.")
                    WellbeingFieldsView(vm: vm)
                }
                // The cycle-tracking date picker + duration stepper only appear once "Oui" is
                // tapped — on a short screen they land right at the bottom edge of the visible
                // area, easy to miss unless something calls attention to them. The short delay
                // lets SwiftUI lay out the newly-revealed fields before `scrollTo` has a target
                // to aim at (asking for an id that doesn't exist yet is a no-op).
                .onChange(of: vm.cycleTrackingEnabled) { _, enabled in
                    guard enabled else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("cycleFields", anchor: .bottom) }
                    }
                }
            }
            ObNext(disabled: !vm.canProceed(fromStep: 4), action: onNext)
        }
    }
}
