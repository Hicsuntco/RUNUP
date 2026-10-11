import SwiftUI

/// « OÙ TU EN ES » — l'étape qui ancre le plan sur la personne plutôt que sur la course visée.
///
/// # POURQUOI UN ÉCRAN DE PLUS, APRÈS AVOIR TANT RÉPÉTÉ QU'UNE QUESTION DOIT CHANGER UNE DÉCISION
///
/// Parce que ces trois-là en changent trois, et des grosses. Avant elles, le moteur devinait :
///
///   • la première sortie longue venait de la DISTANCE DE LA COURSE — 8,4 km en semaine 1 d'un
///     plan marathon, qu'on coure trois kilomètres ou vingt-cinq ;
///   • le palier de départ venait du niveau coché, un mot sur soi, et de rien d'autre ;
///   • toutes les allures du plan venaient du TEMPS VISÉ, c'est-à-dire d'une ambition — ou, pour
///     les huit objectifs sans course, d'une des trois constantes du niveau.
///
/// Trois réponses, et le plan cesse d'être le même pour tout le monde à objectif égal.
///
/// # L'ORDRE DES QUESTIONS EST CELUI DE LA DIFFICULTÉ
///
/// On commence par ce que tout le monde sait de soi — combien de fois je cours — et on finit par
/// ce que peu de gens savent — à quelle allure. La dernière porte « Je ne sais pas » en premier
/// choix, et c'est une vraie réponse : inventer un chiffre pour passer l'écran serait pire que
/// de ne pas répondre, puisque le plan le prendrait au mot.
struct PointDeDepartStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ScrollView {
                // Pas « OÙ TU EN ES » : c'est déjà le titre de l'étape du niveau, deux
                // écrans plus loin. Deux écrans d'une même inscription ne peuvent pas porter le
                // même titre — on ne saurait plus lequel on est en train de lire.
                ObTitle(eyebrow: "Étape 4 · ton point de départ",
                        title: "CE QUE TU COURS DÉJÀ",
                        subtitle: "Le plan part d'ici. Pas de ce que tu voudrais courir.")

                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: "Tu cours combien de fois par semaine, en ce moment ?",
                                 color: RUColor.text3)
                        .padding(.top, 22).padding(.bottom, 10)
                    ChipFlowLayout {
                        ForEach(VolumeActuel.allCases) { choix in
                            SelectableChip(label: choix.title, selected: vm.volumeActuel == choix) {
                                vm.volumeActuel = choix
                            }
                        }
                    }

                    EyebrowLabel(text: "Ta plus longue sortie des 4 dernières semaines",
                                 color: RUColor.text3)
                        .padding(.top, 22).padding(.bottom, 10)
                    ChipFlowLayout {
                        ForEach(PlusLongueSortie.allCases) { choix in
                            SelectableChip(label: choix.title, selected: vm.plusLongueSortie == choix) {
                                vm.plusLongueSortie = choix
                            }
                        }
                    }
                    // C'est de CE nombre que part la première sortie longue du plan. La phrase le
                    // dit, parce qu'une question dont on comprend l'usage se répond mieux — et
                    // parce que celle-ci se répond de mémoire, donc approximativement.
                    Text("C'est d'ici que part ta première sortie longue.")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .padding(.top, 8)

                    EyebrowLabel(text: "Ta meilleure perf récente (facultatif)", color: RUColor.text3)
                        .padding(.top, 22).padding(.bottom, 10)
                    ObTextField(placeholder: "Ex. 10 km en 52 min", text: $vm.bestRecentPerf)

                    // L'ALLURE N'EST DEMANDÉE QUE SI LA PERF NE L'A PAS DÉJÀ DITE. Une distance
                    // et un temps valent mieux qu'une tranche : ils se projettent sur n'importe
                    // quelle autre distance. Poser les deux questions à quelqu'un qui a répondu
                    // à la première, c'est lui demander deux fois la même chose.
                    if vm.bestRecentPerf.trimmingCharacters(in: .whitespaces).isEmpty {
                        EyebrowLabel(text: "Sinon : ton allure sur un footing tranquille",
                                     color: RUColor.text3)
                            .padding(.top, 22).padding(.bottom, 10)
                        ChipFlowLayout {
                            ForEach(AllureFooting.allCases) { choix in
                                SelectableChip(label: choix.title, selected: vm.allureFooting == choix) {
                                    vm.allureFooting = choix
                                }
                            }
                        }
                    }

                    Text("Toutes les allures de ton plan descendent de cette réponse.")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                }
            }
            ObNext(disabled: !vm.canProceed(fromStep: 4), action: onNext)
        }
    }
}
