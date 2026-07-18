import SwiftUI

/// "Forme du jour" detail — previously this and the daily-goals widget both opened the exact
/// same screen (`.rings`), so there was nowhere to actually explain the readiness score. Shows
/// what `UserProfile.readiness` is really computed from (recent perceived-effort trend + current
/// streak), not just the number.
struct ReadinessView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    private static let severityEmoji = ["😎", "🙂", "😤", "😮‍💨"] // 0 facile ... 3 tropDur
    private static let severityLabel = ["Facile", "Juste bien", "Dur", "Trop dur"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.home) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "Aujourd'hui", color: RUColor.lime)
                        Text("Forme du jour").displayStyle(22).foregroundColor(.white)
                    }
                }

                VStack(spacing: 10) {
                    if profile.hasReadinessData {
                        RingView(pct: Double(profile.readiness), color: RUColor.lime, size: 140, strokeWidth: 10) {
                            VStack(spacing: 2) {
                                Text("\(profile.readiness)").displayStyle(30).foregroundColor(RUColor.lime)
                                Text("/ 100").font(RUFont.mono(11)).foregroundColor(RUColor.text2)
                            }
                        }
                        Text("Forme \(profile.readinessLabel)").font(RUFont.sans(15, weight: .semibold)).foregroundColor(.white)
                    } else {
                        // An empty ring, not the near-full default score — there's no real RPE
                        // behind it yet, so nothing should read as "already measured".
                        RingView(pct: 0, color: RUColor.text3, size: 140, strokeWidth: 10) {
                            Text("–").displayStyle(30).foregroundColor(RUColor.text3)
                        }
                        Text("Pas encore de données").font(RUFont.sans(15, weight: .semibold)).foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Basé sur", color: RUColor.text3)
                    HStack(spacing: 10) {
                        Text("🔥").font(.system(size: 16))
                        Text("Série en cours : jour \(profile.streak)").font(RUFont.sans(13)).foregroundColor(.white)
                    }
                    if profile.recentRPESeverities.isEmpty {
                        Text("Pas encore de séance enregistrée — la forme du jour s'affine après ta première course.")
                            .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    } else {
                        Text("Ressenti d'effort de tes \(profile.recentRPESeverities.count) dernières séances :")
                            .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                        HStack(spacing: 8) {
                            ForEach(Array(profile.recentRPESeverities.enumerated()), id: \.offset) { _, severity in
                                let clamped = max(0, min(3, severity))
                                VStack(spacing: 4) {
                                    Text(Self.severityEmoji[clamped]).font(.system(size: 20))
                                    Text(Self.severityLabel[clamped]).font(RUFont.sans(8, weight: .semibold)).foregroundColor(RUColor.text2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(16)
                .ruCard()

                Text("Un score bas ne veut pas dire qu'il faut sauter ta séance — c'est un repère, pas une règle. Le coach peut t'aider à décider.")
                    .font(RUFont.sans(11.5)).foregroundColor(RUColor.text3).lineSpacing(2)

                Button(action: { appState.go(.coach) }) {
                    HStack { Text("💬"); Text("EN PARLER AU COACH") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }
}
