import SwiftUI

/// Le conteneur des deux écrans sociaux — `ClubView` (esprit club : classement partagé, défis,
/// code d'invitation) et `FriendsView` (un fil d'abonnements, indépendant de toute appartenance à
/// un club). Lequel s'affiche est décidé en amont, par la carte du Profil sur laquelle on a tapé.
///
/// Cet écran portait jusqu'ici un sélecteur « Mon club / Mes amis » en haut. Il a disparu pour
/// deux raisons : depuis que le Profil est le 5e onglet, on n'arrive plus ici que par l'une de ses
/// deux cartes — le choix est donc déjà fait, et le reproposer juste au-dessus de l'écran choisi
/// n'ajoutait rien ; et il n'existait aucun chemin de retour vers le Profil, la barre d'onglets y
/// ramenait sans que rien ne le dise.
struct SocialView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: Mode = .club

    private enum Mode { case club, friends }

    var body: some View {
        VStack(spacing: 0) {
            backToProfile
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.top, 8)

            Group {
                if mode == .club { ClubView() } else { FriendsView() }
            }
        }
        .background(RUColor.bg)
        .onAppear {
            if appState.openFriendsTabOnNextVisit {
                mode = .friends
                appState.openFriendsTabOnNextVisit = false
            }
        }
    }

    /// Le compteur de demandes d'abonnement en attente vivait sur le segment « Mes amis » de ce
    /// sélecteur. Il n'est pas perdu : il est reporté sur la carte Amis du Profil (voir
    /// `ProfileView.amisCard`), donc sur l'écran qu'ouvre directement l'onglet — visible plus tôt
    /// qu'avant, et non plus sur une barre qu'il fallait déjà avoir atteinte.
    private var backToProfile: some View {
        Button(action: { appState.go(.profile) }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                Text("Profil").font(RUFont.sans(13, weight: .semibold))
            }
            .foregroundColor(RUColor.text2)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Retour au profil")
    }
}
