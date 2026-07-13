import SwiftUI

/// RPE debrief bottom sheet — submitting this is the core adaptive-plan mechanic. Mirrors the
/// `debrief` sheet inside `RecapScreen` in screensA.jsx.
struct DebriefSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var run: RunRecord
    @State private var rpe: RPE = .justeBien

    private var impactLines: [(String, String, String)] {
        let nextStreak = appState.profile.streak + 1
        switch rpe {
        case .facile, .justeBien:
            return [("📈", "Prochaine séance : ", "relevée d'un palier"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        case .dur:
            return [("👍", "Prochaine séance : ", "on garde la même intensité"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        case .tropDur:
            return [("🧘", "Prochaine séance : ", "récupération allégée"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EyebrowLabel(text: "Bilan · \(run.title)", color: RUColor.rose).padding(.top, 8)
                Text("Comment tu te sens ?").displayStyle(24).foregroundColor(.white).padding(.top, 4)

                HStack(alignment: .top, spacing: 10) {
                    AppMarkView(size: 18, radius: 9)
                    Text("Séance solide 💪 Ton dernier bloc était ton plus rapide — tu avais encore du jus. FC maîtrisée en Z4.")
                        .font(RUFont.sans(13)).foregroundColor(.white).lineSpacing(3)
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                .padding(.top, 14)

                EyebrowLabel(text: "L'effort ressenti", color: RUColor.text3).padding(.top, 18).padding(.bottom, 10)
                HStack(spacing: 6) {
                    ForEach(RPE.allCases) { opt in
                        Button(action: { rpe = opt }) {
                            VStack(spacing: 5) {
                                Text(opt.emoji).font(.system(size: 22))
                                Text(opt.label).font(RUFont.sans(9, weight: .semibold)).foregroundColor(rpe == opt ? RUColor.rose2 : RUColor.text2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(rpe == opt ? RUColor.rose.opacity(0.12) : RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(rpe == opt ? RUColor.rose.opacity(0.35) : RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: "Impact sur ton programme", color: RUColor.rose2)
                    ForEach(impactLines.indices, id: \.self) { i in
                        HStack(spacing: 12) {
                            Text(impactLines[i].0).font(.system(size: 18))
                            (Text(impactLines[i].1).foregroundColor(.white.opacity(0.75))
                                + Text(impactLines[i].2).foregroundColor(i == 0 ? .white : RUColor.cyan).fontWeight(.bold))
                                .font(RUFont.sans(12.5))
                                .lineSpacing(2)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, i == 0 ? 12 : 0)
                        .overlay(alignment: .bottom) {
                            if i == 0 { Divider().background(RUColor.line) }
                        }
                    }
                }
                .padding(16)
                .ruHeroCard(radius: 18)
                .padding(.top, 16)

                Button("VALIDER & METTRE À JOUR") {
                    AdaptivePlanEngine.applyDebrief(rpe: rpe, run: run, profile: appState.profile)
                    appState.toast("Programme mis à jour · +120 XP 🔥")
                    dismiss()
                    appState.go(.rings)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 16)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }
}
