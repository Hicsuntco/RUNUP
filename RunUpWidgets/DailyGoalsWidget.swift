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

struct DailyGoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailyGoalsSnapshot

    private var colors: [Color] { WidgetAccentPalette.ringColors(themeID: snapshot.accentThemeID, isLight: snapshot.isLightMode) }
    private var bg: Color { snapshot.isLightMode ? .white : Color(hex: 0x0E0E14) }
    private var textPrimary: Color { snapshot.isLightMode ? Color(hex: 0x15151C) : .white }
    private var text2: Color { snapshot.isLightMode ? .black.opacity(0.55) : .white.opacity(0.5) }
    private var flameColor: Color { snapshot.streak > 0 ? Color(hex: 0xFFB03D) : text2 }

    var body: some View {
        switch family {
        case .systemMedium: mediumBody
        default: smallBody
        }
    }

    private var smallBody: some View {
        VStack(spacing: 8) {
            WidgetRingView(progress: snapshot.progress, colors: colors, size: 64, isLight: snapshot.isLightMode)
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.system(size: 11))
                Text("\(snapshot.streak)").font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(flameColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(bg, for: .widget)
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            WidgetRingView(progress: snapshot.progress, colors: colors, size: 64, isLight: snapshot.isLightMode)
            VStack(alignment: .leading, spacing: 6) {
                Text("TES OBJECTIFS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundColor(text2)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 12))
                    Text("\(snapshot.streak) jours de série").font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(flameColor)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(bg, for: .widget)
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
