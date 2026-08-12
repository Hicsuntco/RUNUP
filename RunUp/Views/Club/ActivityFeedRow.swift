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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(urlString: item.avatarUrl, base64DataURI: item.avatarBase64, initial: String(item.name.prefix(1)), size: 34, seed: isMine ? nil : item.userId)
                VStack(alignment: .leading, spacing: 2) {
                    (Text(item.name).fontWeight(.semibold) + Text(" \(item.text)"))
                        .font(RUFont.sans(13))
                        .foregroundColor(RUColor.textPrimary)
                    Text(item.createdAt.relativeDescription).font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button(action: {
                    Haptics.impact(.light)
                    onKudos()
                }) {
                    HStack(spacing: 6) {
                        Text("👏")
                        Text("\(item.kudos)")
                    }
                    .font(RUFont.sans(11.5, weight: .semibold))
                    .foregroundColor(item.kudoedByMe ? RUColor.rose2 : RUColor.text2)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(minHeight: 44)
                    .background(item.kudoedByMe ? RUColor.rose.opacity(0.16) : RUColor.card2, in: Capsule())
                    .overlay(Capsule().stroke(item.kudoedByMe ? RUColor.rose.opacity(0.35) : RUColor.line, lineWidth: RUSpacing.hairline))
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
                    .font(RUFont.sans(11.5, weight: .semibold))
                    .foregroundColor(RUColor.text2)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(minHeight: 44)
                    .background(RUColor.card2, in: Capsule())
                    .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Voir les commentaires")
                .accessibilityValue("\(item.commentsCount)")
            }
        }
        .padding(13)
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
}
