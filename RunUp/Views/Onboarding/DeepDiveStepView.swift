import SwiftUI
import UIKit

/// Step 3 for non-race goals — branches by `goal` (weight/progress/restart/health). Mirrors the
/// `!isRace` branch of step 3 in onboarding.jsx.
struct DeepDiveStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    private var title: String {
        switch vm.goal {
        case .weight: return "TON POINT DE DÉPART"
        case .progress: return "TA PRIORITÉ"
        case .restart: return "AVANT DE REPRENDRE"
        default: return "TON RYTHME IDÉAL"
        }
    }

    var body: some View {
        ObScreen {
            ScrollView {
                ObTitle(eyebrow: "Étape 3 · sur mesure", title: title, subtitle: "Plus on en sait, plus le plan colle à ta réalité.")

                switch vm.goal {
                case .weight: weightFields
                case .progress: progressFields
                case .restart: restartFields
                default: healthFields
                }
            }
            ObNext(disabled: !vm.canProceed(fromStep: 3), action: onNext)
        }
    }

    private var weightFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                NumField(label: "Poids actuel", value: $vm.weightNow, unit: "kg", placeholder: "70")
                NumField(label: "Poids visé", value: $vm.weightTarget, unit: "kg", placeholder: "64")
            }
            NumField(label: "Taille", value: $vm.height, unit: "cm", placeholder: "168")
            Text("Ton coach adapte ses conseils course et nutrition à ton objectif — sans jamais sacrifier ta forme.")
                .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).lineSpacing(3)
        }
        .padding(.top, 20)
    }

    private var progressFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Ta priorité", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach([("speed", "Aller plus vite"), ("endurance", "Tenir plus longtemps"), ("consistency", "Être régulière"), ("trail", "Dénivelé / trail")], id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.focusArea == id) { vm.focusArea = id }
                }
            }
            EyebrowLabel(text: "Ta meilleure perf récente (facultatif)", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ObTextField(placeholder: "Ex. 10 km en 52 min", text: $vm.bestRecentPerf)
        }
    }

    private var restartFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Ta dernière sortie remonte à", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach([("1m", "Moins d'1 mois"), ("6m", "1 à 6 mois"), ("1y", "6 mois à 1 an"), ("1y+", "Plus d'1 an")], id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.lastRanRecency == id) { vm.lastRanRecency = id }
                }
            }
            EyebrowLabel(text: "Une douleur ou blessure à surveiller ?", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach([("none", "Aucune"), ("knee", "Genou"), ("ankle", "Cheville"), ("back", "Dos"), ("other", "Autre")], id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.injuryArea == id) { vm.injuryArea = id }
                }
            }
        }
    }

    private var healthFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Temps que tu veux y consacrer / semaine", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach([("1h", "Moins d'1h"), ("2h", "1 à 2h"), ("3h", "2 à 3h"), ("3h+", "Plus de 3h")], id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.weeklyTimeBudget == id) { vm.weeklyTimeBudget = id }
                }
            }
            EyebrowLabel(text: "Ton moment préféré pour courir", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach([("morning", "Matin"), ("noon", "Midi"), ("evening", "Soir"), ("varies", "Ça varie")], id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.preferredTimeOfDay == id) { vm.preferredTimeOfDay = id }
                }
            }
        }
    }
}

private struct NumField: View {
    var label: String
    @Binding var value: String
    var unit: String
    var placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: label, color: RUColor.text3)
            HStack {
                TextField("", text: $value, prompt: Text(placeholder).foregroundColor(RUColor.text3))
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .toolbar {
                        // .numberPad has no return key and this screen has no scroll-to-dismiss —
                        // without this, the keyboard has no way to close and permanently covers
                        // the Continuer button underneath (the bug reported as the weight-goal
                        // step being "stuck").
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Terminé") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                Text(unit).font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.text2)
            }
            .padding(13)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        }
    }
}
