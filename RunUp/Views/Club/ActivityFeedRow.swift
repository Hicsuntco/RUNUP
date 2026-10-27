import SwiftUI

/// Une activité publiée dans un fil — applaudissements, commentaires, et selon l'auteur :
/// suppression et édition pour la sienne, signalement et blocage pour celle des autres. Partagée
/// entre le « Fil d'activité » de `ClubView` (les membres du club) et celui de `FriendsView` (les
/// personnes suivies) : les deux rendent le même `FeedItem`, publié par les mêmes points d'entrée
/// `api/activities/*.js`, atteint par une relation différente (voir `canViewActivity` dans
/// `lib/social.js`). La carte n'a donc pas à savoir dans lequel des deux elle se trouve.
///
/// # Deux têtes, une seule carte
///
/// Quand la sortie porte un tracé, il devient le sujet : plein cadre, sur fond sombre, le nom et
/// les chiffres posés dessus. C'est la seule IMAGE qu'une course produit, et un fil sans images
/// n'est pas un fil, c'est une liste.
///
/// Quand elle n'en porte pas — pas de GPS, sortie trop courte pour survivre au rognage de
/// confidentialité, tracé retiré après coup, ou simplement un badge — la carte reprend sa
/// composition d'origine : en-tête, phrase, rangée de chiffres. Elle doit rester bonne à regarder,
/// pas devenir le trou laissé par une image absente.
struct ActivityFeedRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// L'éclat du double-tape. Local à la carte : deux posts applaudis coup sur coup doivent
    /// pouvoir s'animer chacun chez soi.
    @State private var eclat = false
    var item: FeedItem
    var isMine: Bool
    var revealed: Bool
    var index: Int
    var onKudos: () -> Void
    var onComment: () -> Void
    var onReport: () -> Void
    var onBlock: () -> Void
    var onDelete: () -> Void
    var onEdit: () -> Void
    /// « ton club », « tu la suis », « toi » — pourquoi cette sortie est dans le fil qu'on lit.
    ///
    /// Déclaré EN DERNIER et avec une valeur par défaut : les trois appels existants ne le passent
    /// pas, et l'initialiseur mémoire d'une structure Swift exige l'ordre de déclaration. Nil dans
    /// un fil d'un seul genre, où la provenance serait une évidence répétée à chaque carte — dans
    /// le fil du club, tout vient du club.
    var sourceLabel: String? = nil

    /// Le fond du bandeau de tracé est sombre dans les DEUX thèmes, volontairement. Une ligne fine
    /// et colorée se lit sur du sombre ; sur un fond clair elle devient un gribouillis pâle. C'est
    /// le seul endroit de l'app qui ne suit pas le thème, et c'est un choix, pas un oubli.
    private static let traceBackground = LinearGradient(
        colors: [Color(hex: 0x1A1926), Color(hex: 0x0E0D16)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private var trace: [RunRecord.RoutePoint]? {
        guard let route = item.routePreview, route.count > 1 else { return nil }
        return route
    }

    private var photo: URL? {
        guard let brut = item.photoUrl, !brut.isEmpty else { return nil }
        return URL(string: brut)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // UN FILET ENTRE DEUX POSTS, ET RIEN AUTOUR.
            //
            // La carte est partie. Une sortie n'est pas un objet posé sur la page — c'est la page.
            // Un rectangle arrondi avec son fond et son contour autour de chaque post fabrique une
            // pile de tuiles qu'on parcourt ; un filet fin entre deux posts fabrique un fil qu'on
            // descend. C'est la différence entre un tableau de bord et Instagram, et elle tient à
            // ça.
            //
            // Le filet est EN TÊTE de chaque post sauf le premier, pas en pied : un filet en pied
            // flotterait tout seul après le dernier, sous rien.
            if index > 0 {
                Rectangle()
                    .fill(RUColor.line)
                    .frame(height: RUSpacing.hairline)
                    .padding(.bottom, 16)
            }

            VStack(alignment: .leading, spacing: 11) {
                // LE NOM AU-DESSUS DE L'IMAGE, ET NON PLUS DESSUS.
                //
                // Il était posé SUR le bandeau, ce qui obligeait à deux voiles dégradés pour que du
                // blanc reste lisible sur n'importe quelle photo — un ciel de midi, de la neige.
                // Au-dessus, le texte est sur le fond de l'app : il est lisible par construction,
                // les deux voiles disparaissent, et la photo n'est plus assombrie à ses deux bouts
                // pour servir de support à du texte. Moins de pièces, et la photo entière.
                HStack(spacing: 10) {
                    author(onDark: false)
                    Spacer(minLength: 0)
                    menuDuPost
                }

                media
                    // BORD À BORD, ET C'EST LE GESTE QUI FAIT LA DIFFÉRENCE.
                    //
                    // L'image était posée DANS la colonne de texte, avec ses coins arrondis et
                    // les marges de page de chaque côté. C'est la mise en page d'un tableau de
                    // bord : une vignette illustrant une ligne. Instagram, Strava et tout ce qui
                    // se parcourt au pouce font l'inverse — l'image touche les deux bords, et
                    // c'est elle qui tient la page pendant que le texte s'aligne autour.
                    //
                    // Les quatre écrans qui affichent cette ligne (le fil, les amis, l'activité
                    // du club, la page de quelqu'un) posent tous exactement
                    // `RUSpacing.pagePadding` horizontalement : une marge négative de la même
                    // valeur la ramène donc au bord de l'écran dans les quatre, sans qu'aucun
                    // d'eux ait à le savoir.
                    .padding(.horizontal, -RUSpacing.pagePadding)
                    // LE DOUBLE-TAPE SUR L'IMAGE : le geste par lequel on aime, partout, depuis
                    // dix ans. Il n'enlève jamais un applaudissement — sur Instagram comme ici,
                    // double-taper une photo déjà aimée ne la dés-aime pas : ce serait punir
                    // l'enthousiasme. Le bouton applaudir reste le seul chemin pour retirer.
                    .overlay { eclatDApplaudissement }
                    .onTapGesture(count: 2) { applaudirParDoubleTape() }

                // LA PHRASE ET LES CHIFFRES OUVRENT LA SORTIE.
                //
                // Une carte de fil était un cul-de-sac : quatre chiffres, et rien derrière. Les
                // kilomètres un par un, le profil du terrain et le cardio existaient sur
                // l'appareil de qui avait couru sans jamais en sortir. C'est ce bloc-ci qui est
                // la porte — pas l'image, qui porte déjà le double-tape, ni le nom, qui mène à
                // la personne. Trois zones, trois destinations, aucune ambiguïté.
                Button(action: { appState.ouvrirLaSortie(item.id) }) {
                    VStack(alignment: .leading, spacing: 11) {
                        Text(item.localizedText)
                            .font(RUFont.sans(.label))
                            .foregroundColor(RUColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if item.hasMetrics {
                            HStack(spacing: 10) {
                                metricsRow
                                if item.isPersonalRecord { recordBadge(onDark: false) }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .combine)
                .accessibilityHint("Ouvre la sortie en détail")

                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(RUFont.sans(.emphasis, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actions

                if let liked = likedByLine {
                    Text(liked)
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let last = item.lastComment {
                    // Une carte qui affiche « 💬 2 » oblige à ouvrir une feuille pour savoir si ces
                    // deux commentaires valent le détour. Celle-ci répond sur place.
                    (Text(last.name).font(RUFont.sans(.small, weight: .bold))
                     + Text(verbatim: "  ")
                     + Text(last.text).font(RUFont.sans(.small)))
                        .foregroundColor(RUColor.text2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 16)
        }
        .opacity(revealed ? 1 : 0)
        .offset(x: revealed ? 0 : -14)
        .animation(.easeOut(duration: 0.35).delay(Double(min(index, 8)) * 0.05), value: revealed)
        // Le même menu sous l'appui long, pour qui connaît le geste. Les trois points l'ont rendu
        // trouvable ; ils ne le remplacent pas.
        .contextMenu {
            if isMine {
                Button("Modifier ma sortie", action: onEdit)
                Button("Supprimer cette activité", role: .destructive, action: onDelete)
            } else {
                Button("Signaler cette activité", action: onReport)
                Button("Bloquer \(item.name)", role: .destructive, action: onBlock)
            }
        }
    }

    // MARK: - L'image

    /// LA PHOTO D'ABORD, LE TRACÉ SINON, RIEN QUAND IL N'Y A RIEN.
    ///
    /// Un post a une image ou n'en a pas. Quand une sortie porte les deux, c'est la photo qu'on est
    /// venu voir ; le tracé reprend sa place en vignette dans le coin, comme la carte incrustée
    /// d'un post Strava. Et une sortie sans photo ni tracé — une séance de renfo, un badge — n'a
    /// pas de bloc d'image du tout, au lieu d'un rectangle vide qui tiendrait la place.
    @ViewBuilder
    private var media: some View {
        if let photo {
            image(photo)
        } else if let trace {
            banniereDeTrace(trace)
        }
    }

    private func image(_ url: URL) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            // Le fond du tracé plutôt qu'un vide : il tient la place à la bonne couleur pendant
            // que l'image arrive, au lieu de faire sauter la mise en page à son arrivée.
            ZStack {
                Self.traceBackground
                ProgressView().tint(.white)
            }
        }
        // 4:5, le format le plus haut qu'Instagram accepte — c'est lui qui remplit l'écran d'un
        // téléphone sans avaler le post suivant. Fixe, et non la hauteur de l'image : des posts de
        // hauteurs différentes font sauter le fil à chaque chargement.
        .aspectRatio(4.0 / 5.0, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .clipped()
        // Plus de coins arrondis : l'image touche maintenant les deux bords de l'écran, et un
        // coin arrondi contre un bord d'écran se lit comme une image mal découpée, pas comme un
        // objet posé. Même raison qu'au bandeau de tracé.
        .overlay(alignment: .bottomTrailing) {
            if let trace {
                RouteThumbnail(route: trace, lineWidth: 2, lineColor: .white, showsStart: false)
                    .frame(width: 52, height: 52)
                    .padding(7)
                    .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: RUSpacing.radiusTile, style: .continuous))
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Photo de la sortie"))
    }

    /// La main qui s'ouvre au centre de l'image, une demi-seconde. Sans elle, un double-tape
    /// réussi ne se distingue pas d'un double-tape manqué : le compteur bouge de un, sous le pli,
    /// là où le doigt vient de passer.
    private var eclatDApplaudissement: some View {
        Image(systemName: "hands.clap.fill")
            .font(.system(size: 72))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 14)
            .scaleEffect(eclat ? 1 : 0.5)
            .opacity(eclat ? 1 : 0)
            .allowsHitTesting(false)
    }

    private func applaudirParDoubleTape() {
        guard !item.kudoedByMe else {
            // Déjà applaudi : on ne fait rien côté serveur, mais la main repasse quand même.
            // Un geste qui ne répond pas se lit comme un geste qui n'a pas été vu.
            jouerLEclat()
            return
        }
        onKudos()
        Haptics.impact(.light)
        jouerLEclat()
    }

    private func jouerLEclat() {
        // Sous « Réduire les animations », l'éclat apparaît et disparaît sans ressort : le geste
        // garde son accusé de réception, c'est le rebond qui part.
        let entree: Animation = reduceMotion ? .easeOut(duration: 0.12)
                                             : .spring(response: 0.28, dampingFraction: 0.5)
        withAnimation(entree) { eclat = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(480))
            withAnimation(.easeOut(duration: 0.22)) { eclat = false }
        }
    }

    /// Le tracé, quand il n'y a pas de photo. Le fond reste sombre dans les DEUX thèmes,
    /// volontairement : une ligne fine et colorée se lit sur du sombre ; sur un fond clair elle
    /// devient un gribouillis pâle.
    private func banniereDeTrace(_ trace: [RunRecord.RoutePoint]) -> some View {
        ZStack {
            Self.traceBackground
            SelfDrawingRoute(
                route: trace,
                lineWidth: 3.5,
                colors: [RUColor.rose, RUColor.violet],
                targetPoints: 140,
                showsStart: true
            )
            .padding(20)
        }
        // 190 → 4:3. Le bandeau de tracé était SQUAT : cent quatre-vingt-dix points de haut
        // pendant que la branche photo, dix lignes plus haut, tient un 4:5 — soit près du double.
        // Deux traitements pour la même place dans la même ligne, et c'est le tracé qui perdait,
        // alors que c'est lui qu'on a presque toujours (une sortie sans photo en a quand même un).
        //
        // 4:3 et non 4:5 : une trace GPS n'est pas un portrait. Étirée sur cinq quarts, elle
        // flotte au milieu d'un rectangle vide — ce qu'on veut, c'est qu'elle remplisse.
        .aspectRatio(4.0 / 3.0, contentMode: .fill)
    }

    /// Les trois points, à la place du menu contextuel caché sous un appui long.
    ///
    /// Il n'existait QUE sous un appui long sur la carte — un geste que personne ne découvre, et
    /// le seul chemin vers « signaler » et « bloquer ». Sur un fil public, la modération ne peut
    /// pas être un geste qu'on devine. Le menu long reste, pour qui le connaît.
    private var menuDuPost: some View {
        Menu {
            if isMine {
                Button("Modifier ma sortie", action: onEdit)
                Button("Supprimer cette activité", role: .destructive, action: onDelete)
            } else {
                Button("Signaler cette activité", action: onReport)
                Button("Bloquer \(item.name)", role: .destructive, action: onBlock)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(RUColor.text3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Plus d'options")
    }

    // MARK: - Pièces communes

    /// TOUT LE BLOC D'IDENTITÉ OUVRE LA PAGE DE LA PERSONNE — photo, nom et heure ensemble.
    ///
    /// Viser le seul nom serait une cible de la largeur d'un mot au milieu d'une carte ; et c'est
    /// la photo qu'on vise spontanément. Sur sa propre sortie, rien ne s'ouvre : on est déjà à
    /// deux onglets de son profil, et un aller-retour vers soi-même n'apprend rien.
    private func author(onDark: Bool) -> some View {
        Button(action: { if !isMine { appState.ouvrirLeProfil(item.userId) } }) {
            HStack(spacing: 9) {
                AvatarView(urlString: item.avatarUrl, base64DataURI: item.avatarBase64,
                           initial: String(item.name.prefix(1)), size: 32, seed: isMine ? nil : item.userId)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(RUFont.sans(.label, weight: .bold))
                        .foregroundColor(onDark ? .white : RUColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    HStack(spacing: 5) {
                        Text(timeLine)
                            .font(RUFont.sans(.small))
                            .foregroundColor(onDark ? .white.opacity(0.7) : RUColor.text3)
                        // LA PROVENANCE, posée sous le nom. Dans un fil mélangé, « ton club » ou
                        // « tu la suis » est ce qui répond à « pourquoi cette personne est là ? ».
                        // Sans elle, un fil unique redevient un annuaire.
                        if let sourceLabel {
                            Text(verbatim: "·")
                                .font(RUFont.sans(.small))
                                .foregroundColor(onDark ? .white.opacity(0.45) : RUColor.text3)
                            Text(sourceLabel)
                                .font(RUFont.sans(.small, weight: .semibold))
                                .foregroundColor(onDark ? .white.opacity(0.78) : RUColor.text2)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(isMine)
        .accessibilityLabel(isMine ? item.name : String(localized: "Voir le profil de \(item.name)"))
    }

    /// « il y a 2 h », et « · modifié » dès qu'un texte a changé.
    ///
    /// Affiché plutôt que caché : un fil où une phrase peut changer sans laisser de trace est un
    /// fil dont on ne peut rien citer.
    private var timeLine: String {
        let when = item.createdAt.relativeDescription
        guard item.editedAt != nil else { return when }
        return when + " · " + String(localized: "modifié")
    }

    /// La pastille de record vit dans l'en-tête, à l'opposé du nom, et pas dans la rangée de
    /// mesures — c'est un fait sur la sortie entière, pas une cinquième mesure. Elle n'apparaît que
    /// quand la sortie a réellement battu la plus longue distance ou la meilleure allure (voir
    /// `RunRecord.beatsPersonalRecord`).
    private func recordBadge(onDark: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill").font(.system(size: 8, weight: .bold))
            Text("RECORD")
        }
        .font(RUFont.sans(.micro, weight: .bold))
        .tracking(0.4)
        .foregroundColor(onDark ? .white : RUColor.rose)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(onDark ? AnyShapeStyle(Color.white.opacity(0.18))
                                          : AnyShapeStyle(Color.black.opacity(0.05))))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Record personnel")
    }

    /// « Aimé par Sofia, Marc et 5 autres » — ce qui fait d'un compte des gens.
    ///
    /// `nil` quand le serveur n'a renvoyé aucun nom : une version antérieure du serveur, ou
    /// personne qui ait applaudi. Le compte reste affiché à côté du bouton, lui.
    private var likedByLine: String? {
        let names = Array(item.kudosNames.prefix(3))
        guard !names.isEmpty else { return nil }
        // `ListFormatter` sait joindre « a, b et c » dans la langue courante — « a, b and c » en
        // anglais, « a, b y c » en espagnol. Une virgule et un « et » écrits à la main ne le
        // savent pas.
        let list = ListFormatter.localizedString(byJoining: names)
        let others = max(0, item.kudos - names.count)
        switch others {
        case 0: return String(localized: "Aimé par \(list)")
        case 1: return String(localized: "Aimé par \(list) et une autre personne")
        default: return String(localized: "Aimé par \(list) et \(others) autres")
        }
    }

    /// Actions sans pastille ni contour : dans une carte, deux gros boutons bordés pèsent plus
    /// lourd que l'activité elle-même. La cible tactile reste à 44 pt via `frame(minHeight:)` +
    /// `contentShape` — c'est le chrome qui disparaît, pas la zone tapable.
    /// DES TRAITS, PAS DES EMOJIS.
    ///
    /// L'applaudissement était un 👏 — l'élément le moins épuré de la carte, et le seul qui change
    /// de dessin selon la version d'iOS. Un symbole système garde exactement le sens
    /// (« applaudir », pas « aimer » : ce n'est pas la même chose dans une app de course) et
    /// adopte la graisse du reste de l'interface. Plein quand c'est fait, en trait sinon — la
    /// grammaire d'Instagram, où un cœur vide et un cœur plein sont la même icône.
    ///
    /// Le crayon de « Modifier » est parti : il vit maintenant dans les trois points en tête du
    /// post, avec « Supprimer ». Deux chemins pour la même action sur la même carte, dont un en
    /// doublon du menu, n'est pas de la redondance utile — c'est une icône de plus à lire.
    private var actions: some View {
        HStack(spacing: 18) {
            Button(action: {
                Haptics.impact(.light)
                onKudos()
            }) {
                HStack(spacing: 7) {
                    Image(systemName: item.kudoedByMe ? "hands.clap.fill" : "hands.clap")
                        .font(.system(size: 15, weight: .regular))
                    if item.kudos > 0 {
                        Text("\(item.kudos)")
                            .font(RUFont.sans(.body, weight: .semibold))
                            .contentTransition(.numericText())
                    }
                }
                .foregroundColor(item.kudoedByMe ? RUColor.rose : RUColor.text2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .scaleEffect(item.kudoedByMe ? 1.06 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.45), value: item.kudoedByMe)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(item.kudoedByMe ? "Retirer ton applaudissement" : "Applaudir cette séance")
            .accessibilityValue("\(item.kudos)")

            Button(action: onComment) {
                HStack(spacing: 7) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 15, weight: .regular))
                    if item.commentsCount > 0 {
                        Text("\(item.commentsCount)")
                            .font(RUFont.sans(.body, weight: .semibold))
                    }
                }
                .foregroundColor(RUColor.text2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Voir les commentaires")
            .accessibilityValue("\(item.commentsCount)")

            Spacer(minLength: 0)
        }
    }

    /// `.feed-stats` de la maquette : les chiffres de la sortie, alignés à gauche, séparés par des
    /// filets verticaux. Les colonnes ABSENTES ne laissent pas de trou — une séance de renfo sans
    /// distance montre juste la durée, et la rangée entière disparaît quand il n'y a rien à
    /// montrer (`hasMetrics`). C'est pour ça que les filets sont insérés entre les colonnes
    /// construites, et pas posés à des positions fixes.
    private struct Metric: Identifiable {
        var id: String { label }
        var value: String
        var label: String
    }

    private var metrics: [Metric] {
        var result: [Metric] = []
        if let distanceKm = item.distanceKm {
            result.append(Metric(value: String(format: "%.1f", locale: Locale.current, distanceKm), label: "km"))
        }
        // L'ALLURE N'EST PLUS ACCENTUÉE. Elle l'était parce que c'est le chiffre qu'on compare
        // — vrai sur une carte isolée. Dans un fil, la même colonne revient à chaque post : un
        // chiffre rose tous les cinq centimètres, en ligne verticale, sur toute la hauteur du
        // défilement. L'accent ne désignait plus rien, il peignait une colonne.
        if let avgPace = item.avgPace {
            result.append(Metric(value: avgPace, label: "allure"))
        }
        if let durationDisplay = item.durationDisplay {
            result.append(Metric(value: durationDisplay, label: "temps"))
        }
        if let elevationGainM = item.elevationGainM {
            result.append(Metric(value: "\(elevationGainM) m", label: "D+"))
        }
        return result
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            ForEach(metrics) { metric in
                if metric.id != metrics.first?.id {
                    Rectangle()
                        .fill(RUColor.line)
                        .frame(width: RUSpacing.hairline, height: 26)
                        .padding(.horizontal, 12)
                }
                MetricColumn(
                    value: metric.value,
                    label: metric.label,
                    valueColor: RUColor.textPrimary,
                    valueSize: 16
                )
            }
            Spacer(minLength: 0)
        }
    }
}
