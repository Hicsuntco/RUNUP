import WidgetKit
import SwiftUI

struct DailyGoalsEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyGoalsSnapshot
}

struct DailyGoalsProvider: TimelineProvider {
    /// Shown in the widget gallery preview and before the app has ever published a real snapshot —
    /// "rose" matches `AccentTheme.defaultID` in the app target.
    private static let placeholderSnapshot = DailyGoalsSnapshot(progress: [1, 0.6, 0.3], streak: 4, accentThemeID: "rose", isLightMode: false)

    func placeholder(in context: Context) -> DailyGoalsEntry {
        DailyGoalsEntry(date: .now, snapshot: Self.placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyGoalsEntry) -> Void) {
        completion(DailyGoalsEntry(date: .now, snapshot: DailyGoalsSnapshot.load() ?? Self.placeholderSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyGoalsEntry>) -> Void) {
        let entry = DailyGoalsEntry(date: .now, snapshot: DailyGoalsSnapshot.load() ?? Self.placeholderSnapshot)
        // The app calls `WidgetCenter.shared.reloadAllTimelines()` itself the moment anything
        // actually changes (`AppState.publishWidgetSnapshot`) — this hourly fallback only covers
        // the rare case that never fires (app force-quit mid-sync, etc.), not the normal path.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

/// Second pass on the visual design — the first version used flat system-rounded text on a flat
/// fill and read as generic/placeholder-ish rather than something belonging to the app's actual
/// brand. This one borrows the same techniques `RunShareCardView` already uses for the same
/// reason (a corner glow instead of a flat fill, a real drop shadow under the ring, the app's own
/// Bebas Neue/DM Sans faces instead of the system font) so the widget reads as unmistakably RunUp,
/// not a generic iOS widget template.
struct DailyGoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailyGoalsSnapshot

    private var isLight: Bool { snapshot.isLightMode }
    private var colors: [Color] { WidgetAccentPalette.ringColors(themeID: snapshot.accentThemeID, isLight: isLight) }
    /// The ring's "rose" swatch — used for the corner glow so the glow tint always matches
    /// whatever accent she actually picked, not a fixed brand color.
    private var glowColor: Color { colors[1] }

    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: isLight ? [Color(hex: 0xFAFAFC), .white] : [Color(hex: 0x17171F), Color(hex: 0x0E0E14)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    private var textPrimary: Color { isLight ? Color(hex: 0x15151C) : .white }
    private var text2: Color { isLight ? .black.opacity(0.5) : .white.opacity(0.5) }
    private var flameColor: Color { snapshot.streak > 0 ? Color(hex: 0xFFB03D) : text2 }
    private var textShadow: Color { .black.opacity(isLight ? 0.1 : 0.35) }

    var body: some View {
        Group {
            switch family {
            case .systemMedium: mediumBody
            default: smallBody
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                bgGradient
                RadialGradient(colors: [glowColor.opacity(isLight ? 0.16 : 0.3), .clear], center: .topLeading, startRadius: 0, endRadius: 130)
            }
        }
    }

    private var smallBody: some View {
        VStack(spacing: 10) {
            ring
            streakLabel(size: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediumBody: some View {
        HStack(spacing: 18) {
            ring
            VStack(alignment: .leading, spacing: 7) {
                Text("RUNUP")
                    .font(.custom("BebasNeue-Regular", size: 12))
                    .tracking(2.5)
                    .foregroundColor(text2)
                Text("TES OBJECTIFS")
                    .font(.custom("DMSans-Bold", size: 10))
                    .tracking(1.2)
                    .foregroundColor(textPrimary)
                streakLabel(size: 17)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var ring: some View {
        WidgetRingView(progress: snapshot.progress, colors: colors, size: 64, isLight: isLight)
            .shadow(color: .black.opacity(isLight ? 0.14 : 0.4), radius: 6, x: 0, y: 3)
    }

    private func streakLabel(size: CGFloat) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").font(.system(size: size * 0.68))
            Text("\(snapshot.streak)").font(.custom("BebasNeue-Regular", size: size))
            if family == .systemMedium {
                Text("JOURS").font(.custom("DMSans-SemiBold", size: size * 0.5)).tracking(0.5)
            }
        }
        .foregroundColor(flameColor)
        .shadow(color: textShadow, radius: 3)
    }
}

struct DailyGoalsWidget: Widget {
    let kind = "DailyGoalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyGoalsProvider()) { entry in
            DailyGoalsWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Objectifs du jour")
        .description("Ta séance, tes calories actives et tes pas, d'un coup d'œil.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
