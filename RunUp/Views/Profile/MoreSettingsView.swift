import SwiftUI
import UIKit

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
    private var clubService: ClubService { ClubService(auth: appState.auth) }

    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var usernameText = ""
    @State private var lastNameText = ""
    @State private var isSavingIdentity = false
    @State private var identityError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionTitle("Course")
                    runSettingsCard
                    shoesCard

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

                    sectionTitle("Bêta")
                    betaFeedbackCard
                }
                .padding(18)
            }
            .background(RUColor.bg)
            .navigationTitle("Plus de réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .onAppear {
                usernameText = appState.auth.currentUser?.username ?? ""
                lastNameText = appState.auth.currentUser?.lastName ?? ""
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    private func sectionTitle(_ text: String) -> some View {
        EyebrowLabel(text: text, color: RUColor.text3)
    }

    private var programCard: some View {
        VStack(spacing: 0) {
            programRow("flag.checkered", "Voir mon objectif") { dismiss(); appState.go(.race) }
            Divider().background(RUColor.line)
            programRow("slider.horizontal.3", "Modifier jours & objectif") { dismiss(); appState.openProgramSettings() }
            Divider().background(RUColor.line)
            // Opens the same wizard `ChoiceView` offers at the end of a program — only touches
            // goal/distance/allure/jours, keeps everything else (nom, blessures, cycle...) as-is.
            // The old "Refaire l'onboarding" re-asked all of it just to change the training plan.
            programRow("arrow.counterclockwise", "Refaire un programme") { dismiss(); appState.newGoalWizardPresented = true }
            if profile.programPhase != .freerun {
                Divider().background(RUColor.line)
                // The direct route to `.freerun` — before this, the only way in was "Terminer le
                // programme" -> several days of recovery countdown -> a "Choix" screen that
                // finally offers it. That reads as the app forcing a rest phase just to stop and
                // run casually for a while, when what's actually wanted (course libre: suggested
                // sessions with no pace/distance target, just maintien/progression) already
                // exists — it just needed a way in that doesn't run through recovery first.
                programRow("figure.run", "Passer en mode course libre") {
                    AdaptivePlanEngine.chooseFreeRun(profile)
                    appState.toast("Mode course libre activé — suggestions sans objectif de perf")
                    dismiss()
                }
            }
            if profile.programPhase == .active {
                Divider().background(RUColor.line)
                programRow("checkmark.seal", "Terminer le programme") {
                    AdaptivePlanEngine.endProgram(profile)
                    appState.toast("Programme terminé · récupération en cours")
                    dismiss()
                }
            }
        }
        .ruCard()
    }

    private func programRow(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                rowIcon(icon)
                Text(label).font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                Spacer()
                Text("›").foregroundColor(RUColor.text2)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .buttonStyle(PressableStyle())
    }

    /// Small leading glyph on every settings row — every card here used to be label-plus-control
    /// with nothing to distinguish one row from the next at a glance except the text itself.
    private func rowIcon(_ systemName: String, color: Color = RUColor.rose2) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 22)
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
                .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
        }
        .padding(14)
        .ruCard()
    }

    /// Auto-pause at a stop (see `LiveRunViewModel.autoPause`) — on by default like Strava/Garmin,
    /// but a real opt-out for runners whose interval sessions include genuine short walk breaks
    /// that shouldn't freeze the chrono.
    private var runSettingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                rowIcon("pause.circle")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause automatique aux arrêts").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                    Text("Met la course en pause si tu t'arrêtes, reprend toute seule.")
                        .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { profile.autoPauseEnabled }, set: { profile.autoPauseEnabled = $0 }))
                    .labelsHidden()
                    .tint(RUColor.rose)
                    .accessibilityLabel("Pause automatique aux arrêts")
            }
            .padding(14)
            Divider().background(RUColor.line)
            HStack {
                rowIcon("speaker.wave.2")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alertes vocales d'allure").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                    Text("Prévient à voix haute si tu t'écartes de ton allure cible.")
                        .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { profile.paceAlertsEnabled }, set: { profile.paceAlertsEnabled = $0 }))
                    .labelsHidden()
                    .tint(RUColor.rose)
                    .accessibilityLabel("Alertes vocales d'allure")
            }
            .padding(14)
        }
        .ruCard()
    }

    private var shoesCard: some View {
        VStack(spacing: 0) {
            programRow("shoeprints.fill", "Mes chaussures") { dismiss(); appState.go(.shoes) }
        }
        .ruCard()
    }

    /// Only shown when `profile.sex == "female"` — lets her set up cycle tracking after
    /// onboarding (or change it later) rather than only ever getting the one chance during
    /// onboarding. `AdaptivePlanEngine.adjustForWellbeing` reads `profile.cyclePhase` directly, so
    /// editing these fields here immediately changes next week's plan, same as any other program
    /// setting.
    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                rowIcon("drop.fill")
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
                .accessibilityLabel("Suivi du cycle")
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
        .ruCard()
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
    /// La section porte déjà le titre « Parraine un ami », d'où l'absence de titre dans la carte.
    /// Le contenu vit maintenant dans `ReferralInviteCard`, partagé avec le fil d'amis vide —
    /// c'est là que l'invitation compte vraiment, ici elle n'est qu'un rappel.
    private func referralCard(code: String) -> some View {
        ReferralInviteCard(code: code)
    }

    /// Real account, tied to the Club backend (see `AuthService`) — includes account deletion,
    /// required by App Store guideline 5.1.1(v) whenever an app offers account creation.
    private var accountCard: some View {
        VStack(spacing: 0) {
            if let user = appState.auth.currentUser {
                HStack {
                    rowIcon("person.crop.circle")
                    Text("Connectée en tant que \(user.name)").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                Divider().background(RUColor.line)
            }
            identityEditor
            Divider().background(RUColor.line)
            programRow("arrow.right.square", "Se déconnecter") { appState.auth.signOut(); dismiss() }
            Divider().background(RUColor.line)
            Button(action: { showDeleteAccountConfirm = true }) {
                HStack(spacing: 12) {
                    rowIcon("trash", color: RUColor.rose)
                    Text("Supprimer mon compte").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.rose)
                    Spacer()
                    if isDeletingAccount { ProgressView().tint(RUColor.rose) }
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
            }
            .buttonStyle(PressableStyle())
            .disabled(isDeletingAccount)
        }
        .ruCard()
        .confirmationDialog("Supprimer définitivement ton compte ?", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { Task { await deleteAccount() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ton club, ton classement et ton fil d'activité seront définitivement supprimés du serveur. Cette action est irréversible.")
        }
    }

    /// A `mailto:` link, not a custom feedback backend/dashboard — zero infrastructure to build
    /// or maintain for a handful of beta testers, and it works with whatever mail app is actually
    /// configured on their phone (unlike `MFMailComposeViewController`, which only fires if the
    /// built-in Mail app itself has an account set up). Same address `ClubView`'s "nous contacter"
    /// link already uses, so feedback and abuse reports land in the same inbox.
    private var betaFeedbackCard: some View {
        VStack(spacing: 0) {
            Link(destination: feedbackMailURL) {
                HStack {
                    rowIcon("envelope")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Donner mon avis").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
                        Text("Un bug, une idée, un truc qui t'a gênée — ça part par mail.")
                            .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                    }
                    Spacer()
                    Text("›").foregroundColor(RUColor.text2)
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
            }
            .buttonStyle(PressableStyle())
        }
        .ruCard()
    }

    private var feedbackMailURL: URL {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let system = UIDevice.current.systemVersion
        let body = "\n\n\n---\nCe qui suit aide juste au diagnostic :\nVersion \(version) (\(build)) · iOS \(system)"
        var components = URLComponents(string: "mailto:charlottegrudep@gmail.com")!
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Feedback RunUp bêta"),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url!
    }

    /// Neither onboarding nor signup ever asked for a handle or a last name — "Mes amis" search
    /// can't reliably find "Léo" among several without one. Both optional, saved together with a
    /// single tap; a taken username surfaces inline rather than a generic failure toast.
    private var identityEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Pseudo (facultatif)", text: $usernameText)
                .textFieldStyle(.plain)
                .font(RUFont.sans(13.5))
                .foregroundColor(RUColor.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            TextField("Nom (facultatif)", text: $lastNameText)
                .textFieldStyle(.plain)
                .font(RUFont.sans(13.5))
                .foregroundColor(RUColor.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if let identityError {
                Text(identityError).font(RUFont.sans(11)).foregroundColor(RUColor.rose)
            }
            HStack {
                Text("Aide tes amis à te retrouver dans la recherche.")
                    .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
                Spacer()
                Button(isSavingIdentity ? "…" : "Enregistrer") { Task { await saveIdentity() } }
                    .font(RUFont.sans(11.5, weight: .semibold))
                    .foregroundColor(RUColor.rose2)
                    .disabled(isSavingIdentity)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
    }

    private func saveIdentity() async {
        isSavingIdentity = true
        identityError = nil
        do {
            try await clubService.updateProfile(
                username: usernameText.trimmingCharacters(in: .whitespaces),
                lastName: lastNameText.trimmingCharacters(in: .whitespaces)
            )
            // Refreshes `currentUser` so the change is reflected immediately — search results and
            // future signup/profile screens all read from there, not from this sheet's own state.
            try? await appState.auth.refreshMe()
            appState.toast("Profil mis à jour")
        } catch ClubServiceError.badResponse(409, _) {
            identityError = "Ce pseudo est déjà pris."
        } catch ClubServiceError.badResponse(400, _) {
            identityError = "Pseudo invalide — lettres minuscules, chiffres, underscore, 3 à 20 caractères."
        } catch ClubServiceError.badResponse(422, _) {
            identityError = "Ce nom n'est pas autorisé — choisis-en un autre."
        } catch {
            identityError = "Impossible d'enregistrer — vérifie ta connexion."
        }
        isSavingIdentity = false
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            try await appState.auth.deleteAccount()
            appState.toast("Compte supprimé")
            dismiss()
        } catch {
            appState.toast("Impossible de supprimer le compte — réessaie.")
        }
        isDeletingAccount = false
    }
}
