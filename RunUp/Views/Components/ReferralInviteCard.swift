import SwiftUI

/// L'invitation par code de parrainage — le code, ce qu'il rapporte, et le partage système.
///
/// Existait déjà, mais uniquement dans « Plus de réglages », derrière la molette du Profil.
/// C'est-à-dire à l'endroit où l'on va changer un objectif ou supprimer son compte, et jamais à
/// l'endroit où l'on constate qu'on n'a personne à suivre. La boucle était pourtant complète de
/// bout en bout côté serveur (`users.referral_code` / `referred_by`, `REFERRAL_REWARD_XP`) et
/// côté client (lien profond via `ReferralLinkHandler`, saisie du code à l'inscription) : le seul
/// maillon manquant était de proposer le partage au moment où il a un sens.
///
/// Extrait en composant partagé plutôt que recopié : le texte de partage contient le code, la
/// récompense et l'URL, et deux copies auraient dérivé dès le premier changement de l'une.
struct ReferralInviteCard: View {
    var code: String
    /// Le titre change selon l'endroit : dans un fil vide il doit expliquer pourquoi il est là,
    /// dans les réglages la section porte déjà son nom.
    var title: String?

    /// Une seule définition du message envoyé. `ShareLink` le passe tel quel à la feuille de
    /// partage système, donc il doit se suffire à lui-même dans un SMS comme dans un mail.
    private var shareMessage: String {
        String(localized: "Rejoins-moi sur Valta, mon appli de coaching running — utilise mon code \(code) à l'inscription : https://runup-nu.vercel.app")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(RUFont.sans(13, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
            }
            Text("Invite un ami avec ton code — vous gagnez tous les deux +100 XP dès sa première séance.")
                .font(RUFont.sans(12.5)).foregroundColor(RUColor.text2).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text(code)
                    .font(RUFont.mono(18, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
                    .tracking(2)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .ruCard(radius: 12, fill: RUColor.card2)
                    // Sans ça VoiceOver épelle un code alphanumérique comme un mot, ce qui le
                    // rend impossible à recopier — or c'est exactement ce qu'on demande d'en
                    // faire.
                    .accessibilityLabel("Ton code de parrainage")
                    .accessibilityValue(code.map { String($0) }.joined(separator: " "))
                Spacer(minLength: 0)
                ShareLink(item: shareMessage) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Partager")
                    }
                    .font(RUFont.sans(12.5, weight: .semibold))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(14)
        .ruCard()
    }
}
