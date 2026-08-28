import SwiftUI

/// One posted activity in a feed — kudos, comment button, owner-only delete / others-only
/// report+block. Shared between `ClubView`'s "Fil d'activité" (clubmates) and `FriendsView`'s
/// feed (people followed): both render the same `FeedItem` posted through the same
/// `api/activities/*.js` endpoints, just reached through a different relationship (club
/// membership vs. a follow — see `lib/social.js`'s `canViewActivity`), so the row itself doesn't
/// need to know which one it's in.
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

    var body: some View {
        // Composition reprise de `.feed-card` de la maquette : en-tête (avatar + qui + quand),
        // corps, puis une barre d'actions SÉPARÉE par un filet. Ce filet est le vrai apport :
        // avant, les deux pastilles d'action flottaient au même niveau visuel que le texte de
        // l'activité, et la carte n'avait aucune structure interne.
        //
        // La ligne KM / ALLURE / TEMPS / D+ et le badge « RECORD » de la maquette sont maintenant
        // là, alimentés par de vraies mesures : `FeedItem` transporte désormais `distanceKm`,
        // `durationSeconds`, `avgPace`, `elevationGainM` et `isPersonalRecord`, enregistrés au
        // moment du debrief (voir DebriefSheet.swift). Chaque colonne n'apparaît que si sa mesure
        // existe — un post de badge ou une séance sans GPS n'en affiche aucune, plutôt qu'un
        // « 0,0 km » qui ferait passer une absence de mesure pour une mesure.
        //
        // Toujours PAS repris, faute de données réelles : la vignette de tracé (le tracé GPS
        // n'est jamais envoyé au serveur), la ligne « Aimé par Thomas, Sofia et 6 autres » (le
        // serveur renvoie un COMPTE, jamais les noms) et l'aperçu du dernier commentaire.
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(urlString: item.avatarUrl, base64DataURI: item.avatarBase64, initial: String(item.name.prefix(1)), size: 34, seed: isMine ? nil : item.userId)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(RUFont.sans(.label, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(item.createdAt.relativeDescription).font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                }
                Spacer(minLength: 0)
                // `.pr-badge` : la pastille de record vit dans l'en-tête, à l'opposé du nom, et
                // pas dans la rangée de métriques — c'est un fait sur la sortie entière, pas une
                // cinquième mesure. Elle n'apparaît que quand la sortie a réellement battu la
                // plus longue distance ou la meilleure allure (voir `RunRecord
                // .beatsPersonalRecord`).
                if item.isPersonalRecord {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill").font(.system(size: 8, weight: .bold))
                        Text("RECORD")
                    }
                    .font(RUFont.sans(.micro, weight: .bold))
                    .tracking(0.4)
                    .foregroundColor(RUColor.rose)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(RUColor.tint(RUColor.rose, 0.12, over: RUColor.card)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Record personnel")
                }
            }
            // La phrase commence par un verbe conjugué (« a couru 8,2 km · Sortie longue ») :
            // elle reste rattachée au nom au-dessus, mais sur sa propre ligne plutôt qu'en une
            // seule phrase enroulée autour de l'avatar — c'est la ligne de contenu de la carte,
            // elle mérite sa largeur pleine.
            //
            // `localizedText` et pas `text` : le serveur renvoie la phrase telle que l'autrice
            // l'a composée, DANS SA LANGUE. Ici, on la refabrique dans celle de la lectrice dès
            // que le post porte de quoi le faire — voir `FeedItem.localizedText`.
            Text(item.localizedText)
                .font(RUFont.sans(.label))
                .foregroundColor(RUColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if item.hasMetrics {
                metricsRow
            }

            Rectangle()
                .fill(RUColor.line)
                .frame(height: RUSpacing.hairline)

            // Actions sans pastille ni contour (`.feed-actions .act` dans la maquette) : dans une
            // carte, deux gros boutons bordés pèsent plus lourd que l'activité elle-même. La
            // cible tactile reste à 44 pt via `frame(minHeight:)` + `contentShape` — c'est le
            // chrome qui disparaît, pas la zone tapable.
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
            }
        }
        .padding(14)
        .ruCard()
        // Rows fade/slide in one after the other on first load instead of the whole feed
        // materializing at once — delay capped past the 8th row so a long feed doesn't keep
        // animating below the fold.
        .opacity(revealed ? 1 : 0)
        .offset(x: revealed ? 0 : -14)
        .animation(.easeOut(duration: 0.35).delay(Double(min(index, 8)) * 0.05), value: revealed)
        .contextMenu {
            if !isMine {
                Button("Signaler cette activité", action: onReport)
                Button("Bloquer \(item.name)", role: .destructive, action: onBlock)
            } else {
                Button("Supprimer cette activité", role: .destructive, action: onDelete)
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
