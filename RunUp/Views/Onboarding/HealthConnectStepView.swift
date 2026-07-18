import SwiftUI

/// Step 6 — data source connections. Apple Santé uses the real HealthKit authorization prompt;
/// Strava/Garmin are UI stubs per the brief ("peuvent rester des stubs à connecter pour une v1").
struct HealthConnectStepView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
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
            try? await appState.healthKit.requestAuthorization()
            await MainActor.run {
                vm.connected.insert(.apple)
                vm.connecting = nil
            }
        }
    }
}

private struct ConnectRow: View {
    var source: ConnectedSource
    var connected: Bool
    var busy: Bool
    var action: () -> Void

    private var icon: String {
        switch source {
        case .apple: return "🍎"
        case .strava: return "🟠"
        case .garmin: return "⌚"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(icon).font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title).font(RUFont.sans(15, weight: .semibold)).foregroundColor(.white)
                    Text(source.subtitle).font(RUFont.sans(11.5)).foregroundColor(RUColor.text2)
                }
                Spacer()
                if source != .apple {
                    Text("Bientôt").font(RUFont.sans(11, weight: .semibold)).foregroundColor(RUColor.text3)
                } else if busy {
                    ProgressView().tint(.white)
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
