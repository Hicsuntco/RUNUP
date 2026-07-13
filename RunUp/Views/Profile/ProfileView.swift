import SwiftUI

/// Profile & Settings — mirrors `ProfileScreen` in screensC.jsx, plus an API-key entry section
/// for the coach (see README/user decision: key entered here, stored in Keychain).
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    @State private var apiKeyDraft = ""
    @State private var apiKeySaved = false
    @State private var unit = "km"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.home) }
                    Text("Profil & réglages").displayStyle(22).foregroundColor(.white)
                }

                HStack(spacing: 14) {
                    Circle()
                        .fill(LinearGradient(colors: [RUColor.rose, RUColor.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                        .overlay(Text(String(profile.name.prefix(1))).displayStyle(24).foregroundColor(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name).displayStyle(20).foregroundColor(.white)
                        Text("Objectif · \(profile.goalDisplay)").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    }
                }

                premiumBanner

                coachApiKeySection

                sectionTitle("Sources de données")
                dataSourcesCard

                sectionTitle("Préférences")
                preferencesCard

                sectionTitle("Programme")
                programCard

                if profile.programPhase == .active {
                    demoButton("Terminer le programme (démo)") {
                        AdaptivePlanEngine.endProgram(profile)
                        appState.toast("Programme terminé — place à la récup")
                        appState.go(.home)
                    }
                }
                demoButton(profile.coachOfflineDemo ? "Reconnecter le coach (démo)" : "Simuler coach hors ligne (démo)") {
                    profile.coachOfflineDemo.toggle()
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .onAppear {
            apiKeyDraft = KeychainService.loadAPIKey() ?? ""
            unit = profile.distanceUnit
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        EyebrowLabel(text: text, color: RUColor.text3)
    }

    private var premiumBanner: some View {
        Button(action: { if !profile.premium { appState.openPaywall() } }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(profile.premium ? RUColor.lime.opacity(0.15) : RUColor.violet.opacity(0.2))
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "star.fill").foregroundColor(profile.premium ? RUColor.lime : RUColor.violet).font(.system(size: 14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.premium ? "Runner Premium" : "Passer à Premium").font(RUFont.sans(14, weight: .bold)).foregroundColor(.white)
                    Text(profile.premium ? "Coach illimité, stats avancées, connexions étendues" : "Coach illimité, prédictions de course, plus encore")
                        .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                }
                Spacer(minLength: 0)
                if !profile.premium { Text("→").foregroundColor(RUColor.violet) }
            }
            .padding(14)
            .background(bannerFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(profile.premium ? RUColor.lime.opacity(0.3) : RUColor.violet.opacity(0.35), lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
    }

    private var bannerFill: AnyShapeStyle {
        profile.premium
            ? AnyShapeStyle(RUColor.lime.opacity(0.08))
            : AnyShapeStyle(LinearGradient(colors: [RUColor.violet.opacity(0.16), RUColor.rose.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var coachApiKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Coach IA")
            VStack(alignment: .leading, spacing: 10) {
                Text("Colle ta clé API Anthropic pour activer les réponses réelles du coach.")
                    .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2).lineSpacing(2)
                SecureField("", text: $apiKeyDraft, prompt: Text("sk-ant-…").foregroundColor(RUColor.text3))
                    .font(RUFont.mono(12))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                HStack {
                    Text(KeychainService.loadAPIKey()?.isEmpty == false ? "Clé enregistrée ✓" : "Aucune clé enregistrée")
                        .font(RUFont.sans(11, weight: .semibold))
                        .foregroundColor(KeychainService.loadAPIKey()?.isEmpty == false ? RUColor.lime : RUColor.text3)
                    Spacer()
                    Button("Enregistrer") {
                        KeychainService.saveAPIKey(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                        appState.toast("Clé API enregistrée")
                    }
                    .font(RUFont.sans(12, weight: .bold))
                    .foregroundColor(RUColor.rose2)
                }
            }
            .padding(14)
            .ruCard()
        }
    }

    private var dataSourcesCard: some View {
        VStack(spacing: 0) {
            ForEach(ConnectedSource.allCases) { source in
                HStack(spacing: 12) {
                    Text(source == .apple ? "🍎" : source == .strava ? "🟠" : "⌚").font(.system(size: 17))
                    Text(source.title).font(RUFont.sans(14, weight: .medium)).foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { profile.connectedSources.contains(source) },
                        set: { on in
                            if on {
                                profile.connectedSources.append(source)
                                if source == .apple { Task { try? await appState.healthKit.requestAuthorization() } }
                            } else {
                                profile.connectedSources.removeAll { $0 == source }
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(RUColor.rose)
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                if source != ConnectedSource.allCases.last {
                    Divider().background(RUColor.line)
                }
            }
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Unité de distance").font(RUFont.sans(14, weight: .medium)).foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(["km", "mi"], id: \.self) { u in
                        Button(action: { unit = u; profile.distanceUnit = u }) {
                            Text(u).font(RUFont.sans(12, weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(unit == u ? RUColor.rose : .clear, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.06), in: Capsule())
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            Divider().background(RUColor.line)
            HStack {
                Text("Notifications du coach").font(RUFont.sans(14, weight: .medium)).foregroundColor(.white)
                Spacer()
                Toggle("", isOn: Binding(get: { profile.coachNotificationsEnabled }, set: { profile.coachNotificationsEnabled = $0 }))
                    .labelsHidden()
                    .tint(RUColor.rose)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
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
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func programRow(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).font(RUFont.sans(14, weight: .medium)).foregroundColor(.white)
                Spacer()
                Text("›").foregroundColor(RUColor.text2)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .buttonStyle(PressableStyle())
    }

    private func demoButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(RUFont.sans(11.5, weight: .semibold))
                .foregroundColor(RUColor.text3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(PressableStyle())
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: RUSpacing.hairline, dash: [4, 3])).foregroundColor(RUColor.line))
    }
}
