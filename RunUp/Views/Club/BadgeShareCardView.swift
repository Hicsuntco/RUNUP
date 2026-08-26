import SwiftUI

/// The share card for a freshly unlocked badge — rendered off-screen (via `ImageRenderer` in
/// `BadgeUnlockedView`, same mechanism `RecapView` uses for `RunShareCardView`) into a `UIImage`
/// handed to a `ShareLink`. Unlike the run recap card, a badge has no photo to layer over, so this
/// one is a plain opaque brand card rather than a transparent PNG — the achievement itself is the
/// visual, not something meant to sit on top of a story background.
struct BadgeShareCardView: View {
    var badge: ClubBadge

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    var body: some View {
        let color = ClubBadgeCatalog.color(for: badge.key)
        ZStack {
            RadialGradient(colors: [color.opacity(0.22), RUColor.bg], center: .center, startRadius: 10, endRadius: 260)

            VStack(spacing: 18) {
                HexagonBadgeShape()
                    .fill(color.opacity(0.22))
                    .overlay(HexagonBadgeShape().stroke(color.opacity(0.7), lineWidth: RUSpacing.hairline))
                    .frame(width: 132, height: 132)
                    .overlay(Text(badge.emoji).font(.system(size: 58)))
                    .shadow(color: color.opacity(0.45), radius: 30)

                VStack(spacing: 6) {
                    Text("BADGE DÉBLOQUÉ")
                        .font(RUFont.sans(12, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(color)
                    Text(badge.name)
                        .font(RUFont.display(34))
                        .foregroundColor(RUColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(badge.detail)
                        .font(RUFont.sans(13))
                        .foregroundColor(RUColor.text2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)
                }

                VStack(spacing: 5) {
                    HStack(spacing: 7) {
                        AppMarkView(size: 22, radius: 6, color: RUColor.rose)
                        Text("RUNUP").font(RUFont.display(15)).tracking(4).foregroundColor(RUColor.textPrimary)
                    }
                    Text(Self.dateFormatter.string(from: .now))
                        .font(RUFont.mono(9.5))
                        .tracking(1)
                        .foregroundColor(RUColor.text3)
                }
                .padding(.top, 18)
            }
            .padding(40)
        }
        .frame(width: 360, height: 640)
        .background(RUColor.bg)
    }
}
