import SwiftUI
import UIKit

/// Étape 3 des objectifs sans date — progresser, reprendre, perdre du poids, rester en forme.
///
/// # CE N'EST PLUS UN ÉCRAN GÉNÉRIQUE
///
/// Les quatre partageaient un seul en-tête : « Étape 3 · sur mesure », et le sous-titre « Plus
/// on en sait, plus le plan colle à ta réalité » — une phrase vraie de n'importe quelle question
/// de n'importe quelle app. L'étape 3 est pourtant la première chose qu'on voit APRÈS avoir dit
/// ce qu'on veut : c'est elle qui répond « j'ai compris », et elle répondait « sur mesure » à
/// quelqu'un qui venait de choisir « reprendre sans se blesser ».
///
/// L'en-tête vient maintenant de l'objectif lui-même (voir `GoalType.etapePromesse`), comme pour
/// la course, HYROX et le triathlon, qui avaient le leur depuis le début. Le corps de l'écran,
/// lui, reste branché ici : ce sont quatre jeux de questions différents, et les réunir dans une
/// vue par objectif aurait dupliqué quatre fois la même coquille pour un champ de différence.
struct DeepDiveStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ScrollView {
                if let goal = vm.goal {
                    ObTitle(eyebrow: goal.etapeEyebrow, title: goal.etapeTitre,
                            subtitle: goal.etapePromesse)
                }

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
            // LA TAILLE EST FACULTATIVE, ET ELLE NE L'ÉTAIT PAS.
            //
            // Elle bloquait l'étape au même titre que les deux poids, alors qu'elle ne sert qu'à
            // enrichir UNE phrase du contexte envoyé au coach — lequel sait déjà écrire « ? »
            // quand elle manque (voir `CoachService`). Exiger une troisième mesure corporelle
            // pour avancer, sur l'objectif dont l'étape est déjà la plus intime, était le genre
            // de friction qu'on ne remarque pas en l'écrivant et qu'on subit en la remplissant.
            NumField(label: "Taille (facultatif)", value: $vm.height, unit: "cm", placeholder: "168")
            Text("Ton coach adapte ses conseils course et nutrition à ton objectif — sans jamais sacrifier ta forme.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
        }
        .padding(.top, 20)
    }

    private var progressFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Ta priorité", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                // Les libellés sont RÉSOLUS ici et non laissés en littéraux : « Être régulière »
                // s'accorde avec la personne, et seule une chaîne déjà choisie peut porter le bon
                // accord. Les trois autres passent par `String(localized:)` pour la même raison —
                // un mélange de littéraux et de chaînes résolues dans le même tableau donnerait
                // un type hétérogène, et surtout une liste dont la moitié se traduit au moment de
                // l'affichage et l'autre pas.
                ForEach(OnboardingChoices.priorites, id: \.0) { id, label in
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
                ForEach(OnboardingChoices.recences, id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.lastRanRecency == id) { vm.lastRanRecency = id }
                }
            }
        }
    }

    private var healthFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Temps que tu veux y consacrer / semaine", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(OnboardingChoices.budgetsHebdo, id: \.0) { id, label in
                    SelectableChip(label: label, selected: vm.weeklyTimeBudget == id) { vm.weeklyTimeBudget = id }
                }
            }
            EyebrowLabel(text: "Ton moment préféré pour courir", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(OnboardingChoices.momentsDeLaJournee, id: \.0) { id, label in
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
                    .foregroundColor(RUColor.textPrimary)
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
                Text(unit).font(RUFont.sans(.body, weight: .semibold)).foregroundColor(RUColor.text2)
            }
            .padding(13)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        }
    }
}
