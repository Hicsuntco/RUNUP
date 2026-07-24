import SwiftUI

// Watch-local design tokens — the iOS app's RUColor/RUFont live in RunUp/DesignSystem (not a
// shared target source), and the watch only needs this handful of values. Same Midnight Rose
// palette as the phone, via the shared Color(hex:).
private enum WTheme {
    static let bg = Color(hex: 0x0E0E14)
    static let card = Color(hex: 0x191922)
    static let rose = Color(hex: 0xFF3D7F)
    static let violet = Color(hex: 0x8A5CFF)
    static let lime = Color(hex: 0xC8F542)
    static let text2 = Color.white.opacity(0.62)
    static let text3 = Color.white.opacity(0.38)

    static func bebas(_ size: CGFloat) -> Font { .custom("BebasNeue-Regular", size: size) }
    static func sansBold(_ size: CGFloat) -> Font { .custom("DMSans-Bold", size: size) }
    static func sansSemibold(_ size: CGFloat) -> Font { .custom("DMSans-SemiBold", size: size) }

    static let fr = Locale(identifier: "fr_FR")
}

// MARK: - Start

/// Idle screen: today's session as pushed by the phone (title + target pace + duration), or a
/// "course libre" framing when the phone hasn't synced anything yet — never a fake placeholder
/// session.
struct WatchStartView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    private var connectivity: WatchConnectivityManager { .shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("AUJOURD'HUI")
                    .font(WTheme.sansBold(11))
                    .tracking(1.2)
                    .foregroundStyle(WTheme.rose)

                Text(connectivity.sessionTitle ?? "Course libre")
                    .font(WTheme.bebas(24))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)

                if connectivity.sessionPace != nil || connectivity.sessionDurationMinutes != nil {
                    HStack(spacing: 6) {
                        if let pace = connectivity.sessionPace {
                            sessionChip(pace + " /km")
                        }
                        if let minutes = connectivity.sessionDurationMinutes {
                            sessionChip("\(minutes) min")
                        }
                    }
                } else {
                    Text("Cours à ta sensation — ta séance arrive de l'iPhone.")
                        .font(WTheme.sansSemibold(11))
                        .foregroundStyle(WTheme.text2)
                        .multilineTextAlignment(.center)
                }

                Button(action: { workout.start() }) {
                    Text("COURIR")
                        .font(WTheme.bebas(22))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(colors: [WTheme.rose, WTheme.violet], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                if let message = workout.errorMessage {
                    Text(message)
                        .font(WTheme.sansSemibold(10.5))
                        .foregroundStyle(WTheme.rose)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WTheme.bg)
    }

    private func sessionChip(_ label: String) -> some View {
        Text(label)
            .font(WTheme.sansBold(11))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(WTheme.card, in: Capsule())
    }
}

// MARK: - Live run

/// The in-run screen: elapsed time as the hero, then the four live metrics. Heart rate shows "--"
/// until a real wrist sample lands (honest-data policy — same as the iPhone live screen).
struct WatchRunView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    private var distanceLabel: String {
        String(format: "%.2f", locale: WTheme.fr, workout.distanceMeters / 1000)
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

            Text(workout.elapsedLabel)
                .font(WTheme.bebas(46))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())

            HStack(spacing: 5) {
                metric(value: distanceLabel, unit: "KM")
                metric(value: workout.paceLabel, unit: "/KM")
            }
            HStack(spacing: 5) {
                metric(value: workout.heartRate.map(String.init) ?? "--", unit: "BPM", accent: WTheme.rose)
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

    private func metric(value: String, unit: String, accent: Color = .white) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(WTheme.bebas(21))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(WTheme.sansBold(8.5))
                .tracking(0.8)
                .foregroundStyle(WTheme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(WTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Summary

/// Post-run screen: the final numbers, and where the story continues — the phone received the run
/// (queued transfer, arrives even if the iPhone is out of reach right now) and builds the debrief.
struct WatchSummaryView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    private var distanceLabel: String {
        String(format: "%.2f", locale: WTheme.fr, workout.distanceMeters / 1000)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("TERMINÉ 🎉")
                    .font(WTheme.bebas(26))
                    .foregroundStyle(.white)

                HStack(spacing: 5) {
                    metric(value: distanceLabel, unit: "KM")
                    metric(value: workout.elapsedLabel, unit: "TEMPS")
                }
                HStack(spacing: 5) {
                    metric(value: workout.paceLabel, unit: "/KM")
                    metric(value: workout.avgHeartRate.map(String.init) ?? "--", unit: "BPM MOY", accent: WTheme.rose)
                }

                Text("Ton bilan t'attend sur l'iPhone 📱")
                    .font(WTheme.sansSemibold(11))
                    .foregroundStyle(WTheme.text2)
                    .multilineTextAlignment(.center)

                Button(action: { workout.reset() }) {
                    Text("OK")
                        .font(WTheme.bebas(18))
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
        VStack(spacing: 0) {
            Text(value)
                .font(WTheme.bebas(21))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(WTheme.sansBold(8.5))
                .tracking(0.8)
                .foregroundStyle(WTheme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(WTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
