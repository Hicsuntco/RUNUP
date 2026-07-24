import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen + Dynamic Island UI for an in-progress run (`RunActivityAttributes`, updated live
/// from `LiveRunViewModel`). Same reasoning as `DailyGoalsWidget` for not reusing
/// `RunUp/DesignSystem`: this runs in the widget extension's own process, so it can't read the
/// live `ThemeStore`/accent color anyway — fixed dark + the app's rose brand color, same as
/// `RunShareCardView`'s deliberately-fixed palette for a similar reason (a system surface outside
/// her in-app theme choice).
struct RunActivityWidget: Widget {
    private static let accent = Color(hex: 0xFF0F5B)
    private static let bg = Color(hex: 0x0E0E14)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.2f", locale: Locale(identifier: "fr_FR"), context.state.distanceKm))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("KM").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.5))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.paceLabel).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.white)
                        Text("/KM").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.5))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isPaused ? "pause.circle.fill" : "figure.run")
                        Text(context.attributes.sessionTitle).font(.system(size: 12, weight: .medium, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                        Spacer()
                        Text(formatDuration(context.state.elapsedSeconds))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
            } compactLeading: {
                Image(systemName: "figure.run").foregroundColor(Self.accent)
            } compactTrailing: {
                Text(formatDuration(context.state.elapsedSeconds))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "figure.run").foregroundColor(Self.accent)
            }
            .keylineTint(Self.accent)
        }
    }

    private func lockScreenView(context: ActivityViewContext<RunActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.sessionTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                Text(String(format: "%.2f km", locale: Locale(identifier: "fr_FR"), context.state.distanceKm))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(context.state.paceLabel)/km").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                Text(formatDuration(context.state.elapsedSeconds))
                    .font(.system(size: 13, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .activityBackgroundTint(Self.bg)
        .activitySystemActionForegroundColor(.white)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
