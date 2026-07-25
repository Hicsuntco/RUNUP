import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Profile & Settings — mirrors `ProfileScreen` in screensC.jsx. The coach needs no API key from
/// the user (it's proxied through RunUp's own backend, see `Services/CoachService.swift`), so
/// there's no key-entry section here.
///
/// Only the 4 sections she's likely to actually touch often (Sources de données, Apparence,
/// Préférences, Objectifs quotidiens) stay directly on this page, fully expanded — a first attempt
/// at cutting down the page's density collapsed every section behind a tap-to-expand accordion,
/// but that added a second tap on top of whatever tap actually changes the setting, for things
/// meant to be quick. Everything reached less often (Programme, Santé & blessures, Cycle,
/// Parrainage, Compte) now lives one tap away on `MoreSettingsView`, the same cost a
/// permanently-expanded section already had — nothing gets slower, the page just gets shorter.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    @State private var showMoreSettings = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isSavingAvatar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BackTitleHeaderView(title: "Profil & réglages") { appState.go(.home) }

                HStack(spacing: 14) {
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(imageData: profile.avatarImageData, initial: String(profile.name.prefix(1)), size: 60)
                                .opacity(isSavingAvatar ? 0.5 : 1)
                            if isSavingAvatar {
                                ProgressView().tint(RUColor.textPrimary)
                            } else {
                                // A small pencil badge is what actually tells her the avatar is
                                // tappable — a plain circle with no affordance reads as decoration.
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .background(RUColor.rose, in: Circle())
                                    .offset(x: 3, y: 3)
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

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name).displayStyle(20).foregroundColor(RUColor.textPrimary)
                        // Only when a program/course-libre goal is actually current — recovery and
                        // choice phases have no active goal, and showing the last program's
                        // "Objectif · 20km · 1:45" there reads as if it were still being pursued.
                        if profile.programPhase == .active || profile.programPhase == .freerun {
                            Text("Objectif · \(profile.goalDisplay)").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                        }
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

                moreSettingsRow
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .sheet(isPresented: $showMoreSettings) {
            MoreSettingsView()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        EyebrowLabel(text: text, color: RUColor.text3)
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
        guard appState.auth.isSignedIn else { return }
        let dataURI = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        do {
            try await appState.auth.updateAvatar(dataURI: dataURI)
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
        guard appState.auth.isSignedIn else { return }
        do {
            try await appState.auth.updateAvatar(dataURI: nil)
        } catch {
            // Mirrors setAvatar's error handling above — the local photo is already cleared, but
            // the server (and every other club member's leaderboard/feed/comments view) still
            // shows the old one until this actually lands, and without this she'd have no signal
            // that the removal didn't take.
            appState.toast("Photo supprimée localement, mais toujours visible du club — vérifie ta connexion.")
        }
    }

    private var moreSettingsRow: some View {
        Button(action: { showMoreSettings = true }) {
            HStack {
                Text("Plus de réglages").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Text("›").foregroundColor(RUColor.text2)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    // Apple Santé only — the Strava and Garmin rows are removed entirely until those
    // integrations actually work (per the owner's call: no visible mention of a service that
    // isn't functional yet). To reinstate: Strava gets `StravaConnectionRow(auth: appState.auth)`
    // back (the OAuth code below is intact, it only needs server credentials), Garmin gets a
    // `BrandLogoIcon`-based row once a real integration exists.
    private var dataSourcesCard: some View {
        VStack(spacing: 0) {
            appleHealthRow
        }
        .ruCard()
    }

    private var appleHealthRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "apple.logo").font(.system(size: 16)).foregroundColor(RUColor.textPrimary)
            Text(ConnectedSource.apple.title).font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { profile.connectedSources.contains(.apple) },
                set: { on in
                    if on {
                        profile.connectedSources.append(.apple)
                        // See HealthConnectStepView's identical toggle for why this can't just
                        // swallow the error with `try?` — a genuine failure (HealthKit
                        // unavailable) shouldn't silently leave "Apple Santé" marked connected.
                        Task {
                            do {
                                try await appState.healthKit.requestAuthorization()
                            } catch {
                                await MainActor.run {
                                    profile.connectedSources.removeAll { $0 == .apple }
                                    appState.toast("Connexion à Apple Santé impossible, réessaie plus tard.")
                                }
                            }
                        }
                    } else {
                        profile.connectedSources.removeAll { $0 == .apple }
                    }
                }
            ))
            .labelsHidden()
            .tint(RUColor.rose)
            .accessibilityLabel("Synchroniser avec Apple Santé")
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
                                // Theme-aware — a white selection ring was invisible on the
                                // near-white light-mode card.
                                Circle().stroke(RUColor.textPrimary, lineWidth: 2.5).frame(width: 46, height: 46)
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        .frame(width: 46, height: 46)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(theme.name)
                    .accessibilityAddTraits(profile.accentThemeID == theme.id ? .isSelected : [])
                }
            }
        }
        .padding(14)
        .ruCard()
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
        appState.publishWidgetSnapshot()
    }

    private func selectAccent(_ theme: AccentTheme) {
        profile.accentThemeID = theme.id
        ThemeStore.shared.themeID = theme.id
        appState.publishWidgetSnapshot()
    }

    // The "Unité de distance" km/mi toggle used to sit here — removed rather than left as dead
    // state: `distanceUnit` was written and persisted but read by nothing, so picking "mi"
    // visibly changed nothing anywhere in the app. Reinstate only alongside real unit conversion
    // in every distance display.
    private var preferencesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notifications du coach").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { profile.coachNotificationsEnabled },
                    set: { on in
                        profile.coachNotificationsEnabled = on
                        if on {
                            Task {
                                // The OS grant used to be ignored — if she'd denied the system
                                // prompt, the toggle stayed ON while every scheduler silently
                                // no-op'd (they all guard on real authorization). Reflect reality:
                                // revert the toggle and point at Réglages instead.
                                let granted = await NotificationService.shared.requestAuthorization()
                                if granted {
                                    NotificationService.shared.rescheduleDailyReminder(for: profile)
                                    NotificationService.shared.rescheduleInactivityReminder(for: profile)
                                    NotificationService.shared.scheduleWeeklyRecapReminder(for: profile)
                                } else {
                                    await MainActor.run {
                                        profile.coachNotificationsEnabled = false
                                        appState.toast("Notifications refusées côté iPhone — active-les dans Réglages > RunUp.")
                                    }
                                }
                            }
                        } else {
                            NotificationService.shared.cancelDailyReminder()
                            NotificationService.shared.cancelInactivityReminder()
                            NotificationService.shared.cancelWeeklyRecapReminder()
                        }
                    }
                ))
                    .labelsHidden()
                    .tint(RUColor.rose)
                    .accessibilityLabel("Notifications du coach")
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .ruCard()
    }

    /// Both goals used to only ever be fixed defaults (`UserProfile.stepsGoal` = 6000,
    /// `activeCaloriesGoal` = 400) with no way to change them — the daily-goals bars on Home read
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
                Text("Objectif calories actives").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Stepper(
                    "\(Int(profile.activeCaloriesGoal)) kcal",
                    value: Binding(get: { profile.activeCaloriesGoal }, set: { profile.activeCaloriesGoal = $0 }),
                    in: 100...1000,
                    step: 50
                )
                .fixedSize()
                .tint(RUColor.rose)
                .foregroundColor(RUColor.textPrimary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .ruCard()
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
