import SwiftUI

/// "Plus de réglages" — reached from `ProfileView`'s bottom row, same one-tap cost the main page
/// already paid for by being long: Programme, Santé & blessures, Cycle, Parrainage, Compte are all
/// real settings she's asked to keep, just not ones adjusted often enough to earn permanent space
/// on the page she opens most. Mirrors `ClubManagementView`'s own "secondary settings" sheet
/// pattern (`NavigationStack` + a "Fermer" toolbar button) for the same reason it exists there —
/// nothing here is behind a second, internal tap once she's on this screen.
struct MoreSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    @State private var showDeleteAccountConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                .padding(18)
            }
            .background(RUColor.bg)
            .navigationTitle("Plus de réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    private func sectionTitle(_ text: String) -> some View {
        EyebrowLabel(text: text, color: RUColor.text3)
    }

    private var programCard: some View {
        VStack(spacing: 0) {
            programRow("Voir mon objectif") { dismiss(); appState.go(.race) }
            Divider().background(RUColor.line)
            programRow("Modifier jours & objectif") { dismiss(); appState.openProgramSettings() }
            Divider().background(RUColor.line)
            programRow("Refaire l'onboarding") { dismiss(); appState.replayOnboarding() }
            if profile.programPhase == .active {
                Divider().background(RUColor.line)
                programRow("Terminer le programme") {
                    AdaptivePlanEngine.endProgram(profile)
                    appState.toast("Programme terminé · récupération en cours")
                    dismiss()
                }
            }
        }
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
                        .colorScheme(RUColor.colorScheme)
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
            programRow("Se déconnecter") { appState.auth.signOut(); dismiss() }
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
            dismiss()
        } catch {
            appState.toast("Impossible de supprimer le compte — réessaie.")
        }
    }
}
