import SwiftUI

/// Final onboarding step — animated ring + checklist, auto-advances. Mirrors the `built` state
/// machine (4 timed steps over ~2.9s, then `onDone` at 3.8s) in onboarding.jsx.
struct BuildingProgramView: View {
    @Bindable var vm: OnboardingViewModel
    var onDone: () -> Void

    private var buildSteps: [String] {
        let dayCount = vm.runningDays.count
        let closing: String
        if vm.isRace {
            let label = vm.distance == .other ? (vm.customDistance.isEmpty ? "ta course" : vm.customDistance) : (vm.distance?.label ?? "ta course")
            closing = "Objectif \(label) sécurisé"
        } else {
            closing = "Progression sécurisée"
        }
        return [
            "Ton profil analysé",
            "Ta forme de départ estimée",
            "Séances calées sur tes \(dayCount) jours",
            closing
        ]
    }

    /// Program length is variable (tied to a real race date, or open-ended for other goals) since
    /// the plan-engine rebuild — this used to just say "9 semaines" regardless of what was
    /// actually about to be built.
    private var buildingLabel: String {
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: vm.goal ?? .health, raceDate: vm.raceDate, from: .now)
        if let total = shape.totalWeeks { return "\(total) semaines en préparation…" }
        return "Programme sur mesure en préparation…"
    }

    var body: some View {
        ObScreen {
            Spacer()
            VStack(spacing: 22) {
                RingView(pct: Double(vm.buildProgress) / 4 * 100, color: RUColor.rose, size: 110, strokeWidth: 7) {
                    Text(vm.buildProgress == 4 ? "✓" : "\(Int(Double(vm.buildProgress) / 4 * 100))%")
                        .displayStyle(30)
                        .foregroundColor(vm.buildProgress == 4 ? RUColor.lime : .white)
                }
                Text("ON CONSTRUIT\nTON PROGRAMME")
                    .displayStyle(28)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .lineSpacing(-2)
            }

            VStack(spacing: 0) {
                ForEach(buildSteps.indices, id: \.self) { i in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(vm.buildProgress > i ? RUColor.rose : Color.white.opacity(0.06))
                                .overlay(Circle().stroke(Color.white.opacity(vm.buildProgress > i ? 0 : 0.15), lineWidth: 1))
                            if vm.buildProgress > i {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            } else if vm.buildProgress == i {
                                Circle().fill(RUColor.rose).frame(width: 6, height: 6)
                            }
                        }
                        .frame(width: 24, height: 24)
                        Text(buildSteps[i])
                            .font(RUFont.sans(14))
                            .foregroundColor(vm.buildProgress > i ? .white : RUColor.text2)
                        Spacer()
                    }
                    .padding(.vertical, 13)
                    .overlay(Divider().background(Color.white.opacity(0.06)), alignment: .bottom)
                }
            }
            .padding(.top, 26)
            Spacer()
            Text(vm.buildProgress == 4 ? "Prêt !" : buildingLabel)
                .font(RUFont.sans(11))
                .foregroundColor(RUColor.text3)
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
