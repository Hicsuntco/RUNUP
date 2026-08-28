import SwiftUI

/// A full-screen celebration the moment a badge is genuinely newly earned — until this, an earned
/// badge only ever showed up as a static tile in the `badgeStrip`/`ClubMemberProfileView` grid, the
/// same as one that had been sitting there unlocked for months. `ClubView.syncBadgesIfNeeded` is
/// what tells "just crossed the threshold" apart from "already earned before this feature existed"
/// (via `UserProfile.seenBadgeKeys`/`didBackfillSeenBadges`) and presents this as a `fullScreenCover`.
struct BadgeUnlockedView: View {
    var badge: ClubBadge
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false
    @State private var shareImage: Image?
    @State private var shareRenderFailed = false

    /// Fixed offsets (not regenerated every body evaluation) so the confetti doesn't jitter on
    /// every re-render — one dot per real `AccentTheme`, the same 8 hues used everywhere else in
    /// the app, not an invented confetti palette.
    private static let confettiOffsets: [(CGFloat, CGFloat)] = [
        (-72, -58), (58, -70), (-96, 10), (90, -10),
        (-50, 62), (66, 54), (-16, -92), (20, 88)
    ]

    var body: some View {
        ZStack {
            RUColor.pageBackground.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(RUColor.text3)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Fermer")
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            VStack(spacing: 18) {
                Spacer()

                ZStack {
                    ForEach(Array(Self.confettiOffsets.enumerated()), id: \.offset) { index, offset in
                        Circle()
                            .fill(AccentTheme.all[index % AccentTheme.all.count].primary)
                            .frame(width: 7, height: 7)
                            .offset(x: offset.0, y: offset.1)
                            .opacity(isRevealed ? 0.85 : 0)
                    }

                    let color = ClubBadgeCatalog.color(for: badge.key)
                    HexagonBadgeShape()
                        .fill(color.opacity(0.22))
                        .overlay(HexagonBadgeShape().stroke(color.opacity(0.7), lineWidth: RUSpacing.hairline))
                        .frame(width: 108, height: 108)
                        .overlay(Text(badge.emoji).font(.system(size: 46)))
                        .shadow(color: color.opacity(0.4), radius: 26)
                        .scaleEffect(isRevealed ? 1 : 0.5)
                        .opacity(isRevealed ? 1 : 0)
                }
                .frame(height: 180)

                VStack(spacing: 8) {
                    Text("BADGE DÉBLOQUÉ")
                        .font(RUFont.sans(.small, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(RUColor.text3)
                    Text(badge.name)
                        .font(RUFont.display(30))
                        .foregroundColor(RUColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(badge.detail)
                        .font(RUFont.sans(.label))
                        .foregroundColor(RUColor.text2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 2)
                }

                Spacer()

                VStack(spacing: 14) {
                    if let shareImage {
                        ShareLink(
                            item: shareImage,
                            preview: SharePreview(badge.name, image: shareImage)
                        ) {
                            HStack(spacing: 7) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Partager ce badge")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else if shareRenderFailed {
                        // `ImageRenderer.uiImage` can come back nil under memory pressure — same
                        // recovery as `RecapView`'s share card: a manual retry, "Continuer" below
                        // still works either way if she doesn't bother.
                        Button("Réessayer") { renderShareCard() }
                            .font(RUFont.sans(.body, weight: .semibold))
                            .foregroundColor(RUColor.rose2)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    } else {
                        ProgressView().tint(RUColor.rose).frame(height: 44)
                    }

                    Button(action: onDismiss) {
                        Text("Continuer").font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.text2)
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            Haptics.success()
            if reduceMotion {
                isRevealed = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                    isRevealed = true
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                renderShareCard()
            }
        }
    }

    private func renderShareCard() {
        let renderer = ImageRenderer(content: BadgeShareCardView(badge: badge))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else {
            shareRenderFailed = true
            return
        }
        shareImage = Image(uiImage: uiImage)
    }
}
