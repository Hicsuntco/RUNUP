import SwiftUI

// Watch-local design tokens — the iOS app's RUColor/RUFont live in RunUp/DesignSystem (not a
// shared target source), and the watch only needs this handful of values. Same Midnight Rose
// palette as the phone, via the shared Color(hex:).
private enum WTheme {
    // True flat black, not the near-black `0x0E0E14` this used to be — matches the flat, no-
    // gradient "scoreboard" treatment the widgets and Live Activity moved to.
    static let bg = Color.black
    static let card = Color(hex: 0x191922)
    // Alignés sur `AccentTheme` côté app (rose #FF0F5B, violet #7C5CFF, lime #C8FF3D). La montre
    // portait #FF3D7F, #8A5CFF et #C8F542 — un écart faible, réel, et justifié nulle part : le
    // même rose n'était pas le même d'un écran à l'autre.
    static let rose = Color(hex: 0xFF0F5B)
    static let violet = Color(hex: 0x7C5CFF)
    static let lime = Color(hex: 0xC8FF3D)
    static let text2 = Color.white.opacity(0.62)
    static let text3 = Color.white.opacity(0.38)

    static let roseVioletGradient = LinearGradient(colors: [rose, violet], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Passe par `DisplayFont` (RunUp/Shared) : même police et même facteur de taille que
    /// l'app et le widget, décidés à un seul endroit.
    static func display(_ size: CGFloat) -> Font { DisplayFont.font(size) }
    static func sansBold(_ size: CGFloat) -> Font { .custom("\(DisplayFont.family)-Bold", size: size) }
    static func sansSemibold(_ size: CGFloat) -> Font { .custom("\(DisplayFont.family)-SemiBold", size: size) }

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
                Text("Aujourd'hui")
                    .font(WTheme.sansBold(11))
                    .tracking(0.2)
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
                                Text("Courir").font(WTheme.display(16)).foregroundStyle(.white)
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

/// L'écran de course : UN chiffre, énorme, et trois petits sous lui.
///
/// La version précédente mettait le chrono dans un anneau et alignait quatre métriques en 2 × 2.
/// Six chiffres se disputaient l'écran : en courant, on cherche le sien et on ne le trouve pas du
/// premier coup d'œil. C'est le seul écran de l'app qu'on lit le bras qui balance, à trois
/// secondes près — il n'a de valeur que s'il se lit sans s'arrêter.
///
/// Ce qui est affiché vient de `WatchConnectivityManager.runLayout`, choisi dans les réglages du
/// téléphone : le héros et les trois secondaires. La montre ne décide de rien, elle rend.
struct WatchRunView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    private var connectivity: WatchConnectivityManager { .shared }
    private var layout: WatchRunLayout { connectivity.runLayout }

    /// Avancement dans la séance — `nil`, donc barre masquée, pour une course libre sans objectif
    /// réel synchronisé depuis le téléphone. Même politique que partout ailleurs : pas de
    /// progression inventée.
    ///
    /// Toujours la DURÉE, quel que soit le héros choisi. C'est le seul objectif qu'une séance
    /// porte : elles sont définies en minutes, jamais en kilomètres. Une barre qui suivrait la
    /// distance avancerait vers un but qui n'existe pas.
    private var progressFraction: Double? {
        guard let minutes = connectivity.sessionDurationMinutes, minutes > 0 else { return nil }
        return max(0, min(1, workout.elapsedSeconds / Double(minutes * 60)))
    }

    private func value(_ metric: RunMetric) -> String {
        switch metric {
        case .time: return workout.elapsedLabel
        case .distance: return String(format: "%.2f", locale: WTheme.locale, workout.distanceMeters / 1000)
        case .pace: return workout.paceLabel
        case .heartRate: return workout.heartRate.map(String.init) ?? "--"
        case .calories: return "\(Int(workout.activeCalories.rounded()))"
        }
    }

    private func tint(_ metric: RunMetric) -> Color {
        switch metric {
        case .pace: return WTheme.rose
        case .heartRate: return WTheme.violet
        default: return .white
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(workout.state == .paused ? WTheme.text3 : WTheme.lime)
                    .frame(width: 6, height: 6)
                Text(workout.state == .paused ? "EN PAUSE" : "EN COURS")
                    .font(WTheme.sansBold(10))
                    .tracking(0.2)
                    .foregroundStyle(workout.state == .paused ? WTheme.text3 : WTheme.lime)
            }

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(value(layout.hero))
                    .font(WTheme.display(50))
                    .foregroundStyle(workout.state == .paused ? tint(layout.hero).opacity(0.5) : tint(layout.hero))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(LocalizedStringKey(layout.hero.nameKey))
                    .font(WTheme.sansBold(10))
                    .tracking(0.24)
                    .textCase(.uppercase)
                    .foregroundStyle(WTheme.text3)
            }

            if let fraction = progressFraction {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(workout.state == .paused ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(WTheme.roseVioletGradient))
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 4)
                    Text("Séance · \(Int((fraction * 100).rounded())) %")
                        .font(WTheme.sansBold(9))
                        .tracking(0.2)
                        .textCase(.uppercase)
                        .foregroundStyle(WTheme.text3)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                ForEach(layout.secondary, id: \.self) { metric in
                    VStack(spacing: 1) {
                        Text(value(metric))
                            .font(WTheme.display(17))
                            .foregroundStyle(tint(metric))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        // `Text(String)` ne consulte PAS le catalogue — seul `Text(LocalizedStringKey)`
                        // le fait. Sans ça, « Temps » restait français même catalogue chargé.
                        Text(LocalizedStringKey(metric.unitKey))
                            .font(WTheme.sansBold(8.5))
                            .tracking(0.2)
                            .foregroundStyle(WTheme.text3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 6) {
                Button(action: { workout.togglePause() }) {
                    Image(systemName: workout.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(WTheme.card, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workout.state == .paused ? "Reprendre" : "Mettre en pause")

                Button(action: { workout.end() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(WTheme.rose, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Terminer la course")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WTheme.bg)
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
                Text("✓ Terminé")
                    .font(WTheme.sansBold(10.5))
                    .tracking(0.2)
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
                        Text(verbatim: "km")
                            .font(WTheme.sansBold(9.5))
                            .tracking(0.2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 108, height: 108)
                .padding(.vertical, 2)

                HStack(spacing: 14) {
                    metric(value: workout.elapsedLabel, unit: "Temps")
                    metric(value: workout.paceLabel, unit: "/km", accent: WTheme.rose)
                    metric(value: workout.avgHeartRate.map(String.init) ?? "--", unit: "bpm moy", accent: WTheme.violet)
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
            Text(LocalizedStringKey(unit))
                .font(WTheme.sansBold(7.5))
                .tracking(0.2)
                .foregroundStyle(WTheme.text3)
        }
    }
}
