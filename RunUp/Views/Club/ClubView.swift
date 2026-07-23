import SwiftUI
import SwiftData

/// Social/club screen — a real, server-backed club (see `ClubService`, `api/clubs/*.js`,
/// `api/activities/*.js`), not `ClubMockData`: the leaderboard is computed from real members' XP,
/// the feed is real posted activities, kudos persist per-user. Requires a real account
/// (`AuthService`) — the rest of the app works fully offline, this is the one feature that
/// intrinsically needs one, so sign-in is gated here rather than forced at onboarding.
struct ClubView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]

    @State private var tab: Tab = .board
    @State private var board = ClubBoard(club: nil, leaderboard: [])
    @State private var feed: [FeedItem] = []
    // Starts true (not false) so the very first render — before `.task` below has had a chance to
    // run — reads as "checking for your club" rather than immediately flashing the create/join
    // form. `.id(appState.screen)` on the parent means a fresh ClubView (and fresh isLoading=true)
    // is created every time this tab is opened, so this covers every visit, not just the first.
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSignIn = false
    @State private var newClubName = ""
    @State private var joinCode = ""
    @State private var reportTarget: ReportTarget?
    @State private var pendingBlock: (userId: String, name: String)?
    @State private var showManagement = false
    @State private var commentsActivity: FeedItem?
    @State private var selectedBadge: ClubBadge?

    private enum Tab { case board, feed }

    private var profile: UserProfile { appState.profile }
    private var auth: AuthService { appState.auth }
    private var clubService: ClubService { ClubService(auth: auth) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header

                if !auth.isSignedIn {
                    signInPrompt
                } else if isLoading && board.club == nil {
                    // Without this, the ~few seconds `loadIfSignedIn` takes to fetch her real
                    // club read as "the create/join form flashes, then flips to the leaderboard" —
                    // confusing when she already has a club (looks like it vanished, not loaded).
                    loadingCard
                } else if board.club == nil {
                    clubSetupCard
                } else {
                    levelCard
                    challengeCard
                    membershipRow
                    segmentedControl
                    if tab == .board { boardContent } else { feedContent }
                }

                if let errorMessage {
                    Text(errorMessage).font(RUFont.sans(11)).foregroundColor(RUColor.rose).padding(.top, 4)
                }

                if auth.isSignedIn {
                    // Published contact info, surfaced directly here rather than only buried in
                    // the privacy policy — App Store guideline 1.2.
                    Link("Signaler un problème ou nous contacter", destination: URL(string: "mailto:charlottegrudep@gmail.com")!)
                        .font(RUFont.sans(10.5))
                        .foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .task { await loadIfSignedIn() }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge).runUpSheetStyle(detents: [.height(300)])
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
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { Task { await loadIfSignedIn() } }
        }
        // Report reason picker — App Store guideline 1.2. `reportTarget` is set by the context
        // menus on leaderboard rows / feed items / the club itself.
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
        // Block confirmation — the other half of guideline 1.2, doesn't require leaving the club.
        .alert(
            "Bloquer \(pendingBlock?.name ?? "") ?",
            isPresented: Binding(get: { pendingBlock != nil }, set: { if !$0 { pendingBlock = nil } })
        ) {
            Button("Bloquer", role: .destructive) { Task { await confirmBlock() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tu ne verras plus son score ni ses activités, sans avoir à quitter le club.")
        }
    }

    /// The club's name doubles as the entry point to "Gestion du club" (invite code, member
    /// list, member profiles) — those used to be scattered across the main page (the invite code
    /// in particular sat as its own card, which read as clutter on a screen that's really about
    /// the leaderboard and feed).
    private var header: some View {
        HStack(alignment: .center) {
            if let club = board.club {
                Button(action: { showManagement = true }) {
                    VStack(alignment: .leading, spacing: 2) {
                        EyebrowLabel(text: "Le Club", color: RUColor.rose)
                        HStack(spacing: 6) {
                            Text(club.name).displayStyle(24).foregroundColor(RUColor.textPrimary)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(RUColor.text3)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    EyebrowLabel(text: "Le Club", color: RUColor.rose)
                    Text("Rejoins un club").displayStyle(24).foregroundColor(RUColor.textPrimary)
                }
            }
            Spacer()
            if let club = board.club {
                StatChip(text: "\(club.memberCount) membre\(club.memberCount > 1 ? "s" : "")", color: RUColor.text2, background: RUColor.card)
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showManagement) {
            if let club = board.club {
                ClubManagementView(
                    club: club,
                    members: board.leaderboard,
                    challenge: board.challenge,
                    onCreateChallenge: { title, targetKm, endDate in
                        try await createChallenge(title: title, targetKm: targetKm, endDate: endDate)
                    },
                    onReport: { member in
                        // Dismiss the sheet first, then set the target once its dismiss animation
                        // is out of the way — setting both in the same tick makes SwiftUI try to
                        // dismiss the sheet and present the confirmationDialog simultaneously,
                        // and one of the two silently loses.
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            reportTarget = ReportTarget(targetType: "user", targetId: member.id, displayName: member.name)
                        }
                    },
                    onBlock: { member in
                        showManagement = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            pendingBlock = (member.id, member.name)
                        }
                    },
                    onUpdateBio: { bio in try await updateBio(bio) }
                )
            }
        }
    }

    // MARK: Loading — signed in, real club status not back from the server yet

    private var loadingCard: some View {
        VStack(spacing: 10) {
            ProgressView().tint(RUColor.rose)
            Text("Chargement de ton club…").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: Not signed in

    private var signInPrompt: some View {
        VStack(spacing: 12) {
            AppMarkView(size: 44)
            Text("Le Club, c'est mieux à plusieurs").font(RUFont.sans(15, weight: .semibold)).foregroundColor(RUColor.textPrimary)
            Text("Connecte-toi pour rejoindre un vrai club, avec un classement et un fil d'activité alimentés par de vraies personnes.")
                .font(RUFont.sans(12)).foregroundColor(RUColor.text2).multilineTextAlignment(.center)
            Button("SE CONNECTER") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .ruCard()
    }

    // MARK: Signed in, no club yet

    private var clubSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                EyebrowLabel(text: "Créer un club", color: RUColor.rose2)
                HStack {
                    TextField("Nom du club", text: $newClubName)
                        .textFieldStyle(.plain)
                        .font(RUFont.sans(14))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    Button("Créer") { Task { await createClub() } }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: newClubName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading))
                        .disabled(newClubName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                EyebrowLabel(text: "Rejoindre avec un code", color: RUColor.rose2)
                HStack {
                    TextField("Code d'invitation", text: $joinCode)
                        .textFieldStyle(.plain)
                        .font(RUFont.mono(14))
                        .foregroundColor(RUColor.textPrimary)
                        .textInputAutocapitalization(.characters)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    Button("Rejoindre") { Task { await joinClub() } }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: joinCode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading))
                        .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
        }
        .padding(16)
        .ruCard()
    }

    /// The invite code used to sit here too, as its own card — now lives in "Gestion du club"
    /// (reached from the header) alongside the member list, so this row is just quick actions.
    private var membershipRow: some View {
        HStack {
            if let club = board.club {
                Button("Signaler ce club") {
                    reportTarget = ReportTarget(targetType: "club", targetId: club.id, displayName: "le club \(club.name)")
                }
                .font(RUFont.sans(11, weight: .semibold))
                .foregroundColor(RUColor.text3)
            }
            Spacer()
            Button("Quitter le club") { Task { await leaveClub() } }
                .font(RUFont.sans(11, weight: .semibold))
                .foregroundColor(RUColor.text3)
        }
    }

    // MARK: Signed in, in a club

    private var levelInfo: (level: Int, title: String, xpIntoLevel: Int, xpForLevel: Int) {
        let titles = ["Premiers pas", "Foulée légère", "Rythme trouvé", "Foulée d'or", "Vitesse de croisière", "Endurance de fer", "Élite locale"]
        let xp = auth.currentUser?.xpTotal ?? 0
        let xpPerLevel = 250
        let level = xp / xpPerLevel + 1
        let title = titles[(level - 1) % titles.count]
        return (level, title, xp % xpPerLevel, xpPerLevel)
    }

    private var levelCard: some View {
        let info = levelInfo
        return HStack(spacing: 14) {
            Text("\(info.level)").displayStyle(22).foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(LinearGradient(colors: [RUColor.violet, RUColor.rose], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Niveau \(info.level) · \(info.title)").font(RUFont.sans(16, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Text("\(info.xpIntoLevel) / \(info.xpForLevel) XP").font(RUFont.mono(10)).foregroundColor(RUColor.text2)
                }
                LinearBar(fraction: Double(info.xpIntoLevel) / Double(info.xpForLevel), color: RUColor.violet, gradient: LinearGradient(colors: [RUColor.violet, RUColor.rose], startPoint: .leading, endPoint: .trailing))
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(hex: 0x241046), Color(hex: 0x160B1F)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(RUColor.violet.opacity(0.3), lineWidth: RUSpacing.hairline))
    }

    private func daysLeft(until date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0)
    }

    /// Any member can set the club's challenge (see "Gestion du club") — this used to always show
    /// a fixed "100 km ce mois-ci" regardless of whether anyone had actually agreed to that goal.
    /// `progressKm` is a real sum computed server-side over every member's logged runs since the
    /// challenge was created, not just this device's local history.
    private var challengeCard: some View {
        Group {
            if let challenge = board.challenge {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        EyebrowLabel(text: "Défi du club", color: RUColor.rose2)
                        Spacer()
                        StatChip(text: "J-\(daysLeft(until: challenge.endDate))", color: RUColor.rose2)
                    }
                    Text(challenge.title).displayStyle(19).foregroundColor(RUColor.textPrimary)
                    LinearBar(fraction: challenge.targetKm > 0 ? min(1, challenge.progressKm / challenge.targetKm) : 0, color: RUColor.rose)
                    HStack {
                        Text("\(Int(challenge.progressKm)) / \(Int(challenge.targetKm)) km").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                        Spacer()
                        Text("ensemble").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                    }
                }
                .padding(16)
                .ruCard()
            } else {
                Button(action: { showManagement = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            EyebrowLabel(text: "Défi du club", color: RUColor.rose2)
                            Text("Aucun défi en cours — en créer un").font(RUFont.sans(13)).foregroundColor(RUColor.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(RUColor.rose2)
                    }
                    .padding(16)
                }
                .buttonStyle(PressableStyle())
                .ruCard()
            }
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 4) {
            segment("Classement", .board)
            segment("Fil d'activité", .feed)
        }
        .padding(3)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func segment(_ label: String, _ value: Tab) -> some View {
        Button(action: {
            tab = value
            if value == .feed && feed.isEmpty { Task { await loadFeed() } }
        }) {
            Text(label)
                .font(RUFont.sans(12.5, weight: .semibold))
                // White stays literal only when selected (background is the opaque RUColor.rose
                // accent fill below); unselected sits on the plain page/card surface and needs to
                // invert with the theme.
                .foregroundColor(tab == value ? .white : RUColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(tab == value ? RUColor.rose : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    /// "My" badges — the only place with real access to this device's local `RunRecord`/streak
    /// history, so the only place that can compute live progress toward a locked badge. Earned
    /// keys get synced to the server (see `syncBadgesIfNeeded`), which is what makes them show up
    /// on this profile for other club members too — see `ClubBadgeCatalog`.
    private var badges: [ClubBadge] {
        let intervalRuns = runs.filter { $0.title.localizedCaseInsensitiveContains("Fractionné") }.count
        let earlyRun = runs.contains { Calendar.current.component(.hour, from: $0.date) < 7 }
        let totalElevation = runs.reduce(0) { $0 + $1.elevationGainM }
        let earned: [String: Bool] = [
            "streak3": profile.streak >= 3,
            "interval3": intervalRuns >= 3,
            "earlyRun": earlyRun,
            "elevation300": totalElevation >= 300
        ]
        let progress: [String: String?] = [
            "streak3": "\(min(profile.streak, 3))/3 jours",
            "interval3": "\(min(intervalRuns, 3))/3 séances",
            "earlyRun": nil,
            "elevation300": "\(min(Int(totalElevation), 300))/300 m"
        ]
        return ClubBadgeCatalog.all.map { def in
            ClubBadge(
                key: def.key, emoji: def.emoji, name: def.name, detail: def.detail,
                progressText: progress[def.key] ?? nil,
                earned: earned[def.key] ?? false
            )
        }
    }

    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 6) {
                ForEach(board.leaderboard) { entry in
                    HStack(spacing: 12) {
                        Text(entry.rank >= 1 && entry.rank <= 3 ? ["🥇", "🥈", "🥉"][entry.rank - 1] : "\(entry.rank)")
                            .displayStyle(15)
                            .foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.text2)
                            .frame(width: 20)
                        Text(entry.isMe ? "\(entry.name) · toi" : entry.name)
                            .font(RUFont.sans(13, weight: entry.isMe ? .semibold : .regular))
                            .foregroundColor(RUColor.textPrimary)
                        Spacer()
                        Text("\(entry.xp)").displayStyle(15).foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.textPrimary)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(entry.isMe ? RUColor.rose.opacity(0.1) : RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(entry.isMe ? RUColor.rose.opacity(0.28) : RUColor.line, lineWidth: RUSpacing.hairline))
                    .contextMenu {
                        if !entry.isMe {
                            Button("Signaler \(entry.name)") {
                                reportTarget = ReportTarget(targetType: "user", targetId: entry.id, displayName: entry.name)
                            }
                            Button("Bloquer \(entry.name)", role: .destructive) {
                                pendingBlock = (entry.id, entry.name)
                            }
                        }
                    }
                }
            }

            EyebrowLabel(text: "Derniers badges", color: RUColor.text3)
            HStack(spacing: 10) {
                ForEach(badges) { badge in
                    Button(action: { selectedBadge = badge }) {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(badge.earned ? RUColor.card : RUColor.card2)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(Text(badge.emoji).font(.system(size: 26)))
                                .opacity(badge.earned ? 1 : 0.35)
                            Text(badge.name).font(RUFont.sans(8, weight: .semibold)).foregroundColor(RUColor.text2)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var feedContent: some View {
        VStack(spacing: 8) {
            if feed.isEmpty && !isLoading {
                Text("Personne n'a encore rien posté — sois la première !")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            ForEach(feed) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Circle().fill(RUColor.rose).frame(width: 34, height: 34)
                            .overlay(Text(String(item.name.prefix(1))).displayStyle(13).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            (Text(item.name).fontWeight(.semibold) + Text(" \(item.text)"))
                                .font(RUFont.sans(13))
                                .foregroundColor(RUColor.textPrimary)
                            Text(item.createdAt.relativeDescription).font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        Button(action: {
                            Haptics.impact(.light)
                            Task { await toggleKudos(item) }
                        }) {
                            HStack(spacing: 6) {
                                Text("👏")
                                Text("\(item.kudos)")
                            }
                            .font(RUFont.sans(11.5, weight: .semibold))
                            .foregroundColor(item.kudoedByMe ? RUColor.rose2 : RUColor.text2)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(item.kudoedByMe ? RUColor.rose.opacity(0.16) : RUColor.card2, in: Capsule())
                            .overlay(Capsule().stroke(item.kudoedByMe ? RUColor.rose.opacity(0.35) : RUColor.line, lineWidth: RUSpacing.hairline))
                            .scaleEffect(item.kudoedByMe ? 1.08 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.45), value: item.kudoedByMe)
                        }
                        .buttonStyle(PressableStyle())

                        Button(action: { commentsActivity = item }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left")
                                Text("\(item.commentsCount)")
                            }
                            .font(RUFont.sans(11.5, weight: .semibold))
                            .foregroundColor(RUColor.text2)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(RUColor.card2, in: Capsule())
                            .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(13)
                .ruCard()
                .contextMenu {
                    if item.userId != auth.currentUser?.id {
                        Button("Signaler cette activité") {
                            reportTarget = ReportTarget(targetType: "activity", targetId: item.id, displayName: "l'activité de \(item.name)")
                        }
                        Button("Bloquer \(item.name)", role: .destructive) {
                            pendingBlock = (item.userId, item.name)
                        }
                    }
                }
            }
        }
    }

    // MARK: Networking

    private func loadIfSignedIn() async {
        guard auth.isSignedIn else { return }
        isLoading = true
        errorMessage = nil
        // These three requests used to run one after another (refreshMe → fetchBoard → feed),
        // each paying its own network/cold-start latency on top of the last — the real cause of
        // the ~5s wait before this tab showed anything (the create/join form sat there the whole
        // time). None of them actually depends on another's result, so firing them concurrently
        // cuts the wait to the slowest single request instead of the sum of all three.
        async let meAttempt = try? await auth.refreshMe()
        async let boardAttempt = try? await clubService.fetchBoard()
        async let feedAttempt = try? await clubService.fetchFeed()
        let (_, boardResult, feedResult) = await (meAttempt, boardAttempt, feedAttempt)

        if let boardResult {
            board = boardResult
            syncBadgesIfNeeded()
        } else {
            errorMessage = "Impossible de charger le club — vérifie ta connexion."
        }
        // Piggyback a kudos check on every Club tab open, not just when switching to the
        // "Fil d'activité" segment — otherwise a new kudos notification only ever surfaces if she
        // happens to tap into the feed specifically.
        if let feedResult {
            feed = feedResult
            notifyNewKudos(in: feedResult)
            notifyNewComments(in: feedResult)
        }
        isLoading = false
    }

    private func loadFeed() async {
        do {
            feed = try await clubService.fetchFeed()
            notifyNewKudos(in: feed)
            notifyNewComments(in: feed)
        } catch {
            errorMessage = "Impossible de charger le fil d'activité."
        }
    }

    /// Real kudos notifications — compares each of *your own* posts' current kudos count against
    /// what was last seen (`profile.kudosSeenCounts`, keyed by activity id) and posts one bell
    /// notification per post that gained new kudos since. Only ever moves forward (kudos are
    /// additive from this client's point of view), so a post that lost kudos some other way isn't
    /// treated as new claps by mistake.
    private func notifyNewKudos(in feed: [FeedItem]) {
        guard let myId = auth.currentUser?.id else { return }
        for item in feed where item.userId == myId {
            let seen = profile.kudosSeenCounts[item.id] ?? 0
            if item.kudos > seen {
                let gained = item.kudos - seen
                appState.notify(
                    icon: "👏", colorHex: 0xFF3B6B,
                    title: "Nouveaux encouragements",
                    text: gained == 1 ? "Quelqu'un a applaudi ta séance." : "\(gained) personnes ont applaudi ta séance."
                )
            }
            profile.kudosSeenCounts[item.id] = item.kudos
        }
    }

    private func createClub() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await clubService.createClub(name: newClubName.trimmingCharacters(in: .whitespaces))
            newClubName = ""
            board = try await clubService.fetchBoard()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = "Ce nom n'est pas autorisé — choisis-en un autre."
        } catch {
            errorMessage = "Impossible de créer le club."
        }
        isLoading = false
    }

    /// Sets the club's active challenge and updates `board` immediately so the card on the main
    /// page reflects it without a full refetch. Throws (rather than setting `errorMessage`, which
    /// lives on the page underneath) so the create-challenge form — its own sheet stacked on top
    /// of "Gestion du club" — can show its own inline error.
    private func createChallenge(title: String, targetKm: Double, endDate: Date) async throws {
        let challenge = try await clubService.createChallenge(title: title, targetKm: targetKm, endDate: endDate)
        board.challenge = challenge
    }

    private func joinClub() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await clubService.joinClub(inviteCode: joinCode.trimmingCharacters(in: .whitespaces))
            joinCode = ""
            board = try await clubService.fetchBoard()
        } catch ClubServiceError.badResponse(404, _) {
            errorMessage = "Code d'invitation introuvable."
        } catch {
            errorMessage = "Impossible de rejoindre ce club."
        }
        isLoading = false
    }

    private func leaveClub() async {
        do {
            try await clubService.leaveClub()
            board = ClubBoard(club: nil, leaderboard: [])
            feed = []
        } catch {
            errorMessage = "Impossible de quitter le club."
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
            // Roll back on failure — the optimistic toggle above was wrong.
            feed[index].kudoedByMe = wasKudoed
            feed[index].kudos += wasKudoed ? 1 : -1
        }
    }

    /// Optimistic local bump after posting a comment — avoids a full feed refetch just to reflect
    /// the +1 this device already knows about.
    private func bumpCommentsCount(_ activityId: String) {
        guard let index = feed.firstIndex(where: { $0.id == activityId }) else { return }
        feed[index].commentsCount += 1
        if let myId = auth.currentUser?.id, feed[index].userId == myId {
            profile.commentsSeenCounts[activityId] = feed[index].commentsCount
        }
    }

    /// Same idea as `notifyNewKudos`: compares each of your own posts' current comment count
    /// against what was last seen and posts one bell notification per post that gained new
    /// comments since — never for comments left by yourself in `ActivityCommentsSheet`, since
    /// `bumpCommentsCount` above already advances the "seen" mark for those.
    private func notifyNewComments(in feed: [FeedItem]) {
        guard let myId = auth.currentUser?.id else { return }
        for item in feed where item.userId == myId {
            let seen = profile.commentsSeenCounts[item.id] ?? 0
            if item.commentsCount > seen {
                let gained = item.commentsCount - seen
                appState.notify(
                    icon: "💬", colorHex: 0xFF3B6B,
                    title: "Nouveaux commentaires",
                    text: gained == 1 ? "Quelqu'un a commenté ta séance." : "\(gained) personnes ont commenté ta séance."
                )
            }
            profile.commentsSeenCounts[item.id] = item.commentsCount
        }
    }

    /// Saves the caller's own club-profile status and mirrors it into the local leaderboard so
    /// re-opening "Gestion du club" reflects it immediately, without a full refetch.
    private func updateBio(_ bio: String) async throws {
        let saved = try await clubService.updateBio(bio)
        if let index = board.leaderboard.firstIndex(where: { $0.isMe }) {
            board.leaderboard[index].bio = saved
        }
    }

    /// Syncs whichever of `badges` are currently earned up to the server — harmless to call every
    /// time the board loads (the server upserts with `ON CONFLICT DO NOTHING`), and it's what
    /// makes an achievement earned on this device show up on this member's profile for everyone
    /// else in the club, not just locally.
    private func syncBadgesIfNeeded() {
        let earnedKeys = badges.filter { $0.earned }.map { $0.key }
        guard !earnedKeys.isEmpty else { return }
        Task { try? await clubService.syncBadges(earnedKeys) }
    }

    private func submitReport(_ target: ReportTarget, reason: String) async {
        do {
            try await clubService.report(targetType: target.targetType, targetId: target.targetId, reason: reason)
            appState.toast("Signalement envoyé — merci")
        } catch {
            appState.toast("Impossible d'envoyer le signalement, réessaie.")
        }
    }

    private func confirmBlock() async {
        guard let pendingBlock else { return }
        do {
            try await clubService.blockUser(userId: pendingBlock.userId)
            // Refresh so the blocked person disappears from the leaderboard/feed immediately —
            // both refetches only depend on blockUser having completed, not on each other, so
            // they run concurrently instead of paying two round trips back to back.
            async let boardAttempt = clubService.fetchBoard()
            async let feedAttempt = clubService.fetchFeed()
            (board, feed) = try await (boardAttempt, feedAttempt)
        } catch {
            errorMessage = "Impossible de bloquer cette personne."
        }
    }
}

/// Identifies what a report is about — a club, a user, or one activity — so the reason picker
/// can post to `api/moderation/report` with the right target.
private struct ReportTarget: Identifiable {
    let id = UUID()
    var targetType: String
    var targetId: String
    var displayName: String
}

/// One badge tile's real state — `key` matches `ClubBadgeCatalog`/the server's `KNOWN_BADGES`, so
/// this same shape works whether the progress/earned state came from local data (mine, in
/// `ClubView`) or from another member's synced `badgeKeys` (`ClubMemberProfileView`). Internal
/// (not private) since both files construct one.
struct ClubBadge: Identifiable {
    let id = UUID()
    var key: String
    var emoji: String
    var name: String
    var detail: String
    /// nil for binary badges ("Lève-tôt") or whenever there's no local data to compute progress
    /// from (any badge on someone else's profile).
    var progressText: String?
    var earned: Bool
}

/// Was previously just a static, untappable tile — no way to know what a badge required or how
/// close she was to earning a locked one. Tapping now opens this real detail instead. Internal so
/// `ClubMemberProfileView` can reuse it for other members' badges too.
struct BadgeDetailView: View {
    var badge: ClubBadge

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(badge.earned ? RUColor.card : RUColor.card2)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                .frame(width: 76, height: 76)
                .overlay(Text(badge.emoji).font(.system(size: 34)))
                .opacity(badge.earned ? 1 : 0.4)
                .padding(.top, 22)

            Text(badge.name).font(RUFont.sans(17, weight: .semibold)).foregroundColor(RUColor.textPrimary)

            StatChip(
                text: badge.earned ? "Débloqué" : "Pas encore débloqué",
                color: badge.earned ? RUColor.lime : RUColor.text3,
                background: badge.earned ? RUColor.lime.opacity(0.14) : RUColor.card2
            )

            Text(badge.detail)
                .font(RUFont.sans(13)).foregroundColor(RUColor.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            if let progressText = badge.progressText, !badge.earned {
                Text(progressText).font(RUFont.mono(13, weight: .semibold)).foregroundColor(RUColor.rose2)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(RUColor.bg)
    }
}

extension Date {
    /// Shared with `ActivityCommentsSheet` — one relative-time formatter for the feed and its
    /// comment threads instead of two copies.
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
