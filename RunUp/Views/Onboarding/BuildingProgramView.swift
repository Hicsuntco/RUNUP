import SwiftUI

/// Final onboarding step — animated ring + checklist, then the « TON PLAN » recap.
///
/// # IL N'ENCHAÎNE PLUS SUR L'ACCUEIL TOUT SEUL
///
/// L'anneau se remplissait, « Prêt ! » paraissait une demi-seconde, et l'app s'ouvrait sur
/// l'accueil — l'inscription se terminait par une temporisation, et les neuf écrans de réponses
/// n'avaient jamais été relus. Le dernier palier ouvre maintenant `PlanRecapView`, qui attend un
/// appui : c'est lui qui appelle `onDone`.
///
/// La demi-seconde reste, et c'est toujours la même : le temps de voir la coche et de lire
/// « Prêt ! », sans quoi l'écran changerait au moment précis où il annonce sa réussite.
struct BuildingProgramView: View {
    @Bindable var vm: OnboardingViewModel
    var onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Posé par le dernier minuteur de `runSequence`, et non dérivé de `buildProgress` : la
    /// bascule arrive une demi-seconde APRÈS le dernier palier, donc elle a sa propre date.
    @State private var recapitulatif = false

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

    private var buildFraction: Double {
        guard !buildSteps.isEmpty else { return 0 }
        return min(1, Double(vm.buildProgress) / Double(buildSteps.count))
    }
    private var buildIsDone: Bool { vm.buildProgress >= buildSteps.count }

    /// Program length is variable (tied to a real race date, or open-ended for other goals) since
    /// the plan-engine rebuild — this used to just say "9 semaines" regardless of what was
    /// actually about to be built.
    private var buildingLabel: String {
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: vm.goal ?? .health, raceDate: vm.raceDate, from: .now)
        if let total = shape.totalWeeks { return String(localized: "\(total) semaines en préparation…") }
        return String(localized: "Programme sur mesure en préparation…")
    }

    var body: some View {
        if recapitulatif {
            PlanRecapView(vm: vm, onDone: onDone)
                .transition(.opacity)
        } else {
            construction
                .transition(.opacity)
        }
    }

    private var construction: some View {
        ObScreen {
            Spacer()
            VStack(spacing: 22) {
                // Le 4 était écrit trois fois, sans lien avec la liste qui décide vraiment du
                // nombre de paliers. Un cinquième élément ajouté un jour à `buildSteps` aurait
                // envoyé l'anneau à 125 % et laissé la coche de fin inatteignable.
                RingView(pct: buildFraction * 100, color: RUColor.rose, size: 110, strokeWidth: 7) {
                    Text(buildIsDone ? "✓" : "\(Int(buildFraction * 100))%")
                        .displayStyle(30)
                        .foregroundColor(buildIsDone ? RUColor.lime : RUColor.textPrimary)
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
                // L'annonce des notifications vivait ici, juste sous « Prêt ! ». Elle est
                // passée sur `PlanRecapView` : c'est désormais lui le dernier écran avant la
                // boîte de dialogue du système, et une mise en bouche doit se trouver sur
                // l'écran qu'on est en train de lire quand la demande arrive.
                Text(buildIsDone ? String(localized: "Prêt !") : buildingLabel)
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
            }
            .animation(reduceMotion ? nil : .easeIn(duration: 0.25), value: vm.buildProgress)
            .padding(.bottom, 24)
        }
        .onAppear(perform: runSequence)
    }

    private func runSequence() {
        vm.buildProgress = 0
        // Un palier par seconde, parce que l'anneau met exactement une seconde à rejoindre sa
        // nouvelle valeur (`RingView.fillDuration`). Les paliers tombaient tous les 0,6 à 0,8
        // seconde : chacun coupait l'animation du précédent en pleine décélération, et l'anneau
        // repartait de plus belle — il sautait. Le pourcentage au centre, lui, changeait
        // instantanément, si bien qu'il annonçait 50 % au-dessus d'un anneau qui en montrait 30.
        //
        // Dérivé de la constante plutôt que réécrit ici : les deux DOIVENT être d'accord, et
        // c'est la seule construction où ils ne peuvent plus diverger en silence.
        let step = RingView<EmptyView>.fillDuration
        for i in 0..<buildSteps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + step * Double(i + 1)) {
                vm.buildProgress = i + 1
            }
        }
        // Une demi-seconde après le dernier palier : le temps de voir la coche et de lire
        // « Prêt ! », sans quoi l'écran changerait au moment précis où il annonce sa réussite.
        DispatchQueue.main.asyncAfter(deadline: .now() + step * Double(buildSteps.count) + 0.5) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { recapitulatif = true }
        }
    }
}
