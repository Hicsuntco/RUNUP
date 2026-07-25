import SwiftUI
import UIKit

/// Circular avatar — a real photo when one exists, else the initial-letter fallback every avatar
/// spot in the app already used. Two ways in, exactly one per caller: `imageData` for the LOCAL
/// case (`UserProfile.avatarImageData`, already-decoded `Data`), `base64DataURI` for the REMOTE
/// case (what the club API returns for other members — `"data:image/jpeg;base64,...."`, decoded
/// here rather than requiring every call site to repeat the same parsing).
struct AvatarView: View {
    var imageData: Data? = nil
    var base64DataURI: String? = nil
    var initial: String
    var size: CGFloat
    /// false for spots that only ever used a flat fill (the old `AvatarButton`), true for the
    /// two-tone gradient (`ProfileView`'s big avatar, Club rows).
    var useGradient: Bool = true

    private var resolvedImage: UIImage? {
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
        ZStack {
            if let resolvedImage {
                Image(uiImage: resolvedImage)
                    .resizable()
                    .scaledToFill()
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
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
