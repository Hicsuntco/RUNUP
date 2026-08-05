import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen + Dynamic Island UI for an in-progress run (`RunActivityAttributes`, updated live
/// from `LiveRunViewModel`). Same reasoning as `DailyGoalsWidget` for not reusing
/// `RunUp/DesignSystem`: this runs in the widget extension's own process, so it can't read the
/// live `ThemeStore`/accent color anyway — fixed dark + the app's rose brand color, same as
/// `RunShareCardView`'s deliberately-fixed palette for a similar reason (a system surface outside
/// her in-app theme choice).
///
/// Lock Screen redone flat and high-contrast to match `DailyGoalsWidget`'s pass: true black, no
/// gradient, the real brand fonts instead of the system rounded design, and a progress bar toward
/// the session's *planned duration* — the one real "how far in am I" number a `WorkoutSession`
/// actually tracks (there's no distance target to show honestly; sessions are duration-based).
struct RunActivityWidget: Widget {
    private static let accent = Color(hex: 0xFF0F5B)
    private static let bg = Color.black

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.2f", locale: Locale(identifier: "fr_FR"), context.state.distanceKm))
                            .font(.custom("BebasNeue-Regular", size: 24))
                            .foregroundColor(.white)
                        Text("KM").font(.custom("DMSans-Bold", size: 9)).tracking(1).foregroundColor(.white.opacity(0.5))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.paceLabel).font(.custom("BebasNeue-Regular", size: 18)).foregroundColor(.white)
                        Text("/KM").font(.custom("DMSans-Bold", size: 9)).tracking(1).foregroundColor(.white.opacity(0.5))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon(context.state))
                        Text(context.attributes.sessionTitle).font(.custom("DMSans-SemiBold", size: 12)).lineLimit(1).minimumScaleFactor(0.7)
                        Spacer()
                        elapsedText(context.state)
                            .font(.custom("DMSans-Bold", size: 13))
                            .monospacedDigit()
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
            } compactLeading: {
                Image(systemName: "figure.run").foregroundColor(Self.accent)
            } compactTrailing: {
                elapsedText(context.state)
                    .font(.custom("DMSans-Bold", size: 13))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "figure.run").foregroundColor(Self.accent)
            }
            .keylineTint(Self.accent)
        }
    }

    private func lockScreenView(context: ActivityViewContext<RunActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("RUN")
                    .font(.custom("BebasNeue-Regular", size: 17))
                    .tracking(1)
                    .foregroundColor(Self.accent)
                Spacer()
                HStack(spacing: 6) {
                    Text(context.attributes.sessionTitle)
                        .font(.custom("DMSans-SemiBold", size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                    statusBadge(context.state)
                }
            }

            HStack {
                metric(value: String(format: "%.2f", locale: Locale(identifier: "fr_FR"), context.state.distanceKm), label: "KM")
                Spacer(minLength: 8)
                metric(value: context.state.paceLabel, label: "ALLURE")
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    elapsedText(context.state)
                        .font(.custom("BebasNeue-Regular", size: 26))
                        .foregroundColor(.white)
                    Text("TEMPS").font(.custom("DMSans-Bold", size: 8.5)).tracking(1).foregroundColor(.white.opacity(0.4))
                }
            }

            if context.attributes.plannedDurationMinutes > 0 {
                let plannedSeconds = Double(context.attributes.plannedDurationMinutes * 60)
                let fraction = max(0, min(1, context.state.elapsedSeconds / plannedSeconds))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("SÉANCE").font(.custom("DMSans-Bold", size: 8.5)).tracking(1).foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("\(context.attributes.plannedDurationMinutes) MIN PRÉVUES").font(.custom("DMSans-Bold", size: 8.5)).tracking(0.6).foregroundColor(.white.opacity(0.4))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Self.accent).frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(Self.bg)
        .activitySystemActionForegroundColor(.white)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.custom("BebasNeue-Regular", size: 26))
                .foregroundColor(.white)
            Text(label).font(.custom("DMSans-Bold", size: 8.5)).tracking(1).foregroundColor(.white.opacity(0.4))
        }
    }

    private func statusBadge(_ state: RunActivityAttributes.ContentState) -> some View {
        Image(systemName: statusIcon(state))
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(state.isPaused ? .white.opacity(0.5) : Self.accent)
    }

    private func statusIcon(_ state: RunActivityAttributes.ContentState) -> String {
        if state.isEnded { return "checkmark.circle.fill" }
        return state.isPaused ? "pause.circle.fill" : "figure.run"
    }

    /// Self-ticking chrono while running (`Text(timerInterval:)` updates every second with zero
    /// pushes from the app — the state only carries the reference date); frozen static label when
    /// paused/ended, which is exactly when the clock shouldn't move.
    @ViewBuilder
    private func elapsedText(_ state: RunActivityAttributes.ContentState) -> some View {
        if let reference = state.timerReference, !state.isPaused, !state.isEnded {
            Text(timerInterval: reference...Date.distantFuture, countsDown: false)
        } else {
            Text(formatDuration(state.elapsedSeconds))
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
