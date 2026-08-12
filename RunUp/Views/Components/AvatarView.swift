import SwiftUI
import UIKit

/// Circular avatar — a real photo when one exists, else the initial-letter fallback every avatar
/// spot in the app already used. Three ways in, priority order when more than one is set:
/// `imageData` for the LOCAL case (`UserProfile.avatarImageData`, already-decoded `Data`),
/// `urlString` for the REMOTE case since the Vercel Blob migration (a real Blob URL — `AsyncImage`
/// fetches and caches it, same as any other remote image, instead of every leaderboard/feed/
/// comments row shipping the full photo inline), `base64DataURI` as a fallback for any account
/// that uploaded a photo before that migration and hasn't re-uploaded since.
struct AvatarView: View {
    var imageData: Data? = nil
    var urlString: String? = nil
    var base64DataURI: String? = nil
    var initial: String
    var size: CGFloat
    /// false for spots that only ever used a flat fill (the old `AvatarButton`), true for the
    /// two-tone gradient (`ProfileView`'s big avatar, Club rows).
    var useGradient: Bool = true
    /// A stable per-person identifier (their user id, or name if no id is available) used to pick
    /// which of the 8 real `AccentTheme` gradients this person gets. Nil keeps the single
    /// rose→violet gradient — used for "me" (`ProfileView`, `AvatarButton`), where only one
    /// instance ever appears on screen so distinguishing colors serve no purpose. Every OTHER
    /// person (club leaderboard, feed, friends, comments) passes their id here so two people never
    /// read as the same colored blob in a list — without this every avatar in a leaderboard was
    /// visually identical regardless of who it was.
    var seed: String? = nil

    private var personalTheme: AccentTheme? {
        guard let seed, !seed.isEmpty else { return nil }
        // `String.hashValue` is randomized per process launch (hash-flood protection) — using it
        // here would give the same person a different avatar color every time the app restarts.
        // A plain deterministic sum keeps it stable across launches and across every device.
        let sum = seed.unicodeScalars.reduce(UInt32(0)) { $0 &+ $1.value }
        let index = Int(sum % UInt32(AccentTheme.all.count))
        return AccentTheme.all[index]
    }

    /// `lime`/`amber` are bright enough that white initials lose contrast on them (unlike
    /// `rose`/`violet`, dark enough that white always reads) — relative luminance decides per
    /// theme instead of hardcoding which two are the exception.
    private func initialColor(for theme: AccentTheme) -> Color {
        let ui = UIColor(theme.primary)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? Color.black.opacity(0.75) : .white
    }

    private var localImage: UIImage? {
        if let imageData, let image = UIImage(data: imageData) { return image }
        if let base64DataURI,
           let commaIndex = base64DataURI.firstIndex(of: ","),
           let data = Data(base64Encoded: String(base64DataURI[base64DataURI.index(after: commaIndex)...])),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    var body: some View {
        // Evaluated once per render and reused for both branches below — `localImage` decodes a
        // `UIImage` (and, for the base64 fallback, a `Data(base64Encoded:)` pass first), so reading
        // it twice per body (once directly, once via the old `remoteURL` computed property) meant
        // every avatar in the app — every Club leaderboard/feed/comments row, every screen header —
        // paid for two full image decodes per render instead of one.
        let img = localImage
        ZStack {
            if let img {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if let urlString, let remoteURL = URL(string: urlString) {
                AsyncImage(url: remoteURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var fallback: some View {
        if let theme = personalTheme {
            LinearGradient(colors: [theme.primary, theme.tail], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initial.uppercased())
                .displayStyle(size * 0.4)
                .foregroundColor(initialColor(for: theme))
        } else {
            if useGradient {
                LinearGradient(colors: [RUColor.rose, RUColor.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                RUColor.rose
            }
            Text(initial.uppercased())
                .displayStyle(size * 0.4)
                .foregroundColor(.white)
        }
    }
}
