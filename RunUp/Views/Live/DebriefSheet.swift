import SwiftUI
import SwiftData
import StoreKit

/// RPE debrief bottom sheet — submitting this is the core adaptive-plan mechanic. Mirrors the
/// `debrief` sheet inside `RecapScreen` in screensA.jsx.
struct DebriefSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Query(filter: #Predicate<Shoe> { $0.retiredAt == nil }) private var activeShoes: [Shoe]
    @Query private var runs: [RunRecord]
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
        let paces = run.splits.compactMap(PaceModel.parseSecPerKm)
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

    private var impactLines: [(String, String, String)] {
        // A second run validated the same day (a different device, or just a second session)
        // doesn't get its own streak day — `applyDebrief`'s own gapDays == 0 branch already
        // no-ops the increment in that case. `seanceDoneToday` is set by the very same call that
        // sets `lastStreakDate`, so it's a reliable read of "did a debrief already land today?"
        // taken here, before this tap's own debrief has run.
        let alreadyCountedToday = appState.profile.seanceDoneToday
        let nextStreak = alreadyCountedToday ? appState.profile.streak : appState.profile.streak + 1
        // Phrased as a tendency ("compte pour...") — the tier really moves on the WEEK's average
        // RPE at the boundary, so a flat promise ("relevée d'un palier") from one single tap
        // could contradict what actually happens after two harder sessions the same week.
        switch rpe {
        case .facile, .justeBien:
            return [("📈", "Semaine prochaine : ", "compte pour relever l'intensité"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        case .dur:
            return [("👍", "Semaine prochaine : ", "compte pour garder ce niveau"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
        case .tropDur:
            return [("🧘", "Semaine prochaine : ", "compte pour alléger la charge"), ("🔥", "Série en cours : ", "jour \(nextStreak)")]
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
                        // The app's own core adaptive-plan mechanic, asked after every single run
                        // — selected state was conveyed by color alone, so VoiceOver had no way to
                        // confirm which option was picked before tapping VALIDER.
                        .accessibilityAddTraits(rpe == opt ? .isSelected : [])
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
                    // Blocks a double-tap (or reopening this sheet for a run already validated)
                    // from crediting XP/streak/club-feed a second time for the same run —
                    // `run.modelContext == nil` below only ever guarded the INSERT, not a second
                    // run through the reward logic on a record already inserted.
                    guard run.debriefedAt == nil else { dismiss(); return }
                    run.debriefedAt = .now
                    // A GPS run is inserted by `endLiveRun` (it really happened, validated or
                    // not); a manual "FAIT" run reaches here NOT yet inserted, so a dismissed
                    // sheet leaves no phantom record — it only becomes real on this tap.
                    if run.modelContext == nil {
                        appState.modelContext.insert(run)
                    }
                    // Auto-attaches whichever pair is set as default in `ShoesView` — asking her
                    // to pick a shoe on every single run here would clutter the one screen that
                    // matters most (the RPE debrief); a wrong pick is a rare enough edge case to
                    // just fix from History/ShoesView instead of designing a picker into this flow.
                    if let shoeID = appState.profile.defaultShoeID, let shoe = activeShoes.first(where: { $0.id == shoeID }) {
                        run.shoeID = shoeID
                        // `runs` may or may not already include this exact run (GPS runs are
                        // inserted earlier by `endLiveRun`, manual ones aren't yet) — excluding it
                        // by identity and adding `run.distanceKm` back by hand sidesteps that
                        // instead of risking a double count.
                        let kmBefore = shoe.totalKm(runs: runs.filter { $0 !== run })
                        let kmAfter = kmBefore + run.distanceKm
                        if kmBefore < shoe.alertThresholdKm, kmAfter >= shoe.alertThresholdKm {
                            appState.notify(icon: "👟", colorHex: 0xFFB03D, title: "\(shoe.name) en fin de vie", text: "Cette paire dépasse \(Int(shoe.alertThresholdKm)) km — pense à la changer bientôt.")
                        }
                    }
                    AdaptivePlanEngine.applyDebrief(rpe: rpe, run: run, profile: appState.profile)
                    let distance = String(format: "%.1f", locale: Locale(identifier: "fr_FR"), run.distanceKm)
                    // A distance-less séance (HYROX/renfo logged without GPS) shouldn't read
                    // "a couru 0,0 km" in the club feed.
                    let feedText = run.distanceKm > 0.05
                        ? "a couru \(distance) km · \(run.title)"
                        : "a fait sa séance · \(run.title)"
                    appState.postClubActivity(type: "run", text: feedText, xpEarned: 120, distanceKm: run.distanceKm)
                    // Every completed session earns its own bell entry — before this, the only
                    // notify() call sites were the rare same-day 3-goals bonus, a club kudos/
                    // comment, or a weekly plan update, so a solo runner who just isn't hitting
                    // that exact daily combo would never see anything land in the bell at all.
                    appState.notify(icon: "✅", colorHex: 0xC9FF3B, title: "Séance terminée", text: run.distanceKm > 0.05 ? "\(run.title) · \(distance) km · +120 XP" : "\(run.title) · +120 XP")
                    // This single tap awards XP, updates the streak, and possibly a daily-goals
                    // bonus — the app's core adaptive-plan mechanic — but had zero haptic feedback,
                    // the same as tapping a settings toggle. A success tap here, and a stronger one
                    // on the two branches below that are genuine celebration moments.
                    Haptics.success()
                    let streak = appState.profile.streak
                    if AdaptivePlanEngine.streakMilestones.contains(streak) {
                        appState.notify(icon: "🔥", colorHex: 0xFF6B4A, title: "Série de \(streak) jours", text: "Tu enchaînes les séances sans lâcher — continue comme ça !")
                        Haptics.impact(.heavy)
                    }
                    if AdaptivePlanEngine.checkDailyGoalsBonus(appState.profile) {
                        appState.postClubActivity(type: "badge", text: "a bouclé ses 3 objectifs du jour", xpEarned: 120)
                        appState.notify(icon: "🎉", colorHex: 0xC9FF3B, title: "Journée bouclée", text: "Tes 3 objectifs du jour sont faits — +120 XP.")
                        NotificationService.shared.postImmediateNotification(title: "Journée bouclée 🎉", body: "Tes 3 objectifs du jour sont faits — +120 XP.")
                        Haptics.impact(.heavy)
                    }
                    // Today's session is done — an evening reminder for it would be stale now.
                    NotificationService.shared.rescheduleDailyReminder(for: appState.profile)
                    appState.publishWidgetSnapshot()
                    appState.toast("Programme mis à jour · +120 XP 🔥")
                    // Ask for a rating right after a run that felt good, not on a fixed schedule —
                    // `shouldRequestReview` also caps this to real milestones and a 90-day cooldown.
                    if appState.shouldRequestReview(rpe: rpe) {
                        appState.recordReviewPromptShown()
                        requestReview()
                        // `requestReview()` only hands the request to the window scene — presenting
                        // it is async and risks getting silently dropped if this sheet dismisses and
                        // navigates away in the same synchronous burst, which is exactly what used
                        // to happen right here. Give it a beat to actually attach before tearing
                        // down the presenting context.
                        Task {
                            try? await Task.sleep(for: .milliseconds(600))
                            await MainActor.run {
                                dismiss()
                                appState.go(.rings)
                            }
                        }
                    } else {
                        dismiss()
                        appState.go(.rings)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 16)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }
}
