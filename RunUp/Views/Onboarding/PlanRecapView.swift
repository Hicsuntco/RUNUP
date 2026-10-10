import SwiftUI

/// « TON PLAN » — le dernier écran de l'inscription, et le premier qui RENDE quelque chose.
///
/// # L'INSCRIPTION NE DISAIT JAMAIS CE QU'ELLE AVAIT ENTENDU
///
/// Neuf écrans de questions, un anneau qui se remplit, puis l'accueil. Entre la dernière réponse
/// et le programme, rien ne venait relire ce qui avait été dit : les réponses entraient dans la
/// machine et n'en ressortaient jamais. Pour quelqu'un qui vient de passer deux minutes à donner
/// sa date de naissance, sa blessure au genou et son chrono visé, c'est le moment exact où l'app
/// doit prouver qu'elle écoutait — et c'était le moment où elle se taisait.
///
/// Les pastilles sont cette preuve, et ce ne sont pas des promesses : chacune est une réponse
/// qu'elle vient de donner, citée telle quelle. Voir `PlanRecap`, qui les calcule.
///
/// # ET IL NE S'EN VA PLUS TOUT SEUL
///
/// L'écran de construction enchaînait sur l'accueil une demi-seconde après sa dernière coche.
/// Un écran qui vaut la peine d'être lu ne peut pas disparaître avant qu'on l'ait lu, donc
/// celui-ci attend un appui. C'est aussi ce qui donne un sens au bouton : l'inscription se
/// termine par un geste, pas par une temporisation.
struct PlanRecapView: View {
    var vm: OnboardingViewModel
    var onDone: () -> Void

    private var goal: GoalType { vm.goal ?? .health }
    private var pastilles: [String] { PlanRecap.pastilles(vm) }

    var body: some View {
        ObScreen {
            Spacer()
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    EyebrowLabel(text: "Ton plan", color: goal.tint)
                    // L'emoji de l'objectif, en grand. C'est le même que celui de la carte
                    // choisie à l'étape 2 : l'écran se referme sur l'image qu'on avait touchée
                    // pour l'ouvrir.
                    Text(goal.emoji)
                        .font(.system(size: 46))
                        .accessibilityHidden(true)
                    Text(goal.title)
                        .displayStyle(29)
                        .multilineTextAlignment(.center)
                        .foregroundColor(RUColor.textPrimary)
                        .lineSpacing(-2)
                }

                if !pastilles.isEmpty {
                    ChipFlowLayout(spacing: 8, alignment: .center) {
                        ForEach(pastilles, id: \.self) { pastille in
                            // `StatChip` et non une capsule écrite ici : c'est déjà LA pastille
                            // de statut de l'app, et son fond neutre est une décision prise
                            // ailleurs — une teinte de la couleur de la pastille rendait sa
                            // version sale en thème sombre. La couleur reste au texte.
                            StatChip(text: pastille, color: goal.tint)
                        }
                    }
                    // Les pastilles ne vont pas jusqu'aux marges : une rangée centrée a besoin
                    // de respirer sur ses côtés pour se lire comme un bloc, et non comme une
                    // ligne de texte qui aurait raté son alignement.
                    .padding(.horizontal, 10)
                    .accessibilityElement(children: .combine)
                }

                Text(PlanRecap.cloture(vm))
                    .font(RUFont.sans(.label))
                    .multilineTextAlignment(.center)
                    .foregroundColor(RUColor.text2)
                    .lineSpacing(3)
                    .padding(.top, 4)
            }
            Spacer()
            // Reprise de l'écran de construction, qui la portait avant : elle paraît juste avant
            // que le système ne demande l'autorisation des notifications (voir
            // `OnboardingContainerView.finish()`), pour que la boîte de dialogue ait une raison
            // d'apparaître au lieu de tomber de nulle part sur l'accueil.
            Text("On t'enverra un petit rappel pour tes séances 🔔")
                .font(RUFont.sans(.small))
                .multilineTextAlignment(.center)
                .foregroundColor(RUColor.text3)
                .padding(.bottom, 14)
            ObNext(label: "C'EST PARTI", action: onDone)
        }
    }
}
