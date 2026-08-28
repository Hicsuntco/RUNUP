import SwiftUI

/// Final onboarding step — animated ring + checklist, auto-advances. Mirrors the `built` state
/// machine (4 timed steps over ~2.9s, then `onDone` at 3.8s) in onboarding.jsx.
struct BuildingProgramView: View {
    @Bindable var vm: OnboardingViewModel
    var onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var buildSteps: [String] {
        let dayCount = vm.runningDays.count
        let closing: String
        if vm.isRace {
            let fallback = String(localized: "ta course")
            let label = vm.distance == .other ? (vm.customDistance.isEmpty ? fallback : vm.customDistance) : (vm.distance?.label ?? fallback)
            closing = String(localized: "Objectif \(label) sécurisé")
        } else {
            closing = String(localized: "Progression sécurisée")
        }
        let firstName = vm.name.trimmingCharacters(in: .whitespaces)
        let profileStep = firstName.isEmpty ? String(localized: "Ton profil analysé") : String(localized: "Profil de \(firstName) analysé")
        return [
            profileStep,
            String(localized: "Ta forme de départ estimée"),
            String(localized: "Séances calées sur tes \(dayCount) jours"),
            closing
        ]
    }

    /// Program length is variable (tied to a real race date, or open-ended for other goals) since
    /// the plan-engine rebuild — this used to just say "9 semaines" regardless of what was
    /// actually about to be built.
    private var buildingLabel: String {
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: vm.goal ?? .health, raceDate: vm.raceDate, from: .now)
        if let total = shape.totalWeeks { return String(localized: "\(total) semaines en préparation…") }
        return String(localized: "Programme sur mesure en préparation…")
    }

    var body: some View {
        ObScreen {
            Spacer()
            VStack(spacing: 22) {
                RingView(pct: Double(vm.buildProgress) / 4 * 100, color: RUColor.rose, size: 110, strokeWidth: 7) {
                    Text(vm.buildProgress == 4 ? "✓" : "\(Int(Double(vm.buildProgress) / 4 * 100))%")
                        .displayStyle(30)
                        .foregroundColor(vm.buildProgress == 4 ? RUColor.lime : RUColor.textPrimary)
                }
                VStack(spacing: 6) {
                    // A generic "ON CONSTRUIT TON PROGRAMME" was the exact same reveal moment for
                    // every runner regardless of what she'd just spent 7 steps answering — this
                    // names who it's for, the same way the checklist below already names her race
                    // distance and running-day count instead of generic placeholders.
                    if !vm.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        EyebrowLabel(text: String(localized: "Pour \(vm.name.trimmingCharacters(in: .whitespaces))"), color: RUColor.rose)
                    }
                    Text("ON CONSTRUIT\nTON PROGRAMME")
                        .displayStyle(28)
                        .multilineTextAlignment(.center)
                        .foregroundColor(RUColor.textPrimary)
                        .lineSpacing(-2)
                }
            }

            VStack(spacing: 0) {
                ForEach(buildSteps.indices, id: \.self) { i in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(vm.buildProgress > i ? RUColor.rose : RUColor.card)
                                .overlay(Circle().stroke(vm.buildProgress > i ? Color.clear : RUColor.line, lineWidth: 1))
                            if vm.buildProgress > i {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            } else if vm.buildProgress == i {
                                Circle().fill(RUColor.rose).frame(width: 6, height: 6)
                            }
                        }
                        .frame(width: 24, height: 24)
                        Text(buildSteps[i])
                            .font(RUFont.sans(.emphasis))
                            .foregroundColor(vm.buildProgress > i ? RUColor.textPrimary : RUColor.text2)
                        Spacer()
                    }
                    .padding(.vertical, 13)
                    .overlay(Divider().background(RUColor.line), alignment: .bottom)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: vm.buildProgress)
                }
            }
            .padding(.top, 26)
            Spacer()
            VStack(spacing: 4) {
                Text(vm.buildProgress == 4 ? String(localized: "Prêt !") : buildingLabel)
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
                // Shown right before the system notification permission prompt fires (see
                // `OnboardingContainerView.finish()`) — that dialog used to appear with zero lead-
                // in, right as she lands on Home, so a blind "Autoriser ?" read as coming from
                // nowhere. This gives it a reason before it shows up.
                if vm.buildProgress == 4 {
                    Text("On t'enverra un petit rappel pour tes séances 🔔")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeIn(duration: 0.25), value: vm.buildProgress)
            .padding(.bottom, 24)
        }
        .onAppear(perform: runSequence)
    }

    private func runSequence() {
        vm.buildProgress = 0
        let delays: [Double] = [0.6, 1.3, 2.1, 2.9]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                vm.buildProgress = i + 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            onDone()
        }
    }
}
