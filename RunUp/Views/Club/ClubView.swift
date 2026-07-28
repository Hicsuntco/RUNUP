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
    @State private var showLeaveConfirm = false
    @State private var showCreateEvent = false
    /// My own feed activity pending delete confirmation (appui long → Supprimer).
    @State private var pendingDeleteActivity: FeedItem?
    /// Which board the Classement tab shows — the fresh Monday-reset km race, all-time XP, or the
    /// opt-in global weekly board across every club.
    @State private var boardMode: BoardMode = .week
    /// Nil until the global board has been fetched at least once (lazy — most people never tap
    /// it) — distinct from `optedIn` inside it, which reflects HER OWN current opt-in state.
    @State private var globalBoard: GlobalWeeklyBoard?
    @State private var isLoadingGlobal = false

    private enum BoardMode { case week, general, global }
    /// Drives the feed rows' staggered entrance — flipped once the first feed load lands, after
    /// which each row's own per-index delay takes over (same pattern as `RecapView`'s splits).
    @State private var feedRevealed = false

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
                    weekPulseCard
                    challengeCard
                    eventsCard
                    membershipRow
                    segmentedControl
                    Group {
                        if tab == .board { boardContent } else { feedContent }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let errorMessage {
                    // Was color-only (rose text, no icon) — reads as regular text rather than an
                    // error, especially on a light theme with a pale accent swatch selected.
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                        Text(errorMessage).font(RUFont.sans(11))
                    }
                    .foregroundColor(RUColor.rose)
                    .padding(.top, 4)
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
        .refreshable { await loadIfSignedIn() }
        .onChange(of: feed.count) { _, count in
            if count > 0 { feedRevealed = true }
        }
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
            // Same synchronous capture as the delete alert below — the alert's dismissal nils
            // `pendingBlock` before an async Task body would read it (silent no-op otherwise).
            Button("Bloquer", role: .destructive) {
                if let target = pendingBlock {
                    Task { await confirmBlock(target.userId) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tu ne verras plus son score ni ses activités, sans avoir à quitter le club.")
        }
        // Deleting my own feed post — permanent (kudos et commentaires partent avec), so it
        // confirms instead of firing straight from the context menu.
        .alert(
            "Supprimer cette activité ?",
            isPresented: Binding(get: { pendingDeleteActivity != nil }, set: { if !$0 { pendingDeleteActivity = nil } })
        ) {
            // The item is captured SYNCHRONOUSLY here: dismissing the alert nils
            // `pendingDeleteActivity` before an async Task body would get to read it, which made
            // the whole action a silent no-op.
            Button("Supprimer", role: .destructive) {
                if let item = pendingDeleteActivity {
                    Task { await confirmDeleteActivity(item) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Elle disparaîtra du fil du club, avec ses applaudissements et commentaires. Tes XP restent acquis.")
        }
    }

    private func confirmDeleteActivity(_ item: FeedItem) async {
        do {
            try await clubService.deleteActivity(activityId: item.id)
            await MainActor.run {
                feed.removeAll { $0.id == item.id }
                appState.toast("Activité supprimée du fil.")
            }
        } catch {
            await MainActor.run { appState.toast("Suppression impossible — réessaie.") }
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
                            Text(club.name).displayStyle(24).foregroundColor(RUColor.textPrimary).lineLimit(1).minimumScaleFactor(0.6)
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

    /// A spinner + explicit "Chargement du club…" — the skeleton-rows version read as a broken/
    /// empty "Rejoins un club" screen (owner's call: the plain message says what's happening).
    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(RUColor.rose)
            Text("Chargement du club…")
                .font(RUFont.sans(13, weight: .semibold))
                .foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .ruCard()
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
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            Spacer()
            // Confirmation + in-flight guard — one accidental tap used to leave the club
            // instantly (rejoining needs the invite code again), and a double-tap made the second
            // call fail with a misleading error after the first had already succeeded.
            Button("Quitter le club") { showLeaveConfirm = true }
                .font(RUFont.sans(11, weight: .semibold))
                .foregroundColor(RUColor.text3)
                .disabled(isLoading)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .confirmationDialog("Quitter le club ?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
                    Button("Quitter", role: .destructive) { Task { await leaveClub() } }
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text("Tu devras redemander le code d'invitation pour revenir.")
                }
        }
    }

    // MARK: Signed in, in a club

    private var levelInfo: (level: Int, title: String, xpIntoLevel: Int, xpForLevel: Int) {
        let titles = ["Premiers pas", "Foulée légère", "Rythme trouvé", "Foulée d'or", "Vitesse de croisière", "Endurance de fer", "Élite locale"]
        let xp = auth.currentUser?.xpTotal ?? 0
        let xpPerLevel = 250
        let level = xp / xpPerLevel + 1
        let title = titles[min(max(level - 1, 0), titles.count - 1)]
        return (level, title, xp % xpPerLevel, xpPerLevel)
    }

    private var levelCard: some View {
        let info = levelInfo
        return HStack(spacing: 14) {
            Text("\(info.level)").displayStyle(22).foregroundColor(.white)
                .contentTransition(.numericText())
                .frame(width: 52, height: 52)
                .background(LinearGradient(colors: [RUColor.violet, RUColor.rose], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Niveau \(info.level) · \(info.title)").font(RUFont.sans(16, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    // Fixed light-on-dark — this card keeps its dark violet gradient in BOTH
                    // themes, so theme-aware text2 went dark-on-dark in light mode.
                    Text("\(info.xpIntoLevel) / \(info.xpForLevel) XP").font(RUFont.mono(10)).foregroundColor(.white.opacity(0.65))
                        .contentTransition(.numericText())
                }
                LinearBar(fraction: Double(info.xpIntoLevel) / Double(info.xpForLevel), color: RUColor.violet, gradient: RUColor.violetRoseGradient)
            }
        }
        .animation(.easeOut(duration: 0.4), value: info.level)
        .animation(.easeOut(duration: 0.4), value: info.xpIntoLevel)
        .padding(16)
        .background(LinearGradient(colors: [Color(hex: 0x241046), Color(hex: 0x160B1F)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: RUSpacing.radiusHero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusHero, style: .continuous).stroke(RUColor.violet.opacity(0.3), lineWidth: RUSpacing.hairline))
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

    private func boardModeChip(_ label: String, _ value: BoardMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { boardMode = value }
            if value == .global && globalBoard == nil { Task { await loadGlobalBoard() } }
        }) {
            Text(label)
                .font(RUFont.sans(11, weight: .semibold))
                .foregroundColor(boardMode == value ? RUColor.rose2 : RUColor.text2)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(boardMode == value ? RUColor.rose.opacity(0.12) : RUColor.card2, in: Capsule())
                .overlay(Capsule().stroke(boardMode == value ? RUColor.rose.opacity(0.4) : RUColor.line, lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
    }

    private func segment(_ label: String, _ value: Tab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { tab = value }
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
        let nightRun = runs.contains { Calendar.current.component(.hour, from: $0.date) >= 21 }
        let totalElevation = runs.reduce(0) { $0 + $1.elevationGainM }
        let totalDistance = runs.reduce(0) { $0 + $1.distanceKm }
        let longestRun = runs.map(\.distanceKm).max() ?? 0
        let weekendRuns = runs.filter { [1, 7].contains(Calendar.current.component(.weekday, from: $0.date)) }.count
        let earned: [String: Bool] = [
            "streak3": profile.streak >= 3,
            "interval3": intervalRuns >= 3,
            "earlyRun": earlyRun,
            "elevation300": totalElevation >= 300,
            "firstRun": !runs.isEmpty,
            "streak7": profile.streak >= 7,
            "streak30": profile.streak >= 30,
            "tenRuns": runs.count >= 10,
            "fiftyRuns": runs.count >= 50,
            "distance50": totalDistance >= 50,
            "distance250": totalDistance >= 250,
            "distance1000": totalDistance >= 1000,
            "halfMarathonDistance": longestRun >= 21,
            "marathonDistance": longestRun >= 42,
            "nightRun": nightRun,
            "weekendWarrior": weekendRuns >= 10
        ]
        let progress: [String: String?] = [
            "streak3": "\(min(profile.streak, 3))/3 jours",
            "interval3": "\(min(intervalRuns, 3))/3 séances",
            "earlyRun": nil,
            "elevation300": "\(min(Int(totalElevation), 300))/300 m",
            "firstRun": nil,
            "streak7": "\(min(profile.streak, 7))/7 jours",
            "streak30": "\(min(profile.streak, 30))/30 jours",
            "tenRuns": "\(min(runs.count, 10))/10",
            "fiftyRuns": "\(min(runs.count, 50))/50",
            "distance50": "\(min(Int(totalDistance), 50))/50 km",
            "distance250": "\(min(Int(totalDistance), 250))/250 km",
            "distance1000": "\(min(Int(totalDistance), 1000))/1000 km",
            "halfMarathonDistance": "\(String(format: "%.1f", min(longestRun, 21)))/21 km",
            "marathonDistance": "\(String(format: "%.1f", min(longestRun, 42)))/42 km",
            "nightRun": nil,
            "weekendWarrior": "\(min(weekendRuns, 10))/10"
        ]
        return ClubBadgeCatalog.all.map { def in
            ClubBadge(
                key: def.key, emoji: def.emoji, name: def.name, detail: def.detail,
                progressText: progress[def.key] ?? nil,
                earned: earned[def.key] ?? false
            )
        }
    }

    /// The club's pulse this week — real collective km + how many members actually ran, computed
    /// server-side over this Monday-started week. Gives the club a shared "we" number, not just
    /// individual rankings.
    private var weekPulseCard: some View {
        let stats = board.weekStats
        let km = String(format: "%.1f", locale: Locale(identifier: "fr_FR"), stats?.totalKm ?? 0)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                EyebrowLabel(text: "Le club cette semaine", color: RUColor.rose)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(km).displayStyle(26).foregroundColor(RUColor.textPrimary)
                    Text("KM").font(RUFont.sans(10, weight: .bold)).foregroundColor(RUColor.text2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats?.activeMembers ?? 0)").displayStyle(20).foregroundColor(RUColor.rose2)
                Text(stats?.activeMembers == 1 ? "membre actif" : "membres actifs")
                    .font(RUFont.sans(10)).foregroundColor(RUColor.text2)
            }
        }
        .padding(14)
        .ruCard()
    }

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM · HH:mm"
        return f
    }()

    /// Sorties de groupe — real proposed group runs with RSVP. The one feature that turns a
    /// leaderboard into an actual club: people running TOGETHER.
    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(text: "Sorties de groupe", color: RUColor.violet)
                Spacer()
                Button(action: { showCreateEvent = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Proposer").font(RUFont.sans(11, weight: .semibold))
                    }
                    .foregroundColor(RUColor.rose2)
                }
                .buttonStyle(PressableStyle())
            }
            if (board.events ?? []).isEmpty {
                Text("Aucune sortie prévue — propose un créneau, les autres n'ont qu'à dire « J'y serai ».")
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text3)
            }
            ForEach(board.events ?? []) { event in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.eventDateFormatter.string(from: event.startsAt).uppercased())
                            .font(RUFont.sans(9, weight: .bold)).tracking(0.6).foregroundColor(RUColor.rose2)
                        Text(event.title).font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin").font(.system(size: 8))
                                Text(location).font(RUFont.sans(10.5))
                            }
                            .foregroundColor(RUColor.text2)
                        }
                    }
                    Spacer()
                    Button(action: { toggleRsvp(event) }) {
                        VStack(spacing: 2) {
                            Text(event.goingByMe ? "J'y serai ✓" : "J'y serai")
                                .font(RUFont.sans(11, weight: .bold))
                                .foregroundColor(event.goingByMe ? .white : RUColor.textPrimary)
                                .padding(.horizontal, 11).padding(.vertical, 6)
                                .background(event.goingByMe ? RUColor.rose : RUColor.card, in: Capsule())
                                .overlay(Capsule().stroke(event.goingByMe ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                            Text("\(event.going) au départ")
                                .font(RUFont.sans(9)).foregroundColor(RUColor.text2)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(12)
                .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                .contextMenu {
                    if event.isMine {
                        Button("Annuler cette sortie", role: .destructive) { deleteEvent(event) }
                    }
                }
            }
        }
        .padding(14)
        .ruCard()
        .sheet(isPresented: $showCreateEvent) {
            CreateEventSheet { title, location, date in
                let created = try await clubService.createEvent(title: title, location: location, startsAt: date)
                await MainActor.run {
                    var events = board.events ?? []
                    events.append(created)
                    events.sort { $0.startsAt < $1.startsAt }
                    board.events = events
                }
            }
            .runUpSheetStyle()
        }
    }

    private func toggleRsvp(_ event: ClubEvent) {
        Haptics.selection()
        Task {
            do {
                let result = try await clubService.toggleEventRsvp(eventId: event.id)
                await MainActor.run {
                    if let index = board.events?.firstIndex(where: { $0.id == event.id }) {
                        board.events?[index].goingByMe = result.going
                        board.events?[index].going = result.count
                    }
                }
            } catch ClubServiceError.badResponse(404, _) {
                // The event was already cancelled/expired server-side — leaving it in the local
                // list would just let her tap it again and fail identically every time.
                await MainActor.run { board.events?.removeAll { $0.id == event.id } }
            } catch {
                await MainActor.run { appState.toast("Impossible de répondre — réessaie.") }
            }
        }
    }

    private func deleteEvent(_ event: ClubEvent) {
        Task {
            do {
                try await clubService.deleteEvent(eventId: event.id)
                await MainActor.run { board.events?.removeAll { $0.id == event.id } }
            } catch ClubServiceError.badResponse(404, _) {
                // Already gone server-side — still fine to drop it locally.
                await MainActor.run { board.events?.removeAll { $0.id == event.id } }
            } catch {
                // A real failure (network, 403 not-the-creator, ...) — keep it in the list rather
                // than silently pretending the cancel worked when it didn't.
                await MainActor.run { appState.toast("Impossible d'annuler la sortie — réessaie.") }
            }
        }
    }

    /// Split out of what used to be one large `boardContent` body — three near-identical ~25-line
    /// row blocks plus a triple `if`/`.transition()` chain in a single ViewBuilder expression was
    /// enough to blow the type-checker's budget (`unable to type-check this expression in
    /// reasonable time`, a real build failure on-device, not just a style nit). Breaking it into
    /// these smaller pieces is exactly the fix Xcode's own error message suggests, and doubles as
    /// the same `Group { if ... }` fix `HomeView.programWeekCard` already needed elsewhere in this
    /// app: an `if` with no `else` can't take a modifier directly.
    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Two real races: km of THIS week (Monday reset — a newcomer can win her first week)
            // and the all-time XP board.
            HStack(spacing: 6) {
                boardModeChip("Cette semaine", .week)
                boardModeChip("Général (XP)", .general)
                boardModeChip("Mondial", .global)
            }
            Group {
                if boardMode == .week {
                    weekBoardContent
                } else if boardMode == .general {
                    generalBoardContent
                } else {
                    globalBoardContent
                }
            }
            .transition(.opacity)

            EyebrowLabel(text: "Derniers badges", color: RUColor.text3)
            badgeStrip
        }
    }

    private var weekBoardContent: some View {
        Group {
            if (board.weekly ?? []).isEmpty && !isLoading {
                Text("Personne n'a encore couru cette semaine — lance-toi !")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            VStack(spacing: 6) {
                ForEach(board.weekly ?? []) { entry in
                    weekRow(entry)
                }
            }
        }
    }

    private func weekRow(_ entry: WeeklyRow) -> some View {
        HStack(spacing: 12) {
            Text(entry.rank >= 1 && entry.rank <= 3 ? ["🥇", "🥈", "🥉"][entry.rank - 1] : "\(entry.rank)")
                .displayStyle(15)
                .foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.text2)
                .frame(width: 20)
            AvatarView(urlString: entry.avatarUrl, base64DataURI: entry.avatarBase64, initial: String(entry.name.prefix(1)), size: 28)
            Text(entry.isMe ? "\(entry.name) · toi" : entry.name)
                .font(RUFont.sans(13, weight: entry.isMe ? .semibold : .regular))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text("\(String(format: "%.1f", locale: Locale(identifier: "fr_FR"), entry.weekKm)) km")
                .displayStyle(14).foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.textPrimary)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(entry.isMe ? RUColor.rose.opacity(0.1) : RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(entry.isMe ? RUColor.rose.opacity(0.28) : RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private var generalBoardContent: some View {
        VStack(spacing: 6) {
            ForEach(board.leaderboard) { entry in
                generalRow(entry)
            }
        }
    }

    private func generalRow(_ entry: LeaderboardRow) -> some View {
        HStack(spacing: 12) {
            Text(entry.rank >= 1 && entry.rank <= 3 ? ["🥇", "🥈", "🥉"][entry.rank - 1] : "\(entry.rank)")
                .displayStyle(15)
                .foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.text2)
                .frame(width: 20)
            AvatarView(urlString: entry.avatarUrl, base64DataURI: entry.avatarBase64, initial: String(entry.name.prefix(1)), size: 28)
            Text(entry.isMe ? "\(entry.name) · toi" : entry.name)
                .font(RUFont.sans(13, weight: entry.isMe ? .semibold : .regular))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    private var badgeStrip: some View {
        HStack(spacing: 10) {
            ForEach(badges) { badge in
                Button(action: { selectedBadge = badge }) {
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(badge.earned ? RUColor.card : RUColor.card2)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(badge.earned ? RUColor.rose.opacity(0.35) : RUColor.line, lineWidth: RUSpacing.hairline))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Text(badge.emoji).font(.system(size: 26)))
                            .opacity(badge.earned ? 1 : 0.35)
                            // A real glow on earned tiles — opacity alone made locked vs.
                            // earned read as "faded vs. normal" rather than "locked vs. won".
                            .shadow(color: badge.earned ? RUColor.rose.opacity(0.3) : .clear, radius: 8, x: 0, y: 3)
                        Text(badge.name).font(RUFont.sans(8, weight: .semibold)).foregroundColor(badge.earned ? RUColor.textPrimary : RUColor.text2)
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    /// The opt-in global weekly board — every club's members compete on the SAME real km-this-
    /// week race the club board already shows, just across the whole platform instead of one
    /// club. Off by default (see `global_leaderboard_opt_in`): a real, explicit choice since
    /// this exposes her name/photo/km to people outside her own club.
    private var globalBoardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Classement mondial").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                    Text("Visible par tout le monde, pas juste ton club.")
                        .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                }
                Spacer()
                if let globalBoard {
                    Toggle("", isOn: Binding(get: { globalBoard.optedIn }, set: { _ in toggleGlobalOptIn() }))
                        .labelsHidden()
                        .tint(RUColor.rose)
                        .accessibilityLabel("Rejoindre le classement mondial")
                }
            }
            .padding(14)
            .ruCard()

            if isLoadingGlobal && globalBoard == nil {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if let globalBoard {
                if !globalBoard.optedIn {
                    Text("Active le classement mondial pour voir où tu te situes parmi tous les coureurs RunUp cette semaine.")
                        .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                } else if globalBoard.entries.isEmpty {
                    Text("Personne n'a encore couru cette semaine — sois la première !")
                        .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                } else {
                    VStack(spacing: 6) {
                        ForEach(globalBoard.entries) { entry in
                            HStack(spacing: 12) {
                                Text(entry.rank >= 1 && entry.rank <= 3 ? ["🥇", "🥈", "🥉"][entry.rank - 1] : "\(entry.rank)")
                                    .displayStyle(15)
                                    .foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.text2)
                                    .frame(width: 20)
                                AvatarView(urlString: entry.avatarUrl, base64DataURI: entry.avatarBase64, initial: String(entry.name.prefix(1)), size: 28)
                                Text(entry.isMe ? "\(entry.name) · toi" : entry.name)
                                    .font(RUFont.sans(13, weight: entry.isMe ? .semibold : .regular))
                                    .foregroundColor(RUColor.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Text("\(String(format: "%.1f", locale: Locale(identifier: "fr_FR"), entry.weekKm)) km")
                                    .displayStyle(14).foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.textPrimary)
                            }
                            .padding(.horizontal, 13).padding(.vertical, 11)
                            .background(entry.isMe ? RUColor.rose.opacity(0.1) : RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(entry.isMe ? RUColor.rose.opacity(0.28) : RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                    }
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

    private func loadIfSignedIn() async {
        guard auth.isSignedIn else { return }
        // Opportunistic: retries anything still stuck in the local outbox from a prior failed
        // `postClubActivity` (see ClubActivityOutbox.swift) — e.g. a run posted on a spotty
        // connection right before she opened Club to check the leaderboard.
        appState.retryPendingClubActivities()
        // A cached board/feed from a prior visit (see `AppState.cachedClubBoard`) renders
        // immediately instead of blanking to the loading spinner on every single re-visit — the
        // fetch below still runs to catch up, it just doesn't need to gate the UI this time.
        if let cachedBoard = appState.cachedClubBoard {
            board = cachedBoard
            isLoading = false
        }
        if let cachedFeed = appState.cachedClubFeed {
            feed = cachedFeed
        }
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
            appState.cachedClubBoard = boardResult
            syncBadgesIfNeeded()
        } else if appState.cachedClubBoard == nil {
            // Only surface the error when there's nothing already on screen to fall back to — a
            // background refresh failing quietly behind still-valid cached content beats replacing
            // it with an error banner over data that was fine a moment ago.
            errorMessage = "Impossible de charger le club — vérifie ta connexion."
        }
        // Piggyback a kudos check on every Club tab open, not just when switching to the
        // "Fil d'activité" segment — otherwise a new kudos notification only ever surfaces if she
        // happens to tap into the feed specifically.
        if let feedResult {
            feed = feedResult
            appState.cachedClubFeed = feedResult
            notifyNewKudos(in: feedResult)
            notifyNewComments(in: feedResult)
        } else if errorMessage == nil, appState.cachedClubFeed == nil {
            // Board can still have loaded fine while this alone failed — without this, a failed
            // feed fetch left `feed` empty with zero indication, so "Fil d'activité" read as a
            // genuinely empty club instead of a failed load.
            errorMessage = "Impossible de charger le fil d'activité — vérifie ta connexion."
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

    private func loadGlobalBoard() async {
        isLoadingGlobal = true
        globalBoard = try? await clubService.fetchGlobalWeekly()
        isLoadingGlobal = false
    }

    private func toggleGlobalOptIn() {
        guard let current = globalBoard?.optedIn else { return }
        let next = !current
        globalBoard?.optedIn = next
        Haptics.selection()
        Task {
            do {
                try await clubService.setGlobalLeaderboardOptIn(next)
                await loadGlobalBoard()
            } catch {
                await MainActor.run {
                    globalBoard?.optedIn = current
                    appState.toast("Impossible de mettre à jour — réessaie.")
                }
            }
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
        guard !isLoading else { return }
        isLoading = true
        do {
            try await clubService.leaveClub()
            board = ClubBoard(club: nil, leaderboard: [])
            feed = []
            // Without this, re-opening Club after leaving would briefly show the OLD club's cached
            // board/feed (see AppState.cachedClubBoard) before the next fetch caught up.
            appState.cachedClubBoard = nil
            appState.cachedClubFeed = nil
            // Both dictionaries are keyed by activity UUIDs from the club she's leaving — none of
            // those ids can ever appear in a feed she can see again, so without this they'd just
            // accumulate permanently in UserProfile across every club she's ever cycled through.
            profile.kudosSeenCounts.removeAll()
            profile.commentsSeenCounts.removeAll()
        } catch {
            errorMessage = "Impossible de quitter le club."
        }
        isLoading = false
    }

    private func toggleKudos(_ item: FeedItem) async {
        guard let index = feed.firstIndex(where: { $0.id == item.id }) else { return }
        let wasKudoed = feed[index].kudoedByMe
        feed[index].kudoedByMe.toggle()
        feed[index].kudos += wasKudoed ? -1 : 1
        do {
            try await clubService.toggleKudos(activityId: item.id)
        } catch {
            // Roll back on failure — the optimistic toggle above was wrong. With feedback: a clap
            // that silently un-claps itself just reads as a broken button.
            feed[index].kudoedByMe = wasKudoed
            feed[index].kudos += wasKudoed ? 1 : -1
            appState.toast("Kudos non envoyé — vérifie ta connexion.")
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

    private func confirmBlock(_ userId: String) async {
        do {
            try await clubService.blockUser(userId: userId)
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
/// can post to `api/moderation/report` with the right target. Internal (not private): `FriendsView`
/// reuses this same type for its own report confirmationDialog.
struct ReportTarget: Identifiable {
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
    // `key` is already unique per badge definition (`ClubBadgeCatalog.all`) — a fresh `UUID()`
    // here meant every rebuild of `badges` (any body re-evaluation: a kudos tap, tab switch, RSVP)
    // handed `ForEach` an entirely new identity for every tile, defeating diffing and triggering
    // spurious re-animations even when nothing about the badges actually changed.
    var id: String { key }
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
    /// Formatter construction (locale lookup included) is the expensive part, and this is called
    /// once per feed row on every redraw — one shared instance instead of a fresh allocation each
    /// call. Safe as a plain static: everything touching it runs on the main actor.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .short
        return formatter
    }()

    /// Shared with `ActivityCommentsSheet` — one relative-time formatter for the feed and its
    /// comment threads instead of two copies.
    var relativeDescription: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: .now)
    }
}
