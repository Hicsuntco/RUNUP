import SwiftUI

/// Étape 8 — le consentement aux statistiques d'usage.
///
/// # POURQUOI UN ÉCRAN, ET PAS UNE CASE DANS LES RÉGLAGES
///
/// L'audit du 9 novembre 2026 l'a relevé ainsi : « Aucun écran ne présente un consentement
/// explicite et révocable aux statistiques d'usage. La politique les décrit ; l'app ne les
/// propose pas à refuser. » Un réglage qu'il faut aller chercher n'est pas un consentement
/// explicite — c'est un refus possible, ce qui n'est pas la même chose.
///
/// # POURQUOI ICI, ET PAS AVANT
///
/// Les événements de l'inscription sont enregistrés depuis le premier écran : c'est l'entonnoir,
/// et il n'a de sens que complet. Poser la question à la première seconde, avant même d'avoir dit
/// ce que l'app fait, serait à la fois impoli et inutile — personne ne décide de ça devant un
/// écran vide.
///
/// `Analytics` résout ça en GARDANT sans envoyer tant que la question n'est pas posée : un oui
/// ici expédie ce qui était gardé, un non le jette. Rien ne part avant la réponse, et l'entonnoir
/// reste mesurable pour qui accepte.
///
/// # DEUX BOUTONS, ET AUCUN N'EST LE DÉFAUT
///
/// Pas de case pré-cochée, pas de « Continuer » qui vaut oui. Les deux réponses sont des boutons
/// de même poids typographique ; seul l'accent distingue celui qui accepte, parce qu'un écran
/// d'inscription a besoin d'un chemin principal — pas parce que l'autre serait moins légitime.
struct StatistiquesStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ObCorps {
                VStack(alignment: .leading, spacing: 0) {
                    ObTitle(
                        eyebrow: String(localized: "Étape 8 · la mesure"),
                        title: String(localized: "ON PEUT COMPTER\nTES PAS DANS L'APP ?"),
                        subtitle: String(localized: "Pas tes pas de course — ceux que tu fais dans l'app. Savoir à quel écran les gens s'arrêtent est la seule façon de réparer ce qui coince.")
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        ligne(icone: "checkmark.circle",
                              texte: String(localized: "Douze moments du parcours : l'app s'ouvre, une étape est franchie, une course démarre, le coach répond."))
                        ligne(icone: "xmark.circle",
                              texte: String(localized: "Jamais ce que tu écris, jamais ta position, jamais rien d'Apple Santé."))
                        ligne(icone: "arrow.uturn.backward.circle",
                              texte: String(localized: "Tu peux changer d'avis quand tu veux, dans Profil → Réglages → Plus de réglages."))
                    }
                    .padding(.top, 24)

                    Text("Si tu refuses, aucune statistique n'est envoyée ni gardée. L'app fonctionne exactement pareil.")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                }
            }

            VStack(spacing: 10) {
                ObNext(label: String(localized: "D'ACCORD")) {
                    Analytics.shared.consentir(.accepte)
                    onNext()
                }
                Button {
                    Analytics.shared.consentir(.refuse)
                    onNext()
                } label: {
                    Text("NON MERCI")
                        .font(RUFont.display(.label))
                        .tracking(1)
                        .foregroundColor(RUColor.text2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func ligne(icone: String, texte: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icone)
                .font(RUFont.icone(.body))
                .foregroundColor(RUColor.text3)
                .accessibilityHidden(true)
            Text(texte)
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
