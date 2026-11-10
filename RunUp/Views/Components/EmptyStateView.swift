import SwiftUI

/// L'état vide, écrit une fois.
///
/// # LE DÉFAUT
///
/// Règle 3 du brief : chaque écran a ses états vide, erreur et chargement. Règle 4 : rien ne
/// s'écrit deux fois. Ici la seconde perdait — relevé par l'audit du 9 novembre 2026 : « Aucun
/// composant d'état vide partagé. Zéro fichier ne porte un `RUEmpty`. Chaque écran écrit le
/// sien. »
///
/// Et ils divergeaient, mesuré sur trois écrans pris au hasard :
///
///     FriendsView    text3, interligne 3, marge verticale 6 puis 18
///     HistoryView    text2, marge horizontale de page, pas d'interligne
///     ShoesView      text2, interligne 3, marge haute 4
///
/// Deux couleurs de texte différentes pour la même phrase — « il n'y a rien ici » — c'est la
/// définition d'un système de design qui ne couvre pas un cas.
///
/// # DEUX FORMES, ET LE CHOIX N'EST PAS ESTHÉTIQUE
///
/// `.bloc` occupe la place d'un contenu absent : icône, titre, une phrase, éventuellement un
/// bouton. C'est la forme d'un ÉCRAN vide — l'historique sans course, le carnet sans paire.
///
/// `.ligne` ne pose qu'une phrase, parce que la section a déjà son en-tête et que lui ajouter un
/// titre le redirait. C'est la forme d'une SECTION vide à l'intérieur d'un écran qui, lui, a du
/// contenu.
///
/// Remplacer une ligne par un bloc change la mise en page d'un écran qui marchait : le bloc se
/// réserve aux endroits où il n'y a vraiment rien d'autre.
///
/// # CE QU'IL N'EST PAS
///
/// Ni un état d'erreur, ni un état de chargement. « Rien à montrer » et « ça n'a pas marché »
/// sont deux phrases différentes, et les confondre fait dire « aucune course » à quelqu'un dont
/// la requête vient d'échouer.
struct RUEmpty: View {
    enum Forme {
        /// La place d'un contenu absent : icône, titre, phrase, bouton éventuel.
        case bloc
        /// Une phrase seule, sous un en-tête de section qui existe déjà.
        case ligne
    }

    var forme: Forme = .bloc
    /// Facultative, et absente en `.ligne` : un symbole au-dessus d'une phrase isolée au milieu
    /// d'un écran rempli attire l'œil sur ce qui manque plutôt que sur ce qui est là.
    var icone: String?
    /// Facultatif pour la même raison.
    var titre: String?
    var message: String
    /// Le geste qui sort de l'état vide, quand il y en a un. « Aucune course » sans « ajouter une
    /// course » laisse quelqu'un devant une page morte.
    var action: (libelle: String, faire: () -> Void)?

    var body: some View {
        switch forme {
        case .ligne:
            Text(message)
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
        case .bloc:
            VStack(spacing: 10) {
                if let icone {
                    Image(systemName: icone)
                        // `.hero` ET PAS `.xlarge`, PARCE QUE LE SYSTÈME LE DIT.
                        //
                        // `RUIconSize.hero` vaut 28 et sa documentation est sans ambiguïté :
                        // « l'icône d'un état vide, celle qu'on voit avant même de lire ». Ce
                        // composant utilisait `.xlarge` (22) — et les trois états vides écrits à
                        // la main dans les écrans, eux, utilisaient bien `.hero`. Le composant
                        // partagé était le seul à ne pas suivre le cran que le système nomme pour
                        // lui, ce qui est le comble pour la pièce censée mettre tout le monde
                        // d'accord.
                        .font(RUFont.icone(.hero))
                        .foregroundColor(RUColor.text3)
                        .accessibilityHidden(true)
                }
                if let titre {
                    Text(titre)
                        .font(RUFont.sans(.emphasis, weight: .medium))
                        .foregroundColor(RUColor.textPrimary)
                        .multilineTextAlignment(.center)
                }
                Text(message)
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text3)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.libelle, action: action.faire)
                        .buttonStyle(GhostButtonStyle())
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            // Le titre, la phrase et l'icône décrivent UNE chose : trois arrêts VoiceOver pour
            // un seul état vide, c'est trois fois le même contexte relu. Même raison que
            // `RUCardHeader`.
            .accessibilityElement(children: .combine)
        }
    }
}
