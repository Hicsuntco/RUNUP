import SwiftUI

/// The lighter, club-independent social option (see `SocialView`) — follow real accounts
/// directly, no shared leaderboard/challenges/invite-code "esprit club" required. A follow is
/// completely separate from club membership: someone with no club (or a different one) still
/// shows up here once followed, and her own feed here is powered by `api/friends/*.js`, not
/// `api/clubs/*.js`.
struct FriendsView: View {
    @Environment(AppState.self) private var appState

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isPrivate = false
    @State private var following: [PublicUser] = []
    @State private var followers: [PublicUser] = []
    @State private var incomingRequests: [PublicUser] = []
    @State private var feed: [FeedItem] = []
    @State private var feedRevealed = false

    @State private var query = ""
    @State private var searchResults: [PublicUser] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var searchTask: Task<Void, Never>?

    @State private var showSignIn = false
    @State private var peopleSheet: PeopleSheetKind?
    @State private var commentsActivity: FeedItem?
    @State private var reportTarget: ReportTarget?
    @State private var pendingBlock: (userId: String, name: String)?
    @State private var pendingDeleteActivity: FeedItem?

    private enum PeopleSheetKind: Identifiable, Hashable {
        case following, followers
        var id: Self { self }
    }

    private var auth: AuthService { appState.auth }
    private var clubService: ClubService { ClubService(auth: auth) }
    private var isSearchingMode: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !auth.isSignedIn {
                    signInPrompt
                } else {
                    searchField
                    if isSearchingMode {
                        searchResultsList
                    } else if isLoading && feed.isEmpty {
                        loadingCard
                    } else {
                        privacyRow
                        if !incomingRequests.isEmpty { requestsCard }
                        countsRow
                        feedSection
                    }
                }

                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                        Text(errorMessage).font(RUFont.sans(11))
                    }
                    .foregroundColor(RUColor.rose)
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: feed.count) { _, count in if count > 0 { feedRevealed = true } }
        .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
        .onChange(of: auth.isSignedIn) { _, signedIn in if signedIn { Task { await load() } } }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(item: $peopleSheet) { kind in
            PeopleListSheet(
                title: kind == .following ? "Abonnements" : "Abonnés",
                people: kind == .following ? following : followers,
                actionLabel: kind == .following ? "Ne plus suivre" : "Retirer",
                onAction: { user in
                    Task {
                        if kind == .following { await unfollow(user) } else { await removeFollower(user) }
                    }
                }
            )
            .runUpSheetStyle()
        }
        .sheet(item: $commentsActivity) { activity in
            ActivityCommentsSheet(
                activity: activity,
                currentUserId: auth.currentUser?.id,
                clubService: clubService,
                onCommentPosted: { bumpCommentsCount(activity.id) },
                onReport: { comment in
                    commentsActivity = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        reportTarget = ReportTarget(targetType: "comment", targetId: comment.id, displayName: "le commentaire de \(comment.name)")
                    }
                },
                onBlock: { comment in
                    commentsActivity = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        pendingBlock = (comment.userId, comment.name)
                    }
                }
            )
        }
        .confirmationDialog(
            "Signaler",
            isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
            presenting: reportTarget
        ) { target in
            Button("Contenu inapproprié") { Task { await submitReport(target, reason: "Contenu inapproprié") } }
            Button("Harcèlement") { Task { await submitReport(target, reason: "Harcèlement") } }
            Button("Spam") { Task { await submitReport(target, reason: "Spam") } }
            Button("Annuler", role: .cancel) {}
        } message: { target in
            Text("Pourquoi signales-tu \(target.displayName) ?")
        }
        .alert(
            "Bloquer \(pendingBlock?.name ?? "") ?",
            isPresented: Binding(get: { pendingBlock != nil }, set: { if !$0 { pendingBlock = nil } })
        ) {
            Button("Bloquer", role: .destructive) {
                if let target = pendingBlock { Task { await confirmBlock(target.userId) } }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Vous ne verrez plus vos activités l'un de l'autre, et ça retire tout suivi entre vous.")
        }
        .alert(
            "Supprimer cette activité ?",
            isPresented: Binding(get: { pendingDeleteActivity != nil }, set: { if !$0 { pendingDeleteActivity = nil } })
        ) {
            Button("Supprimer", role: .destructive) {
                if let item = pendingDeleteActivity { Task { await confirmDeleteActivity(item) } }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Elle disparaîtra de tous les fils où elle apparaît. Tes XP restent acquis.")
        }
    }

    // MARK: Not signed in

    private var signInPrompt: some View {
        VStack(spacing: 12) {
            AppMarkView(size: 44)
            Text("Suis de vraies personnes").font(RUFont.sans(15, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            Text("Connecte-toi pour suivre qui tu veux et voir ses séances dans un fil, sans passer par un club.")
                .font(RUFont.sans(12)).foregroundColor(RUColor.text2).multilineTextAlignment(.center)
            Button("SE CONNECTER") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .ruCard()
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(RUColor.rose)
            Text("Chargement…").font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .ruCard()
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundColor(RUColor.text3)
            TextField("", text: $query, prompt: Text("Pseudo, email ou nom…").foregroundColor(RUColor.text3))
                .textInputAutocapitalization(.never)
                .foregroundColor(RUColor.textPrimary)
                .font(RUFont.sans(13))
            if isSearchingMode {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private var searchResultsList: some View {
        VStack(spacing: 6) {
            if isSearching && searchResults.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if searchFailed {
                Text("Recherche impossible — vérifie ta connexion.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.rose)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if searchResults.isEmpty {
                Text("Personne ne porte ce nom.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            ForEach(searchResults) { user in
                personRow(user) { followButton(for: user) }
            }
        }
    }

    private func followButton(for user: PublicUser) -> some View {
        let label: String
        let isActive: Bool
        switch user.followStatus {
        case "accepted": label = "Abonné·e"; isActive = true
        case "pending": label = "Demande envoyée"; isActive = true
        default: label = "Suivre"; isActive = false
        }
        return Button(action: { Task { await toggleFollow(user) } }) {
            Text(label)
                .font(RUFont.sans(11.5, weight: .bold))
                .foregroundColor(isActive ? RUColor.textPrimary : .white)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .frame(minHeight: 44)
                .background(isActive ? RUColor.card2 : RUColor.rose, in: Capsule())
                .overlay(Capsule().stroke(isActive ? RUColor.line : Color.clear, lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
    }

    /// Full name (when she's set a last name) plus the "@pseudo" secondary line (when she's set
    /// one) — either helps tell several people sharing a first name apart, which a bare first
    /// name alone never could.
    private func personRow<Trailing: View>(_ user: PublicUser, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            AvatarView(urlString: user.avatarUrl, base64DataURI: user.avatarBase64, initial: String(user.name.prefix(1)), size: 34)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(user.lastName.map { "\(user.name) \($0)" } ?? user.name)
                        .font(RUFont.sans(13, weight: .medium)).foregroundColor(RUColor.textPrimary).lineLimit(1)
                    if user.isPrivate {
                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundColor(RUColor.text3)
                    }
                }
                if let username = user.username {
                    Text("@\(username)").font(RUFont.mono(10.5)).foregroundColor(RUColor.text3)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        .contextMenu {
            Button("Signaler \(user.name)") {
                reportTarget = ReportTarget(targetType: "user", targetId: user.id, displayName: user.name)
            }
            Button("Bloquer \(user.name)", role: .destructive) {
                pendingBlock = (user.id, user.name)
            }
        }
    }

    // MARK: Privacy + requests

    private var privacyRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compte privé").font(RUFont.sans(13, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Text(isPrivate ? "Une demande devra être acceptée avant qu'on puisse te suivre." : "Tout le monde peut te suivre sans validation.")
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isPrivate }, set: { _ in togglePrivate() }))
                .labelsHidden()
                .tint(RUColor.rose)
                .accessibilityLabel("Compte privé")
        }
        .padding(14)
        .ruCard()
    }

    private var requestsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Demandes en attente", color: RUColor.rose2)
            ForEach(incomingRequests) { user in
                HStack(spacing: 12) {
                    AvatarView(urlString: user.avatarUrl, base64DataURI: user.avatarBase64, initial: String(user.name.prefix(1)), size: 32)
                    Text(user.name).font(RUFont.sans(13, weight: .medium)).foregroundColor(RUColor.textPrimary).lineLimit(1)
                    Spacer(minLength: 8)
                    Button(action: { Task { await respond(user, accept: false) } }) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(RUColor.text2)
                            .frame(width: 30, height: 30).background(RUColor.card2, in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Refuser \(user.name)")
                    Button(action: { Task { await respond(user, accept: true) } }) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .frame(width: 30, height: 30).background(RUColor.rose, in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Accepter \(user.name)")
                }
            }
        }
        .padding(14)
        .ruCard()
    }

    private var countsRow: some View {
        HStack(spacing: 10) {
            Button(action: { peopleSheet = .following }) {
                countTile(value: following.count, label: "abonnements")
            }
            .buttonStyle(PressableStyle())
            Button(action: { peopleSheet = .followers }) {
                countTile(value: followers.count, label: "abonnés")
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func countTile(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").displayStyle(20).foregroundColor(RUColor.textPrimary)
            Text(label).font(RUFont.sans(10.5)).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .ruCard()
    }

    // MARK: Feed

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Fil d'activité", color: RUColor.rose)
            if feed.isEmpty && !isLoading {
                Text(following.isEmpty
                    ? "Suis quelqu'un pour voir ses séances ici."
                    : "Personne n'a encore rien posté — reviens plus tard.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            ForEach(Array(feed.enumerated()), id: \.element.id) { index, item in
                ActivityFeedRow(
                    item: item,
                    isMine: item.userId == auth.currentUser?.id,
                    revealed: feedRevealed,
                    index: index,
                    onKudos: { Task { await toggleKudos(item) } },
                    onComment: { commentsActivity = item },
                    onReport: {
                        reportTarget = ReportTarget(targetType: "activity", targetId: item.id, displayName: "l'activité de \(item.name)")
                    },
                    onBlock: { pendingBlock = (item.userId, item.name) },
                    onDelete: { pendingDeleteActivity = item }
                )
            }
        }
    }

    // MARK: Networking

    private func load() async {
        guard auth.isSignedIn else { return }
        errorMessage = nil
        async let listAttempt = try? await clubService.fetchFriendsList()
        async let feedAttempt = try? await clubService.fetchFriendsFeed()
        let (listResult, feedResult) = await (listAttempt, feedAttempt)

        if let listResult {
            isPrivate = listResult.isPrivate
            following = listResult.following
            followers = listResult.followers
            incomingRequests = listResult.incomingRequests
        } else {
            errorMessage = "Impossible de charger tes amis — vérifie ta connexion."
        }
        if let feedResult {
            feed = feedResult
        } else if errorMessage == nil {
            errorMessage = "Impossible de charger le fil d'activité — vérifie ta connexion."
        }
        isLoading = false
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            searchFailed = false
            return
        }
        isSearching = true
        searchFailed = false
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try await clubService.searchUsers(query: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isSearching = false
                    searchFailed = true
                }
            }
        }
    }

    private func toggleFollow(_ user: PublicUser) async {
        Haptics.selection()
        if user.followStatus == nil {
            do {
                let status = try await clubService.followUser(userId: user.id)
                await MainActor.run { updateSearchStatus(user.id, status: status) }
            } catch {
                await MainActor.run { appState.toast("Impossible de suivre cette personne — réessaie.") }
            }
        } else {
            do {
                try await clubService.unfollowUser(userId: user.id)
                await MainActor.run { updateSearchStatus(user.id, status: nil) }
            } catch {
                await MainActor.run { appState.toast("Impossible de mettre à jour — réessaie.") }
            }
        }
    }

    private func updateSearchStatus(_ userId: String, status: String?) {
        guard let index = searchResults.firstIndex(where: { $0.id == userId }) else { return }
        searchResults[index].followStatus = status
    }

    private func unfollow(_ user: PublicUser) async {
        do {
            try await clubService.unfollowUser(userId: user.id)
            await MainActor.run { following.removeAll { $0.id == user.id } }
        } catch {
            await MainActor.run { appState.toast("Impossible de mettre à jour — réessaie.") }
        }
    }

    private func removeFollower(_ user: PublicUser) async {
        do {
            try await clubService.removeFollower(userId: user.id)
            await MainActor.run { followers.removeAll { $0.id == user.id } }
        } catch {
            await MainActor.run { appState.toast("Impossible de mettre à jour — réessaie.") }
        }
    }

    private func respond(_ user: PublicUser, accept: Bool) async {
        Haptics.impact(.light)
        do {
            try await clubService.respondToFollowRequest(followerId: user.id, accept: accept)
            await MainActor.run {
                incomingRequests.removeAll { $0.id == user.id }
                if accept { followers.append(user) }
            }
        } catch {
            await MainActor.run { appState.toast("Impossible de répondre — réessaie.") }
        }
    }

    private func togglePrivate() {
        let next = !isPrivate
        isPrivate = next
        Haptics.selection()
        Task {
            do {
                try await clubService.setPrivateAccount(next)
            } catch {
                await MainActor.run {
                    isPrivate = !next
                    appState.toast("Impossible de mettre à jour — réessaie.")
                }
            }
        }
    }

    private func toggleKudos(_ item: FeedItem) async {
        guard let index = feed.firstIndex(where: { $0.id == item.id }) else { return }
        let wasKudoed = feed[index].kudoedByMe
        feed[index].kudoedByMe.toggle()
        feed[index].kudos += wasKudoed ? -1 : 1
        do {
            try await clubService.toggleKudos(activityId: item.id)
        } catch {
            feed[index].kudoedByMe = wasKudoed
            feed[index].kudos += wasKudoed ? 1 : -1
            appState.toast("Kudos non envoyé — vérifie ta connexion.")
        }
    }

    private func bumpCommentsCount(_ activityId: String) {
        guard let index = feed.firstIndex(where: { $0.id == activityId }) else { return }
        feed[index].commentsCount += 1
    }

    private func confirmDeleteActivity(_ item: FeedItem) async {
        do {
            try await clubService.deleteActivity(activityId: item.id)
            await MainActor.run {
                feed.removeAll { $0.id == item.id }
                appState.toast("Activité supprimée.")
            }
        } catch {
            await MainActor.run { appState.toast("Suppression impossible — réessaie.") }
        }
    }

    private func submitReport(_ target: ReportTarget, reason: String) async {
        do {
            try await clubService.report(targetType: target.targetType, targetId: target.targetId, reason: reason)
            appState.toast("Signalement envoyé — merci")
        } catch {
            appState.toast("Impossible d'envoyer le signalement, réessaie.")
        }
    }

    private func confirmBlock(_ userId: String) async {
        do {
            try await clubService.blockUser(userId: userId)
            following.removeAll { $0.id == userId }
            followers.removeAll { $0.id == userId }
            incomingRequests.removeAll { $0.id == userId }
            feed.removeAll { $0.userId == userId }
        } catch {
            errorMessage = "Impossible de bloquer cette personne."
        }
    }
}

/// Following or followers, with a single contextual action per row ("Ne plus suivre" /
/// "Retirer") — the same two lists `FriendsView.countsRow` opens, just as a sheet since either
/// can get long.
private struct PeopleListSheet: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    @State var people: [PublicUser]
    var actionLabel: String
    var onAction: (PublicUser) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    if people.isEmpty {
                        Text("Personne pour l'instant.")
                            .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                            .frame(maxWidth: .infinity).padding(.vertical, 30)
                    }
                    ForEach(people) { user in
                        HStack(spacing: 12) {
                            AvatarView(urlString: user.avatarUrl, base64DataURI: user.avatarBase64, initial: String(user.name.prefix(1)), size: 34)
                            Text(user.lastName.map { "\(user.name) \($0)" } ?? user.name)
                                .font(RUFont.sans(13, weight: .medium)).foregroundColor(RUColor.textPrimary).lineLimit(1)
                            Spacer(minLength: 8)
                            Button(actionLabel) {
                                people.removeAll { $0.id == user.id }
                                onAction(user)
                            }
                            .font(RUFont.sans(11, weight: .semibold))
                            .foregroundColor(RUColor.text2)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .frame(minHeight: 44)
                            .background(RUColor.card2, in: Capsule())
                            .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(RUColor.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }
}
