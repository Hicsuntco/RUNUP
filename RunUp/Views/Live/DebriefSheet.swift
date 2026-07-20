import SwiftUI
import StoreKit

/// RPE debrief bottom sheet — submitting this is the core adaptive-plan mechanic. Mirrors the
/// `debrief` sheet inside `RecapScreen` in screensA.jsx.
struct DebriefSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    var run: RunRecord
    @State private var rpe: RPE = .justeBien

    /// The plan only ever re-adjusts at a week boundary (see `AdaptivePlanEngine.tierDelta`),
    /// never session-to-session — this used to say "Prochaine séance" (next session), implying
    /// tomorrow's plan would shift, when what's really true is the *next week's* plan reacts to
    /// this week's average RPE. Wording it any tighter than "semaine prochaine" would be a promise
    /// the engine doesn't keep.
    /// Was a single hardcoded line claiming the last split was always the fastest and "FC
    /// maîtrisée en Z4" — true or not, for every run. Now derived from `run.splits`'s real pace
    /// values (no HR-zone claim at all: there's no real per-user zone threshold to check FC
    /// against, so that part is dropped rather than kept as an unbacked guess).
    private var insightMessage: String {
        let paces = run.splits.compactMap(paceSeconds)
        guard paces.count > 1, let minPace = paces.min(), let maxPace = paces.max(), maxPace > minPace else {
            return "Séance enregistrée 💪 Bien joué."
        }
        if paces.last == minPace {
            return "Séance solide 💪 Ton dernier kilomètre était ton plus rapide — tu avais encore du jus."
        }
        if paces.first == minPace {
            return "Séance solide 💪 Tu es partie fort et tu as tenu jusqu'au bout."
        }
        return "Séance solide 💪 Allure plutôt régulière du début à la fin."
    }

    private func paceSeconds(_ time: String) -> Double? {
        let parts = time.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    private var impactLines: [(String, String, String)] {
        let nextStreak = appState.profile.streak + 1
        switch rpe {
        case .facile, .justeBien:
            return [("📈", "Semaine prochaine : ", "relevée d'un palier"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        case .dur:
            return [("👍", "Semaine prochaine : ", "on garde la même intensité"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        case .tropDur:
            return [("🧘", "Semaine prochaine : ", "récupération allégée"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EyebrowLabel(text: "Bilan · \(run.title)", color: RUColor.rose).padding(.top, 8)
                Text("Comment tu te sens ?").displayStyle(24).foregroundColor(RUColor.textPrimary).padding(.top, 4)

                HStack(alignment: .top, spacing: 10) {
                    AppMarkView(size: 18, radius: 9)
                    Text(insightMessage)
                        .font(RUFont.sans(13)).foregroundColor(RUColor.textPrimary).lineSpacing(3)
                }
                .padding(14)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            (Text(impactLines[i].1).foregroundColor(RUColor.text2)
                                + Text(impactLines[i].2).foregroundColor(i == 0 ? RUColor.textPrimary : RUColor.cyan).fontWeight(.bold))
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
                    let distance = String(format: "%.1f", run.distanceKm)
                    appState.postClubActivity(type: "run", text: "a couru \(distance) km · \(run.title)", xpEarned: 120, distanceKm: run.distanceKm)
                    if AdaptivePlanEngine.checkDailyGoalsBonus(appState.profile) {
                        appState.postClubActivity(type: "badge", text: "a bouclé ses 3 objectifs du jour", xpEarned: 120)
                        appState.notify(icon: "🎉", colorHex: 0xC9FF3B, title: "Journée bouclée", text: "Tes 3 objectifs du jour sont faits — +120 XP.")
                    }
                    // Today's session is done — an evening reminder for it would be stale now.
                    NotificationService.shared.rescheduleDailyReminder(for: appState.profile)
                    appState.toast("Programme mis à jour · +120 XP 🔥")
                    // Ask for a rating right after a run that felt good, not on a fixed schedule —
                    // `shouldRequestReview` also caps this to real milestones and a 90-day cooldown.
                    if appState.shouldRequestReview(rpe: rpe) {
                        appState.recordReviewPromptShown()
                        requestReview()
                    }
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
