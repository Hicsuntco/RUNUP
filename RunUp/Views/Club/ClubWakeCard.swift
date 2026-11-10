import SwiftUI

/// « Rien n'est lancé pour l'instant » — les deux actions qui réveillent un club.
///
/// Sortie de `ClubView` au troisième morceau de la découpe. Elle ne touche PAS au magasin : elle
/// n'affiche aucune donnée du club, seulement deux boutons. D'où ses deux liaisons et rien
/// d'autre. Voir « Chantier 37 » dans `PROGRESS.md`.
struct ClubWakeCard: View {
    @Binding var showCreateEvent: Bool
    @Binding var showManagement: Bool

    /// À plusieurs, mais rien de lancé. Les deux actions sont celles que portaient les
    /// intertitres de « Défi du club » et « Sorties de groupe » — elles ne sont pas perdues avec
    /// les sections, elles sont réunies là où quelqu'un les cherchera.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rien n'est lancé pour l'instant")
                .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            Text("Un défi à se partager, ou une sortie à proposer : c'est ce qui donne au club une raison de se retrouver cette semaine.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                .fixedSize(horizontal: false, vertical: true)
            // PAS DE `minHeight: 44` ICI. `SecondaryButtonStyle` garantit déjà la cible de 44
            // points — c'est écrit dans son corps : `.padding(.vertical, 14)` et
            // `.frame(maxWidth: .infinity, minHeight: 44)`. Le redemander dans le libellé ne se
            // recouvre pas, ça s'EMPILE : les 14 points du style s'ajoutent en haut et en bas
            // d'un libellé déjà haut de 44, et le mot devient un pavé de 72 points de haut.
            //
            // Le renvoi était « voir la note sur le bouton Partager plus bas » ; cette note est
            // partie dans `ClubAloneCard.swift` avec sa carte, et un renvoi à « plus bas » ne
            // survit pas à une découpe. Elle est donc recopiée ici en entier.
            HStack(spacing: 10) {
                Button(action: { showManagement = true }) {
                    Text("Créer un défi")
                        .font(RUFont.sans(.label, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                Button(action: { showCreateEvent = true }) {
                    Text("Proposer une sortie")
                        .font(RUFont.sans(.label, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }
}
