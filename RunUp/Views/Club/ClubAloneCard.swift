import SwiftUI

/// « Tu es seule dans ton club » — la carte de partage, partagée par deux onglets.
///
/// Sortie de `ClubView` au troisième morceau de la découpe. Elle ne demande que le magasin,
/// aucune liaison, et deux onglets l'appellent — la raison est écrite sur `body`.
/// Voir « Chantier 37 » dans `PROGRESS.md`.
struct ClubAloneCard: View {
    let magasin: ClubStore

    /// SEULE DANS SON CLUB : LA SEULE CHOSE À FAIRE, ET ELLE EST DITE DEUX FOIS AU MÊME ENDROIT.
    ///
    /// Cette carte vivait dans l'onglet Activité, c'est-à-dire sur le troisième onglet d'un
    /// écran qui s'ouvre sur le premier. Un club d'une personne n'a pourtant qu'un seul sujet —
    /// trouver la deuxième — et l'Aperçu lui répondait par trois sections vides empilées :
    /// « Personne n'a encore couru cette semaine », « Aucun défi en cours », « Aucune sortie
    /// prévue ». Trois fois rien, en trois intertitres de même taille que de vraies sections.
    ///
    /// Elle est donc partagée par les deux onglets plutôt que recopiée : un lien de partage
    /// dupliqué, c'est une des deux copies qui garde l'ancienne URL le jour où elle change.
    var body: some View {
        if let club = magasin.board.club {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: Accord.selon(f: String(localized: "Tu es seule dans \(club.name)"),
                                            m: String(localized: "Tu es seul dans \(club.name)")))
                    .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                // LE LIEN A REMPLACÉ LE CODE.
                //
                // Ce bloc affichait un code à six lettres et proposait de le partager, puis
                // il a dit « cherche son nom dans l'onglet Club » — une consigne, et qui
                // désignait un onglet qui n'existe plus. Il n'y a qu'une chose à envoyer
                // maintenant, et c'est le lien juste en dessous.
                Text("Un club prend vie à plusieurs — classement, défis, sorties de groupe. Envoie son lien aux gens avec qui tu cours.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                    .fixedSize(horizontal: false, vertical: true)
                // UN VRAI LIEN, ENFIN. Ce message disait « cherche-le par son nom dans
                // l'onglet Club » : une consigne, pas une invitation. Le lien ouvre
                // maintenant la page publique du club — sa photo, sa ville, ses
                // prochaines séances — et, sur un iPhone où l'app est installée,
                // directement l'app.
                // LE PAVÉ GRIS DE SOIXANTE-DOUZE POINTS, ET D'OÙ IL VENAIT.
                //
                // `SecondaryButtonStyle` garantit DÉJÀ la cible de 44 points — c'est écrit dans
                // son corps : `.padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 44)`.
                // Le libellé en redemandait 44 de son côté, et les deux ne se recouvrent pas :
                // le style ajoute ses 14 points EN HAUT ET EN BAS d'un libellé déjà haut de 44.
                // D'où 72 points de haut pour le mot « Partager » — un aplat gris qui occupait
                // un tiers de la carte et la faisait ressembler à un formulaire.
                //
                // Et `GhostButtonStyle` plutôt que `Secondary`, parce que c'est le style de
                // partage de la maquette : sa propre documentation cite « Partager ce badge » et
                // « Partager ta course ». Fond de carte, libellé en accent — l'action se voit
                // par sa COULEUR au lieu de se voir par sa masse.
                ShareLink(item: String(localized: "Rejoins mon club \(club.name) sur RUNUP : https://runup-nu.vercel.app/club/\(club.id)")) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Partager")
                    }
                    .font(RUFont.sans(.label, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RUSpacing.cardPadding)
            .ruCard()
        }
    }
}
