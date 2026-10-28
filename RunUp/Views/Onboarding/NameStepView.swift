import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ObCorps {
                VStack(alignment: .leading, spacing: 0) {
                    ObTitle(eyebrow: "Pour commencer", title: "COMMENT\nTU T'APPELLES ?",
                            subtitle: "Ton coach s'adressera à toi par ton prénom. Le nom sert à tes amis, pour te retrouver dans le Club.")
                    ObTextField(placeholder: "Prénom", text: $vm.name)
                        .padding(.top, 24)
                    // LE NOM EST DEMANDÉ ICI, ET IL EST EXIGÉ.
                    //
                    // Il ne sert à rien hors du Club. Il est demandé quand même, dès la première
                    // question, parce que c'est l'autre moitié de ce que la recherche de
                    // « Mes amis » interroge : `name || ' ' || last_name`. Quelqu'un sans nom ET
                    // sans pseudo n'est trouvable que par son adresse e-mail exacte — c'est ce
                    // qui est arrivé à toute la première semaine de testeuses.
                    //
                    // `.words` : un nom propre prend sa majuscule tout seul, et personne ne
                    // devrait avoir à la poser à la main sur l'écran le plus court de l'app.
                    // « Nom de famille » et non « Nom » : la clé « Nom » existe déjà au
                    // catalogue, traduite « Name » — c'est celle de la fiche d'administration,
                    // où elle désigne le nom complet d'un compte. La réutiliser afficherait
                    // « Name » sous « First name ».
                    ObTextField(placeholder: "Nom de famille", text: $vm.lastName)
                        .textInputAutocapitalization(.words)
                        .padding(.top, 10)
                }
            }
            ObNext(disabled: !vm.peutContinuer, action: onNext)
        }
    }
}
