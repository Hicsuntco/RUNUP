import SwiftUI
import SwiftData

/// Profile & Settings — mirrors `ProfileScreen` in screensC.jsx. The coach needs no API key from
/// the user (it's proxied through RunUp's own backend, see `Services/CoachService.swift`), so
/// there's no key-entry section here.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    @State private var unit = "km"
    @State private var showDeleteAccountConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.home) }
                    Text("Profil & réglages").displayStyle(22).foregroundColor(RUColor.textPrimary)
                }

                HStack(spacing: 14) {
                    Circle()
                        .fill(LinearGradient(colors: [RUColor.rose, RUColor.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                        .overlay(Text(String(profile.name.prefix(1))).displayStyle(24).foregroundColor(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name).displayStyle(20).foregroundColor(RUColor.textPrimary)
                        Text("Objectif · \(profile.goalDisplay)").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    }
                }

                sectionTitle("Sources de données")
                dataSourcesCard

                sectionTitle("Apparence")
                appearanceCard

                sectionTitle("Préférences")
                preferencesCard

                sectionTitle("Objectifs quotidiens")
                dailyGoalsCard

                sectionTitle("Programme")
                programCard

                sectionTitle("Santé & blessures")
                injuryCard

                if profile.sex == "female" {
                    sectionTitle("Cycle")
                    cycleCard
                }

                if appState.auth.isSignedIn, let code = appState.auth.currentUser?.referralCode {
                    sectionTitle("Parraine un ami")
                    referralCard(code: code)
                }

                if appState.auth.isSignedIn {
                    sectionTitle("Compte")
                    accountCard
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .onAppear {
            unit = profile.distanceUnit
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        EyebrowLabel(text: text, color: RUColor.text3)
    }

    private var dataSourcesCard: some View {
        VStack(spacing: 0) {
            appleHealthRow
            Divider().background(RUColor.line)
            StravaConnectionRow(auth: appState.auth)
            Divider().background(RUColor.line)
            garminRow
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private var appleHealthRow: some View {
        HStack(spacing: 12) {
            Text("🍎").font(.system(size: 17))
            Text(ConnectedSource.apple.title).font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { profile.connectedSources.contains(.apple) },
                set: { on in
                    if on {
                        profile.connectedSources.append(.apple)
                        Task { try? await appState.healthKit.requestAuthorization() }
                    } else {
                        profile.connectedSources.removeAll { $0 == .apple }
                    }
                }
            ))
            .labelsHidden()
            .tint(RUColor.rose)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
    }

    /// No real Garmin Connect integration yet — a working-looking toggle here would silently do
    /// nothing, which reads as broken rather than simply "not built yet".
    private var garminRow: some View {
        HStack(spacing: 12) {
            Text("⌚").font(.system(size: 17))
            Text(ConnectedSource.garmin.title).font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer()
            Text("Bientôt").font(RUFont.sans(11, weight: .semibold)).foregroundColor(RUColor.text3)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
    }

    /// Nuancier — tap a swatch to re-theme the whole app (buttons, highlights, the logo mark)
    /// with that accent. Persists to `profile.accentThemeID` and mirrors into `ThemeStore` so
    /// every `RUColor.rose`/`.rose2`/`.violet` call site updates immediately, live. The mode row
    /// above it (Sombre/Blanc) is the same mirror-into-`ThemeStore` mechanism, one level up —
    /// dark/light instead of an accent hue, see `RUColor`'s theme-aware tokens.
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mode d'affichage").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    modeButton("Sombre", isLight: false)
                    modeButton("Blanc", isLight: true)
                }
                .padding(3)
                .background(RUColor.card2, in: Capsule())
            }

            Divider().background(RUColor.line)

            Text("Couleur de l'app").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 16) {
                ForEach(AccentTheme.all) { theme in
                    Button(action: { selectAccent(theme) }) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [theme.primary, theme.tail], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40)
                            if profile.accentThemeID == theme.id {
                                Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 46, height: 46)
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        .frame(width: 46, height: 46)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(14)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func modeButton(_ label: String, isLight: Bool) -> some View {
        let selected = profile.isLightMode == isLight
        return Button(action: { selectMode(isLight: isLight) }) {
            Text(label)
                .font(RUFont.sans(12, weight: .semibold))
                .foregroundColor(selected ? .white : RUColor.text2)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(selected ? RUColor.rose : .clear, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func selectMode(isLight: Bool) {
        profile.isLightMode = isLight
        ThemeStore.shared.isLightMode = isLight
    }

    private func selectAccent(_ theme: AccentTheme) {
        profile.accentThemeID = theme.id
        ThemeStore.shared.themeID = theme.id
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Unité de distance").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(["km", "mi"], id: \.self) { u in
                        Button(action: { unit = u; profile.distanceUnit = u }) {
                            Text(u).font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(unit == u ? RUColor.rose : .clear, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(3)
                .background(RUColor.card, in: Capsule())
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            Divider().background(RUColor.line)
            HStack {
                Text("Notifications du coach").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { profile.coachNotificationsEnabled },
                    set: { on in
                        profile.coachNotificationsEnabled = on
                        if on {
                            Task {
                                await NotificationService.shared.requestAuthorization()
                                NotificationService.shared.rescheduleDailyReminder(for: profile)
                                NotificationService.shared.rescheduleInactivityReminder(for: profile)
                            }
                        } else {
                            NotificationService.shared.cancelDailyReminder()
                            NotificationService.shared.cancelInactivityReminder()
                        }
                    }
                ))
                    .labelsHidden()
                    .tint(RUColor.rose)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    /// Both goals used to only ever be fixed defaults (`UserProfile.stepsGoal` = 6000,
    /// `strengthGoalMinutes` = 15) with no way to change them — the daily-goals bars on Home read
    /// those values directly, so editing here immediately reshapes what counts as "done" today.
    private var dailyGoalsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Objectif de pas").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Stepper(
                    "\(Int(profile.stepsGoal)) pas",
                    value: Binding(get: { profile.stepsGoal }, set: { profile.stepsGoal = $0 }),
                    in: 2000...20000,
                    step: 500
                )
                .fixedSize()
                .tint(RUColor.rose)
                .foregroundColor(RUColor.textPrimary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            Divider().background(RUColor.line)
            HStack {
                Text("Objectif renfo & mobilité").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Stepper(
                    "\(Int(profile.strengthGoalMinutes)) min",
                    value: Binding(get: { profile.strengthGoalMinutes }, set: { profile.strengthGoalMinutes = $0 }),
                    in: 0...60,
                    step: 5
                )
                .fixedSize()
                .tint(RUColor.rose)
                .foregroundColor(RUColor.textPrimary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    /// Injury used to only ever be askable once, during onboarding — with no way back to it, a
    /// blessure that heals (or a new one that shows up) could never actually update the plan
    /// `AdaptivePlanEngine.adjustForWellbeing` is already computing every week from this field.
    private var injuryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Une douleur ou blessure à surveiller ?").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            ChipFlowLayout {
                ForEach([("none", "Aucune"), ("knee", "Genou"), ("ankle", "Cheville"), ("back", "Dos"), ("other", "Autre")], id: \.0) { id, label in
                    SelectableChip(label: label, selected: (profile.injuryArea ?? "none") == id) { profile.injuryArea = id }
                }
            }
            Text("Le coach adapte tes séances de fractionné/VMA en conséquence, chaque semaine.")
                .font(RUFont.sans(11)).foregroundColor(RUColor.text3)
        }
        .padding(14)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private var programCard: some View {
        VStack(spacing: 0) {
            programRow("Voir mon objectif") { appState.go(.race) }
            Divider().background(RUColor.line)
            programRow("Modifier jours & objectif") { appState.openProgramSettings() }
            Divider().background(RUColor.line)
            programRow("Refaire l'onboarding") { appState.replayOnboarding() }
            if profile.programPhase == .active {
                Divider().background(RUColor.line)
                programRow("Terminer le programme") {
                    AdaptivePlanEngine.endProgram(profile)
                    appState.toast("Programme terminé · récupération en cours")
                }
            }
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    /// Only shown when `profile.sex == "female"` — lets her set up cycle tracking after
    /// onboarding (or change it later) rather than only ever getting the one chance during
    /// onboarding. `AdaptivePlanEngine.adjustForWellbeing` reads `profile.cyclePhase` directly, so
    /// editing these fields here immediately changes next week's plan, same as any other program
    /// setting.
    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Suivi du cycle").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { profile.cycleTrackingEnabled },
                    set: { on in
                        profile.cycleTrackingEnabled = on
                        if on && profile.lastPeriodStartDate == nil { profile.lastPeriodStartDate = .now }
                    }
                ))
                .labelsHidden()
                .tint(RUColor.rose)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)

            if profile.cycleTrackingEnabled {
                Divider().background(RUColor.line)
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date des dernières règles").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                        DatePicker(
                            "",
                            selection: Binding(get: { profile.lastPeriodStartDate ?? .now }, set: { profile.lastPeriodStartDate = $0 }),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                    }

                    HStack {
                        Text("Durée moyenne du cycle").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                        Spacer()
                        Stepper(
                            "\(profile.averageCycleLengthDays) jours",
                            value: Binding(get: { profile.averageCycleLengthDays }, set: { profile.averageCycleLengthDays = $0 }),
                            in: 21...35
                        )
                        .fixedSize()
                        .tint(RUColor.rose)
                        .foregroundColor(RUColor.textPrimary)
                    }

                    if let phase = profile.cyclePhase {
                        HStack(spacing: 7) {
                            Circle().fill(cyclePhaseColor(phase)).frame(width: 8, height: 8)
                            Text("Phase actuelle estimée : \(cyclePhaseLabel(phase))")
                                .font(RUFont.sans(12, weight: .semibold))
                                .foregroundColor(cyclePhaseColor(phase))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14).padding(.top, 2)
            }
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func cyclePhaseLabel(_ phase: UserProfile.CyclePhase) -> String {
        switch phase {
        case .menstrual: return "menstruelle"
        case .follicular: return "folliculaire"
        case .ovulation: return "ovulatoire"
        case .luteal: return "lutéale"
        }
    }

    private func cyclePhaseColor(_ phase: UserProfile.CyclePhase) -> Color {
        switch phase {
        case .menstrual: return RUColor.rose
        case .follicular: return RUColor.lime
        case .ovulation: return RUColor.cyan
        case .luteal: return RUColor.amber
        }
    }

    /// A real, personal referral code (see `api/auth/[action].js`) — sharing it and having the
    /// friend actually log a first activity rewards both accounts +100 XP (see
    /// `api/activities/[action].js`'s `grantReferralRewardIfNeeded`), not just for installing.
    private func referralCard(code: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite un ami avec ton code — vous gagnez tous les deux +100 XP dès sa première séance.")
                .font(RUFont.sans(12.5)).foregroundColor(RUColor.text2).lineSpacing(2)
            HStack(spacing: 10) {
                Text(code)
                    .font(RUFont.mono(18, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
                    .tracking(2)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                Spacer()
                ShareLink(item: "Rejoins-moi sur RunUp, mon appli de coaching running — utilise mon code \(code) à l'inscription : https://runup-nu.vercel.app") {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Partager")
                    }
                    .font(RUFont.sans(12.5, weight: .semibold))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(14)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func programRow(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Text("›").foregroundColor(RUColor.text2)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .buttonStyle(PressableStyle())
    }

    /// Real account, tied to the Club backend (see `AuthService`) — includes account deletion,
    /// required by App Store guideline 5.1.1(v) whenever an app offers account creation.
    private var accountCard: some View {
        VStack(spacing: 0) {
            if let user = appState.auth.currentUser {
                HStack {
                    Text("Connectée en tant que \(user.name)").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                Divider().background(RUColor.line)
            }
            programRow("Se déconnecter") { appState.auth.signOut() }
            Divider().background(RUColor.line)
            Button(action: { showDeleteAccountConfirm = true }) {
                HStack {
                    Text("Supprimer mon compte").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.rose)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
            }
            .buttonStyle(PressableStyle())
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        .confirmationDialog("Supprimer définitivement ton compte ?", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { Task { await deleteAccount() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ton club, ton classement et ton fil d'activité seront définitivement supprimés du serveur. Cette action est irréversible.")
        }
    }

    private func deleteAccount() async {
        do {
            try await appState.auth.deleteAccount()
            appState.toast("Compte supprimé")
        } catch {
            appState.toast("Impossible de supprimer le compte — réessaie.")
        }
    }
}

/// Real Strava connect/disconnect + "import my history" — the only data source here backed by a
/// real OAuth handshake (see `StravaService`) rather than a native framework (HealthKit) or a
/// stub ("Bientôt"). A separate view (not inlined in `dataSourcesCard`) since it owns real
/// async state — connection status, an in-flight import, its own error messages.
private struct StravaConnectionRow: View {
    var auth: AuthService

    @Environment(\.modelContext) private var modelContext
    @State private var isConnected = false
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importedCount: Int?

    private var stravaService: StravaService { StravaService(auth: auth) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("🟠").font(.system(size: 17))
                Text("Strava").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                if !auth.isSignedIn {
                    Text("Nécessite un compte").font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                } else if isLoading {
                    ProgressView().tint(RUColor.rose)
                } else if isConnected {
                    Button("Déconnecter") { Task { await disconnect() } }
                        .font(RUFont.sans(11.5, weight: .semibold)).foregroundColor(RUColor.text3)
                } else {
                    Button("Connecter") { Task { await connect() } }
                        .font(RUFont.sans(11.5, weight: .semibold)).foregroundColor(RUColor.rose2)
                }
            }

            if isConnected {
                Button(action: { Task { await importHistory() } }) {
                    HStack(spacing: 6) {
                        if isImporting { ProgressView().tint(RUColor.text2) }
                        Text(isImporting ? "Import en cours…" : "Importer mon historique Strava")
                    }
                    .font(RUFont.sans(11.5, weight: .semibold))
                    .foregroundColor(RUColor.text2)
                }
                .buttonStyle(PressableStyle())
                .disabled(isImporting)
            }

            if let importedCount {
                Text(importedCount == 0 ? "Rien de nouveau à importer." : "\(importedCount) course\(importedCount > 1 ? "s" : "") importée\(importedCount > 1 ? "s" : "").")
                    .font(RUFont.sans(10.5)).foregroundColor(RUColor.lime)
            }
            if let errorMessage {
                Text(errorMessage).font(RUFont.sans(10.5)).foregroundColor(RUColor.rose)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .task {
            if auth.isSignedIn { await refreshStatus() }
        }
    }

    private func refreshStatus() async {
        isConnected = (try? await stravaService.status()) ?? false
    }

    private func connect() async {
        isLoading = true
        errorMessage = nil
        do {
            try await stravaService.connect()
            isConnected = true
        } catch StravaServiceError.notConfigured {
            errorMessage = "Strava n'est pas encore configuré côté serveur."
        } catch StravaServiceError.cancelled {
            // Silently ignored — she just closed the Strava sheet without finishing.
        } catch {
            errorMessage = "Connexion à Strava impossible, réessaie."
        }
        isLoading = false
    }

    private func disconnect() async {
        isLoading = true
        errorMessage = nil
        do {
            try await stravaService.disconnect()
            isConnected = false
            importedCount = nil
        } catch {
            errorMessage = "Impossible de déconnecter Strava, réessaie."
        }
        isLoading = false
    }

    /// Inserts each Strava run as a local `RunRecord` — deduped against `stravaActivityId`s
    /// already present, so importing again (to pick up newer Strava activity) never duplicates
    /// History. No XP/club post for these: they're historical, not a session just completed.
    private func importHistory() async {
        isImporting = true
        errorMessage = nil
        do {
            let runs = try await stravaService.importActivities()
            let existingIds = existingStravaIds()
            var newCount = 0
            for run in runs where !existingIds.contains(run.stravaActivityId) {
                let record = RunRecord(
                    date: run.date,
                    title: run.title,
                    distanceKm: run.distanceKm,
                    durationSeconds: run.durationSeconds,
                    avgPace: AdaptivePlanEngine.fmt(run.distanceKm > 0 ? Double(run.durationSeconds) / run.distanceKm : 0),
                    avgHeartRate: run.avgHeartRate,
                    kcal: Int(run.distanceKm * 65),
                    elevationGainM: run.elevationGainM,
                    stravaActivityId: run.stravaActivityId
                )
                modelContext.insert(record)
                newCount += 1
            }
            importedCount = newCount
        } catch {
            errorMessage = "Import Strava impossible, réessaie."
        }
        isImporting = false
    }

    private func existingStravaIds() -> Set<Int> {
        let descriptor = FetchDescriptor<RunRecord>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        return Set(existing.compactMap { $0.stravaActivityId })
    }
}
