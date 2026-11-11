import SwiftUI

/// L'onglet Activité du Club : le mur et le fil des sorties, entrelacés.
///
/// # LE DERNIER MORCEAU DE LA DÉCOUPE, ET LE SEUL QUI A DEMANDÉ AUTRE CHOSE QU'UN DÉPLACEMENT
///
/// Les quatre cartes sorties avant celle-ci ne demandaient zéro ou un état. Le mur en touchait
/// ONZE sur les dix-huit de `ClubView`. Le sortir tel quel aurait transformé une vue longue en
/// une vue longue plus onze fils à ne pas confondre, dans un remaniement qui ne doit RIEN changer.
///
/// Huit de ces onze ont donc un propriétaire — `MurDuClub` — et son en-tête dit pourquoi. Restent
/// les deux qui ne sont PAS du mur : `reportTarget` et `pendingBlock` sont posés aussi par le
/// classement et par la page du club, et les feuilles qui les lisent sont accrochées au corps de
/// `ClubView`, qui reste à l'écran quel que soit l'onglet. Ils passent en liaison, comme ils le
/// faisaient déjà vers `ClubBoardSection`.
///
/// Voir « Chantier 42 » dans `PROGRESS.md`.
struct ClubWallView: View {
    @Environment(AppState.self) private var appState

    let magasin: ClubStore
    @Bindable var mur: MurDuClub

    /// Les deux états de modération de l'écran du Club — pas ceux du mur. Voir l'en-tête.
    @Binding var reportTarget: ReportTarget?
    @Binding var pendingBlock: (userId: String, name: String)?

    private var auth: AuthService { appState.auth }

    var body: some View {
        // `LazyVStack` : le serveur renvoie 50 activités, et un `VStack` les construisait TOUTES
        // à l'ouverture de l'onglet — avatars décodés, deux passes d'ombre par carte, et
        // l'animation de révélation qui tournait sur ~45 lignes hors écran.
        LazyVStack(spacing: 0) {
            composeurDuMur
            if magasin.feed.isEmpty && magasin.posts.isEmpty && !magasin.isLoading {
                // Un fil vide a deux causes très différentes, et un seul message les traitait
                // toutes les deux. Seule dans son club, « sois la première » demande de poster
                // pour un public qui n'existe pas — ce qu'il faut, c'est des membres, et le code
                // d'invitation était rangé deux écrans plus loin, dans Gestion du club. À
                // plusieurs, la phrase d'origine est juste : il n'y a qu'à courir.
                if magasin.seuleDansSonClub {
                    ClubAloneCard(magasin: magasin)
                } else {
                    RUEmpty(message: Accord.selon(
                        f: String(localized: "Personne n'a encore rien posté — sois la première !"),
                        m: String(localized: "Personne n'a encore rien posté — sois le premier !")))
                }
            }
            // ENTRELACÉS PAR DATE, pas empilés en deux listes. Un mur posé au-dessus des
            // sorties se serait lu comme une annonce épinglée ; mêlés, un message de lundi et
            // une sortie de lundi se répondent, et c'est ce qui fait une conversation de club.
            ForEach(Array(MurDuClub.entrees(sorties: magasin.feed, messages: magasin.posts).enumerated()), id: \.element.id) { index, entree in
                switch entree {
                case .sortie(let item):
                    ActivityFeedRow(
                        item: item,
                        isMine: item.userId == auth.currentUser?.id,
                        revealed: mur.filDevoile,
                        index: index,
                        onKudos: { Task { await magasin.toggleKudos(item) } },
                        onComment: { mur.commentsActivity = item },
                        onReport: {
                            reportTarget = ReportTarget(targetType: "activity", targetId: item.id, displayName: String(localized: "l'activité de \(item.nomComplet)"))
                        },
                        onBlock: { pendingBlock = (item.userId, item.name) },
                        onDelete: { mur.pendingDeleteActivity = item },
                        onEdit: { mur.editingActivity = item }
                    )
                case .message(let post):
                    // Plus de filet : `blocDeMessage` est une carte comme les sorties, et c'est
                    // l'écart entre deux cartes qui les sépare — même valeur qu'`ActivityFeedRow`,
                    // pour que l'onglet garde un seul rythme quel que soit le type d'entrée.
                    blocDeMessage(post)
                        .padding(.bottom, 14)
                }
            }
        }
    }

    private var composeurDuMur: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reponseA = mur.reponseA {
                HStack(spacing: 6) {
                    Text("Réponse à \(reponseA.author.nomComplet)")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                    Button(action: { mur.reponseA = nil }) {
                        Image(systemName: "xmark.circle.fill").font(RUFont.icone(.body)).foregroundColor(RUColor.text3)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Annuler la réponse")
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 10) {
                TextField(mur.reponseA == nil
                          ? String(localized: "Dis quelque chose au club…")
                          : String(localized: "Ta réponse…"),
                          text: $mur.brouillon, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                // UN ACCENT ÉTEINT N'EST PAS UN ACCENT DÉSACTIVÉ, C'EST UN ACCENT CASSÉ.
                //
                // Le bouton inactif était le rose de l'app à 35 % : un disque bordeaux terne, qui
                // se lit comme une couleur ratée plutôt que comme un bouton en attente. Inactif,
                // il prend la surface neutre des autres boutons-icônes de l'app ; il ne devient
                // rose qu'au moment où il peut vraiment envoyer.
                Button(action: {
                    // L'ÉTAT D'ENVOI, LE BROUILLON ET LA RÉPONSE EN COURS RESTENT ICI : ce sont
                    // trois choses de l'écran. Le magasin publie et recharge le mur, il rend si
                    // ça a marché, et la vue décide alors de vider ce qui lui appartient.
                    // LE GARDE EST ICI, AVANT LE DRAPEAU, comme il l'était avant le
                    // déménagement : un brouillon vide ne doit pas faire clignoter le bouton en
                    // « envoi en cours » le temps d'un `await` qui ne partira pas.
                    guard mur.peutPublier else { return }
                    mur.envoiEnCours = true
                    Task {
                        let parti = await magasin.publier(texte: mur.brouillon,
                                                          enReponseA: mur.reponseA)
                        mur.envoiEnCours = false
                        if parti {
                            mur.brouillon = ""
                            mur.reponseA = nil
                        }
                    }
                }) {
                    Image(systemName: "arrow.up")
                        .font(RUFont.icone(.medium, weight: .bold))
                        .foregroundColor(mur.peutPublier ? RUColor.onRose : RUColor.text3)
                        .frame(width: 38, height: 38)
                        .background(mur.peutPublier ? AnyShapeStyle(RUColor.rose) : AnyShapeStyle(RUColor.card2), in: Circle())
                        .overlay(Circle().stroke(mur.peutPublier ? Color.clear : RUColor.line, lineWidth: RUSpacing.hairline))
                }
                .buttonStyle(PressableStyle())
                .disabled(!mur.peutPublier)
                .accessibilityLabel("Publier sur le mur du club")
            }
        }
        .padding(.bottom, 18)
    }

    private func blocDeMessage(_ message: ClubPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            enTeteDeMessage(message)
            ForEach(MurDuClub.reponses(a: message, dans: magasin.posts)) { reponse in
                HStack(alignment: .top, spacing: 8) {
                    RUFilet(.vertical)
                    enTeteDeMessage(reponse)
                }
                .padding(.leading, 10)
            }
            HStack(spacing: 18) {
                Button(action: { Task { await magasin.applaudirLeMessage(message) } }) {
                    HStack(spacing: 8) {
                        Image(systemName: message.kudoedByMe ? "hands.clap.fill" : "hands.clap")
                            .font(RUFont.icone(.medium, weight: .regular))
                        if message.kudos > 0 {
                            Text("\(message.kudos)").font(RUFont.sans(.body, weight: .semibold))
                        }
                    }
                    .foregroundColor(message.kudoedByMe ? RUColor.rose : RUColor.text2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(message.kudoedByMe ? "Retirer ton applaudissement" : "Applaudir ce message")

                Button(action: {
                    mur.reponseA = message
                    mur.brouillon = ""
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.right").font(RUFont.icone(.medium, weight: .regular))
                        let compte = MurDuClub.reponses(a: message, dans: magasin.posts).count
                        if compte > 0 {
                            Text("\(compte)").font(RUFont.sans(.body, weight: .semibold))
                        }
                    }
                    .foregroundColor(RUColor.text2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(String(localized: "Répondre à \(message.author.name)"))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // MÊME CARTE QUE LES SORTIES — voir la note jumelle sur `WallView.carteDeCourse`.
        //
        // Ce message du mur partageait le rythme à plat des sorties ; depuis qu'elles sont des
        // cartes, c'est lui qui détonnerait en restant nu, et l'onglet Activité se lirait comme
        // deux listes cousues plutôt que comme une conversation.
        .padding(14)
        .background(RUColor.card)
        .clipShape(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
                .stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline)
        )
    }

    private func enTeteDeMessage(_ message: ClubPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Le bloc d'identité entier ouvre la page de la personne — la photo, le nom et
                // l'heure ensemble, comme partout ailleurs.
                Button(action: { if !message.isMine { appState.ouvrirLeProfil(message.author.id) } }) {
                    HStack(spacing: 8) {
                        AvatarView(urlString: message.author.avatarUrl, base64DataURI: message.author.avatarBase64,
                                   initial: String(message.author.name.prefix(1)), size: 32,
                                   seed: message.isMine ? nil : message.author.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.author.nomComplet)
                                .font(RUFont.sans(.label, weight: .bold))
                                .foregroundColor(RUColor.textPrimary)
                            Text(message.createdAt.relativeDescription)
                                .font(RUFont.sans(.small))
                                .foregroundColor(RUColor.text3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                Spacer(minLength: 0)
                Menu {
                    if message.isMine {
                        Button("Modifier ce message") { mur.messageEnModification = message }
                        Button("Supprimer ce message", role: .destructive) {
                            Task { await magasin.supprimerLeMessage(message) }
                        }
                    } else {
                        Button("Signaler ce message") {
                            reportTarget = ReportTarget(targetType: "club_post", targetId: message.id,
                                                        displayName: message.author.nomComplet)
                        }
                        Button("Bloquer \(message.author.name)", role: .destructive) {
                            pendingBlock = (message.author.id, message.author.name)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(RUFont.icone(.body, weight: .bold))
                        .foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Plus d'options")
            }
            Text(message.text)
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
