import SwiftUI

/// Top of the social tab — lets her choose "esprit club" (shared leaderboard/challenges/invite
/// code, `ClubView`) or a lighter, club-independent follow feed (`FriendsView`), and switch
/// between the two freely: a follow relationship is completely separate from club membership, so
/// both stay fully usable regardless of which one she has. Local-only choice (not persisted) —
/// same as `ClubView`'s own `boardMode`, cheap enough to just default back to "Club" on next
/// launch rather than needing a `UserProfile` field for it.
struct SocialView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: Mode = .club
    // Unlike kudos/comments (`ClubView.notifyNewKudos`/`notifyNewComments`), incoming follow
    // requests had no badge at all — a private account could sit with unanswered requests
    // indefinitely unless she happened to tap "Mes amis". Fetched independently of which segment
    // is active, since the whole point is surfacing it before she'd otherwise go looking.
    @State private var pendingRequestsCount = 0

    private enum Mode { case club, friends }
    private var clubService: ClubService { ClubService(auth: appState.auth) }

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
        .task { await refreshPendingRequestsCount() }
        .onChange(of: mode) { _, newMode in
            if newMode == .club { Task { await refreshPendingRequestsCount() } }
        }
    }

    private func refreshPendingRequestsCount() async {
        guard appState.auth.isSignedIn else { return }
        if let list = try? await clubService.fetchFriendsList() {
            pendingRequestsCount = list.incomingRequests.count
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segment("Mon club", .club)
            segment("Mes amis", .friends, badgeCount: pendingRequestsCount)
        }
        .padding(3)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func segment(_ label: String, _ value: Mode, badgeCount: Int = 0) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { mode = value } }) {
            HStack(spacing: 5) {
                Text(label)
                    .font(RUFont.sans(12.5, weight: .semibold))
                if badgeCount > 0 {
                    // Selected segment's own background is already RUColor.rose — a rose badge
                    // on top of it would be invisible, so the badge inverts when selected.
                    Text("\(badgeCount)")
                        .font(RUFont.sans(9.5, weight: .bold))
                        .foregroundColor(mode == value ? RUColor.rose : .white)
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(mode == value ? Color.white : RUColor.rose, in: Capsule())
                }
            }
            .foregroundColor(mode == value ? .white : RUColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(mode == value ? RUColor.rose : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(mode == value ? .isSelected : [])
        .accessibilityLabel(badgeCount > 0 ? "\(label), \(badgeCount) demandes en attente" : label)
    }
}
