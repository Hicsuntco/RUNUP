import SwiftUI

/// Step 6 — data source connections. Apple Santé uses the real HealthKit authorization prompt;
/// Strava/Garmin are UI stubs per the brief ("peuvent rester des stubs à connecter pour une v1").
struct HealthConnectStepView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            Spacer()
            ObTitle(
                eyebrow: "Étape 6 · tes données",
                title: "CONNECTE TA MONTRE",
                subtitle: "Pour une forme du jour plus précise — FC, sommeil, sorties passées. Facultatif, tu peux le faire plus tard."
            )
            VStack(spacing: 8) {
                ForEach(ConnectedSource.allCases) { source in
                    ConnectRow(
                        source: source,
                        connected: vm.connected.contains(source),
                        busy: vm.connecting == source
                    ) {
                        handleTap(source)
                    }
                }
            }
            .padding(.top, 22)
            Spacer()
            ObNext(label: vm.connected.isEmpty ? "PLUS TARD" : "CONTINUER", action: onNext)
        }
    }

    private func handleTap(_ source: ConnectedSource) {
        // Strava/Garmin have no real integration yet — tapping them does nothing rather than
        // faking a successful connection (see ConnectRow below).
        guard source == .apple, !vm.connected.contains(.apple) else { return }
        vm.connecting = .apple
        Task {
            do {
                try await appState.healthKit.requestAuthorization()
                await MainActor.run {
                    vm.connected.insert(.apple)
                    vm.connecting = nil
                }
            } catch {
                // HealthKit deliberately never reveals whether she actually granted or denied each
                // individual read type (a privacy design choice by Apple) — this only throws for a
                // genuine failure (HealthKit unavailable on this device, a malformed type list),
                // which is the one case worth surfacing as "not connected" instead of the old
                // `try?` swallowing it and marking `.apple` connected regardless of outcome.
                await MainActor.run {
                    vm.connecting = nil
                    appState.toast("Connexion à Apple Santé impossible, réessaie plus tard.")
                }
            }
        }
    }
}

private struct ConnectRow: View {
    var source: ConnectedSource
    var connected: Bool
    var busy: Bool
    var action: () -> Void

    /// Real brand logos instead of the 🍎/🟠/⌚ emoji stand-ins — same asset-naming contract as
    /// `BrandLogoIcon` (Profil's data-source rows), Apple stays an SF Symbol (its logo IS a
    /// system symbol).
    @ViewBuilder
    private var icon: some View {
        switch source {
        case .apple:
            Image(systemName: "apple.logo").font(.system(size: 18)).foregroundColor(RUColor.textPrimary)
        case .strava:
            BrandLogoIcon(assetName: "strava-logo", fallbackText: "S", fullBleed: true, size: 26)
        case .garmin:
            BrandLogoIcon(assetName: "garmin-logo", fallbackText: "G", fullBleed: false, size: 26)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon
                    .frame(width: 40, height: 40)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title).font(RUFont.sans(15, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    Text(source.subtitle).font(RUFont.sans(11.5)).foregroundColor(RUColor.text2)
                }
                Spacer()
                if source != .apple {
                    Text("Bientôt").font(RUFont.sans(11, weight: .semibold)).foregroundColor(RUColor.text3)
                } else if busy {
                    ProgressView().tint(RUColor.textPrimary)
                } else if connected {
                    Text("CONNECTÉ ✓").font(RUFont.sans(11, weight: .bold)).foregroundColor(RUColor.lime)
                } else {
                    Text("Connecter")
                        .font(RUFont.sans(11, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }
            }
            .padding(15)
            .opacity(source != .apple ? 0.5 : 1)
            .background(connected ? RUColor.lime.opacity(0.1) : RUColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(connected ? RUColor.lime.opacity(0.35) : RUColor.line, lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
        .disabled(source != .apple)
    }
}
