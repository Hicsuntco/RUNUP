import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Profile tab — a real social hub (identity, real stats, a live preview into Amis and Running
/// Club) rather than a settings page with her name pinned to the top of it. Every setting that
/// used to live directly on this screen (data sources, appearance, notifications, daily goals)
/// moved to `SettingsView`, reached one tap away via the gear icon — nothing here competes with
/// the stats/social content for space anymore, same "one tap away, not gone" cost `MoreSettingsView`
/// already paid for the settings reached even less often than these.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]
    private var profile: UserProfile { appState.profile }
    private var auth: AuthService { appState.auth }
    private var clubService: ClubService { ClubService(auth: auth) }

    @State private var showSettings = false
    @State private var showSignIn = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isSavingAvatar = false

    @State private var isLoadingSocial = true
    @State private var board: ClubBoard?
    @State private var friendsList: FriendsList?
    @State private var todaysFriendActivityCount = 0

    private static let raceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                statRow

                if !auth.isSignedIn {
                    signInPrompt
                } else if isLoadingSocial {
                    loadingSocialCard
                } else {
                    amisCard
                    clubCard
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(RUColor.bg)
        .task { await loadSocialSummary() }
        .refreshable { await loadSocialSummary() }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { Task { await loadSocialSummary() } }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 11) {
                avatarButton
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name).displayStyle(18).foregroundColor(RUColor.textPrimary)
                    if let objectifText {
                        HStack(spacing: 4) {
                            Image(systemName: "target").font(.system(size: 9)).foregroundColor(RUColor.text3)
                            Text(objectifText).font(RUFont.sans(10.5, weight: .semibold)).foregroundColor(RUColor.text2)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundColor(RUColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(RUColor.card, in: Circle())
                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Réglages")
        }
    }

    /// Only when a program/course-libre goal is actually current — recovery and choice phases
    /// have no active goal, and showing the last program's objective there reads as if it were
    /// still being pursued (same reasoning `HomeView.weekEyebrow` already applies).
    private var objectifText: String? {
        guard profile.programPhase == .active || profile.programPhase == .freerun else { return nil }
        if let raceDate {
            return "\(profile.goalDisplay) · \(Self.raceDateFormatter.string(from: raceDate))"
        }
        return profile.goalDisplay.isEmpty ? nil : profile.goalDisplay
    }

    private var raceDate: Date? { profile.raceDate }

    private var avatarButton: some View {
        PhotosPicker(selection: $avatarPickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(imageData: profile.avatarImageData, initial: String(profile.name.prefix(1)), size: 52)
                    .opacity(isSavingAvatar ? 0.5 : 1)
                if isSavingAvatar {
                    ProgressView().tint(RUColor.textPrimary)
                } else {
                    // A small pencil badge is what actually tells her the avatar is
                    // tappable — a plain circle with no affordance reads as decoration.
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(RUColor.rose, in: Circle())
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(isSavingAvatar)
        .accessibilityLabel("Changer la photo de profil")
        .onChange(of: avatarPickerItem) { _, newItem in
            Task { await setAvatar(from: newItem) }
        }
        .contextMenu {
            if profile.avatarImageData != nil {
                Button("Supprimer la photo", role: .destructive) {
                    Task { await removeAvatar() }
                }
            }
        }
    }

    /// Resizes to a real thumbnail (240pt max side) before storing — the picker hands back full
    /// camera-resolution photos (several MB), and this is stored locally in SwiftData AND,
    /// base64-encoded, in the club backend's `users.avatar_data` column for every other member's
    /// leaderboard/feed row — keeping it small keeps both cheap.
    private func setAvatar(from item: PhotosPickerItem?) async {
        isSavingAvatar = true
        defer { isSavingAvatar = false }
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data)
        else { return }
        let resized = uiImage.resized(maxDimension: 240)
        guard let jpeg = resized.jpegData(compressionQuality: 0.6) else { return }
        await MainActor.run { profile.avatarImageData = jpeg }
        // Only club members can ever see this, so only sync it when there's actually an account —
        // it stays a purely local photo otherwise, same as every other profile field.
        guard auth.isSignedIn else { return }
        let dataURI = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        do {
            try await auth.updateAvatar(dataURI: dataURI)
        } catch {
            // The local photo is already saved (see above) — only the club-visible copy failed to
            // sync, worth telling her since it silently used to just never reach other members.
            appState.toast("Photo enregistrée, mais pas encore visible du club — vérifie ta connexion.")
        }
    }

    private func removeAvatar() async {
        await MainActor.run {
            profile.avatarImageData = nil
            avatarPickerItem = nil
        }
        guard auth.isSignedIn else { return }
        do {
            try await auth.updateAvatar(dataURI: nil)
        } catch {
            // Mirrors setAvatar's error handling above — the local photo is already cleared, but
            // the server (and every other club member's leaderboard/feed/comments view) still
            // shows the old one until this actually lands, and without this she'd have no signal
            // that the removal didn't take.
            appState.toast("Photo supprimée localement, mais toujours visible du club — vérifie ta connexion.")
        }
    }

    // MARK: - Real stats row

    private var totalKm: Double { runs.reduce(0) { $0 + $1.distanceKm } }

    /// Number of real, permanent badges earned — `profile.seenBadgeKeys` (see `ClubView`) already
    /// tracks exactly this set (every earned key gets appended there the moment `ClubView` next
    /// computes it, and a badge never un-earns), so this reads it directly instead of re-deriving
    /// earned/locked state from `runs`/`profile.streak` a second time in a different file.
    private var badgeCount: Int { profile.seenBadgeKeys.count }

    private var statRow: some View {
        HStack(spacing: 0) {
            statCell(value: String(format: "%.0f", totalKm), label: "km")
            statDivider
            statCell(
                value: "\(profile.streak)",
                label: "sem. de suite",
                valueColor: profile.streak > 0 ? RUColor.rose : RUColor.textPrimary,
                icon: profile.streak > 0 ? "flame.fill" : nil
            )
            statDivider
            statCell(value: "\(badgeCount)", label: badgeCount > 1 ? "badges" : "badge")
        }
        .padding(.vertical, 14)
        .ruCard()
    }

    private var statDivider: some View {
        Rectangle().fill(RUColor.line).frame(width: RUSpacing.hairline).padding(.vertical, 4)
    }

    private func statCell(value: String, label: String, valueColor: Color = RUColor.textPrimary, icon: String? = nil) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11)).foregroundColor(valueColor)
                }
                Text(value).displayStyle(20).foregroundColor(valueColor)
            }
            Text(label).font(RUFont.sans(9.5, weight: .semibold)).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Social preview cards

    private var loadingSocialCard: some View {
        VStack(spacing: 10) {
            ProgressView().tint(RUColor.rose)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .ruCard()
    }

    private var signInPrompt: some View {
        VStack(spacing: 12) {
            AppMarkView(size: 40)
            Text("Ton profil prend vie à plusieurs").font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            Text("Connecte-toi pour voir tes amis et ton club directement ici.")
                .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).multilineTextAlignment(.center)
            Button("SE CONNECTER") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .ruCard()
    }

    private var amisCard: some View {
        Button(action: {
            appState.openFriendsTabOnNextVisit = true
            appState.go(.club)
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(RUColor.violet.opacity(0.16))
                        Image(systemName: "person.2.fill").font(.system(size: 16)).foregroundColor(RUColor.violet)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Amis").font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                        if let friendsList {
                            Text("\(friendsList.followers.count) abonnés · \(friendsList.following.count) abonnements")
                                .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("›").font(.system(size: 15, weight: .semibold)).foregroundColor(RUColor.text3)
                }

                if let friendsList, !friendsList.following.isEmpty {
                    HStack(spacing: 8) {
                        HStack(spacing: -8) {
                            ForEach(friendsList.following.prefix(3)) { user in
                                AvatarView(urlString: user.avatarUrl, base64DataURI: user.avatarBase64, initial: String(user.name.prefix(1)), size: 24, seed: user.id)
                                    .overlay(Circle().stroke(RUColor.card, lineWidth: 2))
                            }
                        }
                        Text(todaysFriendActivityCount > 0
                             ? "\(todaysFriendActivityCount) nouvelle\(todaysFriendActivityCount > 1 ? "s" : "") activité\(todaysFriendActivityCount > 1 ? "s" : "") aujourd'hui"
                             : "Rien de nouveau aujourd'hui")
                            .font(RUFont.sans(10.5)).foregroundColor(RUColor.text2)
                    }
                } else {
                    Text("Trouve des coureurs à suivre").font(RUFont.sans(10.5)).foregroundColor(RUColor.text2)
                }
            }
            .padding(14)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    private var clubCard: some View {
        Button(action: { appState.go(.club) }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(RUColor.heroGradient)
                        Image(systemName: "trophy.fill").font(.system(size: 15)).foregroundColor(RUColor.rose)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Running Club").font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                        if let club = board?.club {
                            Text("\(club.name) · \(club.memberCount) membres").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                        } else {
                            Text("Pas encore de club").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("›").font(.system(size: 15, weight: .semibold)).foregroundColor(RUColor.text3)
                }

                if let event = board?.events?.first {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundColor(RUColor.rose)
                        Text(event.title).font(RUFont.sans(11, weight: .bold)).foregroundColor(RUColor.rose)
                        Text("— \(event.going) confirmé\(event.going > 1 ? "s" : "")").font(RUFont.sans(10.5)).foregroundColor(RUColor.text2)
                    }
                } else if board?.club == nil {
                    Text("Rejoins ou crée un club pour courir à plusieurs").font(RUFont.sans(10.5)).foregroundColor(RUColor.text2)
                }
            }
            .padding(14)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    // MARK: - Data loading

    private func loadSocialSummary() async {
        guard auth.isSignedIn else { isLoadingSocial = false; return }
        isLoadingSocial = true
        // Independent requests, fired concurrently — same reasoning as `ClubView.loadIfSignedIn`:
        // none of these three depends on another's result, so the wait is the slowest single
        // request instead of the sum of all three.
        async let boardAttempt = try? await clubService.fetchBoard()
        async let friendsListAttempt = try? await clubService.fetchFriendsList()
        async let friendsFeedAttempt = try? await clubService.fetchFriendsFeed()
        let (boardResult, friendsListResult, friendsFeedResult) = await (boardAttempt, friendsListAttempt, friendsFeedAttempt)

        board = boardResult
        friendsList = friendsListResult
        todaysFriendActivityCount = (friendsFeedResult ?? []).filter { Calendar.current.isDateInToday($0.createdAt) }.count
        isLoadingSocial = false
    }
}
