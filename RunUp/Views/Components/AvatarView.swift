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

    private var remoteURL: URL? {
        guard localImage == nil, let urlString, let url = URL(string: urlString) else { return nil }
        return url
    }

    var body: some View {
        ZStack {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else if let remoteURL {
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
