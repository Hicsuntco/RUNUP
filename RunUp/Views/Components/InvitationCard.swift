import SwiftUI

/// L'invitation à rejoindre RUNUP — le partage système, et rien d'autre.
///
/// # CE QU'ELLE ÉTAIT, ET POURQUOI ELLE A CHANGÉ
///
/// C'était `ReferralInviteCard` : elle affichait un code de parrainage à six lettres, ce qu'il
/// rapportait aux deux côtés, et le partageait. La boucle existait de bout en bout — un code par
/// compte, un lien profond `/r/CODE`, un champ à l'inscription, une récompense en XP à la
/// première vraie sortie de la personne parrainée.
///
/// Elle a été retirée. Un code suppose qu'on ait quelque chose à récompenser et quelqu'un pour le
/// réclamer : à l'échelle où l'app en est, il ajoutait un champ à l'inscription, une ligne sur
/// chaque carte de partage et une branche dans la création de compte, pour un geste que personne
/// n'a fait. L'invitation, elle, reste — c'est le seul maillon qui avait un sens sans le reste.
///
/// Ce qui disparaît avec lui : la saisie à l'inscription, le lien `/r/CODE`, la mention sur la
/// carte de partage, et la récompense. Les colonnes `referral_code` / `referred_by` restent en
/// base — elles portent l'histoire de qui a été parrainé par qui, et une colonne supprimée ne se
/// retrouve pas.
struct InvitationCard: View {
    /// Le titre change selon l'endroit : dans un fil vide il doit expliquer pourquoi il est là,
    /// dans les réglages la section porte déjà son nom.
    var title: String?

    /// Une seule définition du message envoyé. `ShareLink` le passe tel quel à la feuille de
    /// partage système, donc il doit se suffire à lui-même dans un SMS comme dans un mail.
    private var shareMessage: String {
        String(localized: "Rejoins-moi sur RUNUP, mon appli de coaching running : https://runup-nu.vercel.app")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(RUFont.sans(.label, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
            }
            Text("Ton club se remplit plus vite à deux.")
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text2)
            ShareLink(item: shareMessage) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Inviter un ami")
                        .font(RUFont.sans(.body, weight: .semibold))
                }
                .foregroundColor(RUColor.onRose)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(RUColor.rose, in: Capsule())
            }
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }
}
