import SwiftUI
import UIKit

/// Small brand-logo tile for data-source rows (Strava, Garmin) — renders the official logo from
/// the asset catalog when present. The image files are added by hand in Xcode (drag the official
/// artwork into `Assets.xcassets` and name the entries exactly `strava-logo` / `garmin-logo`);
/// until then this falls back to the same plain wordmark-text placeholder the rows used before,
/// so a missing asset degrades to text, never an empty hole.
struct BrandLogoIcon: View {
    var assetName: String
    var fallbackText: String
    /// Full-bleed marks (Strava's orange app icon) fill the tile edge-to-edge and just get
    /// rounded corners; wordmarks with transparency (Garmin's black text + blue delta) sit inset
    /// on a small white tile instead, so they stay legible on the dark theme too.
    var fullBleed: Bool = false
    var size: CGFloat = 24

    var body: some View {
        if UIImage(named: assetName) != nil {
            if fullBleed {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(.white)
                    .frame(width: size, height: size)
                    .overlay(
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.14)
                    )
                    .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            }
        } else {
            Text(fallbackText)
                .font(RUFont.sans(10, weight: .bold))
                .foregroundColor(RUColor.text3)
                .frame(width: size, alignment: .leading)
        }
    }
}
