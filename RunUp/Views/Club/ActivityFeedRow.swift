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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let trace {
                traceHead(trace)
            } else {
                plainHead
            }

            VStack(alignment: .leading, spacing: 9) {
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(RUFont.sans(.emphasis, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

                Rectangle()
                    .fill(RUColor.line)
                    .frame(height: RUSpacing.hairline)

                actions
            }
            .padding(RUSpacing.cardPadding)
        }
        .ruCard()
        .opacity(revealed ? 1 : 0)
        .offset(x: revealed ? 0 : -14)
        .animation(.easeOut(duration: 0.35).delay(Double(min(index, 8)) * 0.05), value: revealed)
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

    // MARK: - Avec tracé

    private func traceHead(_ trace: [RunRecord.RoutePoint]) -> some View {
        ZStack {
            Self.traceBackground
            RouteThumbnail(
                route: trace,
                lineWidth: 3.5,
                gradientColors: [RUColor.rose, RUColor.violet],
                showsStart: true,
                targetPoints: 80
            )
            // Les marges hautes et basses réservent la place du nom et des chiffres posés
            // par-dessus : le tracé ne passe jamais SOUS un texte, il s'arrête avant.
            .padding(EdgeInsets(top: 44, leading: 18, bottom: 50, trailing: 18))
        }
        .frame(height: 192)
        .overlay(alignment: .topLeading) { author(onDark: true).padding(12) }
        .overlay(alignment: .topTrailing) {
            if item.isPersonalRecord { recordBadge(onDark: true).padding(12) }
        }
        .overlay(alignment: .bottomLeading) { heroStats.padding(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14)) }
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: RUSpacing.radiusStandard,
            topTrailingRadius: RUSpacing.radiusStandard,
            style: .continuous
        ))
    }

    /// Trois chiffres au plus, en grand, sur le tracé. Pas quatre : le dénivelé est la mesure dont
    /// on se passe le mieux d'un coup d'œil, et la rangée complète vit toujours dans la carte sans
    /// tracé.
    private var heroStats: some View {
        HStack(alignment: .lastTextBaseline, spacing: 18) {
            ForEach(metrics.prefix(3)) { metric in
                VStack(alignment: .leading, spacing: 0) {
                    Text(metric.value)
                        .font(RUFont.display(22))
                        .foregroundColor(.white)
                    Text(LocalizedStringKey(metric.label))
                        .font(RUFont.sans(.micro, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.62))
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Sans tracé

    private var plainHead: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                author(onDark: false)
                Spacer(minLength: 0)
                if item.isPersonalRecord { recordBadge(onDark: false) }
            }
            // La phrase commence par un verbe conjugué (« a couru 8,2 km · Sortie longue ») : elle
            // reste rattachée au nom au-dessus, mais sur sa propre ligne.
            //
            // `localizedText` et pas `text` : le serveur renvoie la phrase telle que l'autrice l'a
            // composée, DANS SA LANGUE. Ici on la refabrique dans celle de la lectrice dès que le
            // post porte de quoi le faire — voir `FeedItem.localizedText`.
            Text(item.localizedText)
                .font(RUFont.sans(.label))
                .foregroundColor(RUColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if item.hasMetrics { metricsRow }
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 0, trailing: 14))
    }

    // MARK: - Pièces communes

    private func author(onDark: Bool) -> some View {
        HStack(spacing: 9) {
            AvatarView(urlString: item.avatarUrl, base64DataURI: item.avatarBase64,
                       initial: String(item.name.prefix(1)), size: 32, seed: isMine ? nil : item.userId)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(RUFont.sans(.label, weight: .bold))
                    .foregroundColor(onDark ? .white : RUColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(timeLine)
                    .font(RUFont.sans(.small))
                    .foregroundColor(onDark ? .white.opacity(0.7) : RUColor.text3)
            }
        }
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
    private var actions: some View {
        HStack(spacing: 20) {
            Button(action: {
                Haptics.impact(.light)
                onKudos()
            }) {
                HStack(spacing: 6) {
                    Text("👏")
                    Text("\(item.kudos)")
                }
                .font(RUFont.sans(.body, weight: .semibold))
                .foregroundColor(item.kudoedByMe ? RUColor.rose2 : RUColor.text2)
                .padding(.trailing, 6)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .scaleEffect(item.kudoedByMe ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.45), value: item.kudoedByMe)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(item.kudoedByMe ? "Retirer ton applaudissement" : "Applaudir cette séance")
            .accessibilityValue("\(item.kudos)")

            Button(action: onComment) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                    Text("\(item.commentsCount)")
                }
                .font(RUFont.sans(.body, weight: .semibold))
                .foregroundColor(RUColor.text2)
                .padding(.trailing, 6)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Voir les commentaires")
            .accessibilityValue("\(item.commentsCount)")

            Spacer(minLength: 0)

            if isMine {
                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15))
                        .foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Modifier ma sortie")
            }
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
        var accent: Bool = false
    }

    private var metrics: [Metric] {
        var result: [Metric] = []
        if let distanceKm = item.distanceKm {
            result.append(Metric(value: String(format: "%.1f", locale: Locale.current, distanceKm), label: "km"))
        }
        // L'allure est la seule colonne accentuée — c'est le chiffre qu'on compare, dans la
        // maquette comme dans la conversation d'un club.
        if let avgPace = item.avgPace {
            result.append(Metric(value: avgPace, label: "allure", accent: true))
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
                    valueColor: metric.accent ? RUColor.rose : RUColor.textPrimary,
                    valueSize: 16
                )
            }
            Spacer(minLength: 0)
        }
    }
}
