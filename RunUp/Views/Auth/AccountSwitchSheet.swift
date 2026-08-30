import SwiftUI

/// « Ce téléphone contient les données de quelqu'un d'autre. »
///
/// Elle s'affiche quand un compte se connecte sur un appareil dont le profil appartient à un autre
/// compte. Elle bloque tout : il n'y a pas de bonne façon de continuer sans avoir demandé.
///
/// Effacer d'office détruirait le programme de quelqu'un qui s'est simplement trompé de compte à
/// la connexion. Ne rien faire montrerait le nom, la photo et l'entraînement d'une personne à une
/// autre. Les deux valent moins que la question — d'où cette feuille, qu'on ne peut ni glisser ni
/// contourner, et dont les deux issues sont écrites en clair.
struct AccountSwitchSheet: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(RUColor.amber)
                .padding(.bottom, 2)

            Text("Ces données ne sont pas les tiennes")
                .displayStyle(26)
                .foregroundColor(RUColor.textPrimary)

            // Le nom du profil local, pas celui du compte qui arrive : c'est lui qui est à l'écran
            // en ce moment, et c'est de lui qu'on parle.
            Text("Ce téléphone contient le profil de \(appState.profile.name) — son programme, son historique et ses réglages. Tu viens de te connecter avec un autre compte.")
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: { appState.startFreshForNewAccount() }) {
                    Text("Repartir à neuf")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: { appState.cancelAccountSwitch() }) {
                    Text("Ce n'est pas le bon compte")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, 4)

            // Dit avant le geste, pas après. « Repartir à neuf » efface l'entraînement de
            // quelqu'un : personne ne doit découvrir ce que ça voulait dire une fois que c'est
            // fait.
            Text("Repartir à neuf efface le programme, l'historique des courses et la conversation avec le coach enregistrés sur cet appareil. Ce qui appartient au Club — les sorties publiées, les kilomètres du club — reste sur le compte de chacune.")
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RUColor.bg)
        .interactiveDismissDisabled()
    }
}
