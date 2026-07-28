import SwiftUI

/// Top of the social tab — lets her choose "esprit club" (shared leaderboard/challenges/invite
/// code, `ClubView`) or a lighter, club-independent follow feed (`FriendsView`), and switch
/// between the two freely: a follow relationship is completely separate from club membership, so
/// both stay fully usable regardless of which one she has. Local-only choice (not persisted) —
/// same as `ClubView`'s own `boardMode`, cheap enough to just default back to "Club" on next
/// launch rather than needing a `UserProfile` field for it.
struct SocialView: View {
    @State private var mode: Mode = .club

    private enum Mode { case club, friends }

    var body: some View {
        VStack(spacing: 0) {
            modeSwitch
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.top, 8)

            Group {
                if mode == .club { ClubView() } else { FriendsView() }
            }
        }
        .background(RUColor.bg)
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segment("Mon club", .club)
            segment("Mes amis", .friends)
        }
        .padding(3)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func segment(_ label: String, _ value: Mode) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { mode = value } }) {
            Text(label)
                .font(RUFont.sans(12.5, weight: .semibold))
                .foregroundColor(mode == value ? .white : RUColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(mode == value ? RUColor.rose : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}
