import SwiftUI

// Watch-local design tokens — the iOS app's RUColor/RUFont live in RunUp/DesignSystem (not a
// shared target source), and the watch only needs this handful of values. Same Midnight Rose
// palette as the phone, via the shared Color(hex:).
private enum WTheme {
    // True flat black, not the near-black `0x0E0E14` this used to be — matches the flat, no-
    // gradient "scoreboard" treatment the widgets and Live Activity moved to.
    static let bg = Color.black
    static let card = Color(hex: 0x191922)
    static let rose = Color(hex: 0xFF3D7F)
    static let violet = Color(hex: 0x8A5CFF)
    static let lime = Color(hex: 0xC8F542)
    static let text2 = Color.white.opacity(0.62)
    static let text3 = Color.white.opacity(0.38)

    static let roseVioletGradient = LinearGradient(colors: [rose, violet], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Passe par `DisplayFont` (RunUp/Shared) : même police et même facteur de taille que
    /// l'app et le widget, décidés à un seul endroit.
    static func display(_ size: CGFloat) -> Font { DisplayFont.font(size) }
    static func sansBold(_ size: CGFloat) -> Font { .custom("DMSans-Bold", size: size) }
    static func sansSemibold(_ size: CGFloat) -> Font { .custom("DMSans-SemiBold", size: size) }

    /// Anciennement figé sur `fr_FR`, ce qui imposait la virgule décimale à TOUT le monde : une
    /// utilisatrice anglophone ou hispanophone voyait « 3,25 km » là où son système écrit
    /// « 3.25 km ». Le séparateur décimal suit maintenant les réglages de la montre.
    static var locale: Locale { .current }
}

// MARK: - Start

/// Idle screen: today's session as pushed by the phone (title + target pace + duration), or a
/// "course libre" framing when the phone hasn't synced anything yet — never a fake placeholder
/// session. The COURIR button is a full circle (not a pill) with a dashed gradient ring around
/// it, echoing the same rose→violet ring language used for real progress on the run/summary
/// screens — here purely decorative since there's nothing to track yet.
struct WatchStartView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    private var connectivity: WatchConnectivityManager { .shared }

    private var subtitleText: String {
        switch (connectivity.sessionPace, connectivity.sessionDurationMinutes) {
        case let (pace?, minutes?): return "\(pace) /km · \(minutes) min"
        case let (pace?, nil): return "\(pace) /km"
        case let (nil, minutes?): return "\(minutes) min"
        case (nil, nil): return ""
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("AUJOURD'HUI")
                    .font(WTheme.sansBold(11))
                    .tracking(1.2)
                    .foregroundStyle(WTheme.rose)

                // `Text(String)` ne traduit PAS (contrairement à `Text("littéral")`), d'où le
                // `String(localized:)` explicite sur le repli.
                Text(connectivity.sessionTitle ?? String(localized: "Course libre"))
                    .font(WTheme.display(21))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                ZStack {
                    Circle()
                        .strokeBorder(WTheme.roseVioletGradient, style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                        .opacity(0.55)
                        .frame(width: 118, height: 118)

                    Button(action: { workout.start() }) {
                        Group {
                            if workout.state == .starting {
                                ProgressView().tint(.white)
                            } else {
                                Text("COURIR").font(WTheme.display(16)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 92, height: 92)
                        .background(WTheme.roseVioletGradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(workout.state == .starting)
                }
                .padding(.vertical, 2)

                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(WTheme.sansBold(11))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text("Cours à ta sensation — ta séance arrive de l'iPhone.")
                        .font(WTheme.sansSemibold(11))
                        .foregroundStyle(WTheme.text2)
                        .multilineTextAlignment(.center)
                }

                if let message = workout.errorMessage {
                    Text(message)
                        .font(WTheme.sansSemibold(10.5))
                        .foregroundStyle(WTheme.rose)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
        }
        .background(WTheme.bg)
    }
}

// MARK: - Live run

/// The in-run screen: elapsed time as the hero inside a progress ring, then the four live
/// metrics. Heart rate shows "--" until a real wrist sample lands (honest-data policy — same as
/// the iPhone live screen).
struct WatchRunView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    private var connectivity: WatchConnectivityManager { .shared }

    private var distanceLabel: String {
        String(format: "%.2f", locale: WTheme.locale, workout.distanceMeters / 1000)
    }

    /// Elapsed vs. the session's planned duration — nil (ring hidden) for a free run with no
    /// real target synced from the phone, same "no fabricated progress" policy as the Live
    /// Activity's own duration bar.
    private var progressFraction: Double? {
        guard let minutes = connectivity.sessionDurationMinutes, minutes > 0 else { return nil }
        return max(0, min(1, workout.elapsedSeconds / Double(minutes * 60)))
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(workout.state == .paused ? WTheme.text3 : WTheme.lime)
                    .frame(width: 6, height: 6)
                Text(workout.state == .paused ? "EN PAUSE" : "EN COURS")
                    .font(WTheme.sansBold(10))
                    .tracking(1)
                    .foregroundStyle(workout.state == .paused ? WTheme.text3 : WTheme.lime)
            }

            ZStack {
                if let fraction = progressFraction {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            workout.state == .paused ? AnyShapeStyle(Color.white.opacity(0.28)) : AnyShapeStyle(WTheme.roseVioletGradient),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: workout.state == .paused ? [5, 6] : [])
                        )
                        .rotationEffect(.degrees(-90))
                }

                Text(workout.elapsedLabel)
                    .font(WTheme.display(38))
                    .foregroundStyle(workout.state == .paused ? .white.opacity(0.5) : .white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .frame(width: 118, height: 118)

            HStack(spacing: 5) {
                metric(value: distanceLabel, unit: "KM")
                metric(value: workout.paceLabel, unit: "/KM", accent: WTheme.rose)
            }
            HStack(spacing: 5) {
                metric(value: workout.heartRate.map(String.init) ?? "--", unit: "BPM", accent: WTheme.violet)
                metric(value: "\(Int(workout.activeCalories.rounded()))", unit: "KCAL")
            }

            HStack(spacing: 6) {
                Button(action: { workout.togglePause() }) {
                    Image(systemName: workout.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(WTheme.card, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { workout.end() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(WTheme.rose, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WTheme.bg)
    }

    // No card fill behind these — flat numbers directly on black, same "scoreboard" treatment
    // the widgets and Live Activity moved to, instead of each stat boxed in its own tile.
    private func metric(value: String, unit: String, accent: Color = .white) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(WTheme.display(22))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(WTheme.sansBold(8.5))
                .tracking(1)
                .foregroundStyle(WTheme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Summary

/// Post-run screen: one hero number (distance) inside a completed gradient ring, then the
/// secondary numbers as a compact row — and where the story continues, since the phone received
/// the run (queued transfer, arrives even if the iPhone is out of reach right now) and builds the
/// debrief.
struct WatchSummaryView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    private var distanceLabel: String {
        String(format: "%.2f", locale: WTheme.locale, workout.distanceMeters / 1000)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("✓ TERMINÉ")
                    .font(WTheme.sansBold(10.5))
                    .tracking(1)
                    .foregroundStyle(WTheme.lime)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(WTheme.lime.opacity(0.12), in: Capsule())

                ZStack {
                    Circle()
                        .stroke(WTheme.roseVioletGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                    VStack(spacing: 0) {
                        Text(distanceLabel)
                            .font(WTheme.display(34))
                            .foregroundStyle(.white)
                        Text("KM")
                            .font(WTheme.sansBold(9.5))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 108, height: 108)
                .padding(.vertical, 2)

                HStack(spacing: 14) {
                    metric(value: workout.elapsedLabel, unit: "TEMPS")
                    metric(value: workout.paceLabel, unit: "/KM", accent: WTheme.rose)
                    metric(value: workout.avgHeartRate.map(String.init) ?? "--", unit: "BPM MOY", accent: WTheme.violet)
                }

                Text("Ton bilan t'attend sur l'iPhone 📱")
                    .font(WTheme.sansSemibold(11))
                    .foregroundStyle(WTheme.text2)
                    .multilineTextAlignment(.center)

                Button(action: { workout.reset() }) {
                    Text("OK")
                        .font(WTheme.display(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(WTheme.card, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
        .background(WTheme.bg)
    }

    private func metric(value: String, unit: String, accent: Color = .white) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(WTheme.display(18))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(WTheme.sansBold(7.5))
                .tracking(1)
                .foregroundStyle(WTheme.text3)
        }
    }
}
