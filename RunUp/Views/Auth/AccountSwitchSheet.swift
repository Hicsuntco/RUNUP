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
    @State private var confirming = false

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

            // AVANT LE GESTE, POUR DE BON. Le commentaire disait déjà « dit avant le geste, pas
            // après » — et le paragraphe était posé SOUS les boutons, dans une feuille à un seul
            // détent moyen, sans défilement : la phrase qui nomme ce qu'on détruit tombait hors
            // de l'écran, inatteignable. Elle est remontée à sa place.
            Text("Repartir à neuf efface le programme, l'historique des courses et la conversation avec le coach enregistrés sur cet appareil. Ce qui appartient au Club — les sorties publiées, les kilomètres du club — reste sur le compte de chacune.")
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: { confirming = true }) {
                    Text("Repartir à neuf")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: { appState.cancelAccountSwitch() }) {
                    Text("Ce n'est pas le bon compte")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding(22)
        // LA SEULE ACTION DESTRUCTRICE DE L'APP QUI N'EN AVAIT PAS. Supprimer une course en a
        // une, une paire de chaussures en a une, effacer la conversation du coach en a une — et
        // celle-ci efface les trois à la fois. Le bouton est en plus rose plein, celui qu'on
        // tape par réflexe partout ailleurs dans l'app.
        .confirmationDialog(
            Text("Effacer le programme et l'historique de \(appState.profile.name) ?"),
            isPresented: $confirming, titleVisibility: .visible
        ) {
            Button("Tout effacer", role: .destructive) { appState.startFreshForNewAccount() }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Cette action est définitive.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RUColor.bg)
        .interactiveDismissDisabled()
    }
}
