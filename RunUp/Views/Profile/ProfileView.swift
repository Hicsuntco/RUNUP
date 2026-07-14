import SwiftUI

/// Profile & Settings — mirrors `ProfileScreen` in screensC.jsx. The coach needs no API key from
/// the user (it's proxied through RunUp's own backend, see `Services/CoachService.swift`), so
/// there's no key-entry section here.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

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

                sectionTitle("Sources de données")
                dataSourcesCard

                sectionTitle("Préférences")
                preferencesCard

                sectionTitle("Programme")
                programCard
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
}
