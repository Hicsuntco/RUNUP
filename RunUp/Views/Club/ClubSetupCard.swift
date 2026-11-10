import SwiftUI

/// L'écran de quelqu'un qui n'a pas encore de club : en créer un, ou en chercher un.
///
/// Sortie de `ClubView` au quatrième morceau de la découpe. Tout passe par le magasin — créer,
/// chercher, charger les clubs proposés — donc elle ne demande que lui et les deux champs de
/// saisie. Voir « Chantier 38 » dans `PROGRESS.md`.
struct ClubSetupCard: View {
    let magasin: ClubStore
    @Binding var newClubName: String
    @Binding var clubQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                RUCardHeader(icon: "plus.circle.fill", title: "Créer un club", subtitle: "Tu en seras l'administratrice")
                HStack {
                    TextField("Nom du club", text: $newClubName)
                        .textFieldStyle(.plain)
                        .font(RUFont.sans(.emphasis))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    Button("Créer") {
                        Task { if await magasin.createClub(nom: newClubName) { newClubName = "" } }
                    }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: newClubName.trimmingCharacters(in: .whitespaces).isEmpty || magasin.isLoading))
                        .disabled(newClubName.trimmingCharacters(in: .whitespaces).isEmpty || magasin.isLoading)
                }
            }

            // ON CHERCHE UN CLUB PAR SON NOM.
            //
            // Ce bloc demandait un code à six lettres. Un code suppose qu'on l'ait reçu de
            // quelqu'un — donc qu'on sache déjà que le club existe et comment il s'appelle,
            // c'est-à-dire tout ce qu'une recherche rend inutile. Et il fallait le taper sans se
            // tromper, sur un champ en capitales, pour une erreur qui ne disait que
            // « introuvable ».
            VStack(alignment: .leading, spacing: 6) {
                RUCardHeader(icon: "magnifyingglass", title: "Rejoindre un club")
                TextField("Chercher par son nom", text: $clubQuery)
                    .textFieldStyle(.plain)
                    .font(RUFont.sans(.emphasis))
                    .foregroundColor(RUColor.textPrimary)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

                let rienDeTape = clubQuery.trimmingCharacters(in: .whitespaces).isEmpty

                if magasin.clubSearchEnCours {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                } else if !rienDeTape, magasin.clubResultats.isEmpty {
                    RUEmpty(forme: .ligne,
                            message: String(localized: "Aucun club ouvert ne porte ce nom."))
                        .padding(.vertical, 8)
                }

                // RIEN DE TAPÉ : ON PROPOSE, AU LIEU DE NE RIEN MONTRER.
                //
                // Le champ exige deux caractères du NOM. Il suppose donc qu'on sache déjà qu'un
                // club existe et comment il s'appelle — exactement le reproche qui avait fait
                // retirer le code d'invitation à six lettres, deux crans plus loin.
                //
                // Les mêmes lignes que la recherche, pas une autre vue : une suggestion doit
                // ressembler à ce qu'on aurait trouvé en cherchant, sinon ce n'est plus la même
                // porte.
                if rienDeTape, !magasin.clubSuggestions.isEmpty {
                    Text("Ou rejoins-en un ouvert")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .padding(.top, 6)
                    ForEach(magasin.clubSuggestions) { suggere in
                        ligneDUnClubARejoindre(suggere)
                    }
                }

                ForEach(magasin.clubResultats) { trouve in
                    ligneDUnClubARejoindre(trouve)
                }
            }
            .task { await magasin.chargerLesClubsSuggeres() }
        }
        .padding(18)
        .ruCard()
    }

    /// « Lyon · 18 membres », ou le compte seul quand le club n'a pas dit où il court.
    /// LA MÊME LIGNE POUR LES DEUX LISTES — celle qu'on a cherchée et celle qu'on propose.
    ///
    /// Deux vues presque identiques auraient dérivé à la première retouche, et l'écart se serait
    /// lu comme une différence de nature entre un club trouvé et un club proposé. Il n'y en a
    /// pas : c'est le même club, et le même appui le rejoint.
    private func ligneDUnClubARejoindre(_ trouve: ClubSearchResult) -> some View {
        Button(action: { Task { if await magasin.joinClub(trouve) { clubQuery = "" } } }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trouve.name)
                        .font(RUFont.sans(.label, weight: .medium))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1)
                    // Le nombre de membres n'est pas décoratif : rien n'empêche deux clubs de
                    // porter le même nom, et c'est ce qui les distingue. LA VILLE AVANT LE
                    // COMPTE, pour la même raison en plus fort : entre deux « Foulées du Canal »,
                    // c'est elle qui dit laquelle est la sienne.
                    Text(ligneDuClubTrouve(trouve))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("Rejoindre")
                    .font(RUFont.sans(.body, weight: .semibold))
                    .foregroundColor(RUColor.rose2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(magasin.isLoading)
    }

    /// CE QUE LA LIGNE DIT SOUS LE NOM, et dans quel ordre.
    ///
    /// Une suggestion porte SA RAISON d'être là, avant la ville et le compte : « une liste de
    /// noms sans explication ressemble à un annuaire, et on ne suit pas un annuaire » — c'est la
    /// règle déjà écrite pour les suggestions de personnes, et c'est le même problème.
    ///
    /// Une séance à venir passe devant un mur actif : l'une dit où se présenter samedi, l'autre
    /// seulement que le club n'est pas mort. Un club cherché, lui, n'a aucune raison à donner :
    /// on l'a demandé par son nom.
    private func ligneDuClubTrouve(_ trouve: ClubSearchResult) -> String {
        let membres = Pluriel.choisir(trouve.memberCount,
                                      String(localized: "\(trouve.memberCount) membre"),
                                      String(localized: "\(trouve.memberCount) membres"))
        var morceaux: [String] = []
        if trouve.seancePrevue == true {
            morceaux.append(String(localized: "Une séance prévue"))
        } else if trouve.actifRecemment == true {
            morceaux.append(String(localized: "Actif ces jours-ci"))
        }
        if let ville = trouve.city, !ville.isEmpty { morceaux.append(ville) }
        morceaux.append(membres)
        return morceaux.joined(separator: " · ")
    }
}
