import WidgetKit
import SwiftUI

struct DailyGoalsEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyGoalsSnapshot
}

struct DailyGoalsProvider: TimelineProvider {
    /// Shown in the widget gallery preview and before the app has ever published a real snapshot —
    /// "rose" matches `AccentTheme.defaultID` in the app target.
    private static let placeholderSnapshot = DailyGoalsSnapshot(
        progress: [1, 0.6, 0.3], streak: 4, accentThemeID: "rose", isLightMode: false,
        dailyGoalsDone: 2, dailyGoalsTotal: 3, activeCaloriesRemaining: 110, stepsRemaining: 2400
    )

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

/// Third pass on the visual design, this time modeled directly on the "INTÉGRÉ · widget sur
/// l'accueil" concept card from the RUNUP 4.0 mockup exploration: a colored eyebrow above the
/// ring, a plain-language sentence naming exactly what's left today (not just an abstract
/// percentage), and the streak below — more than just the ring, on the medium size where there's
/// actually room for it. Same corner-glow/drop-shadow/brand-font techniques as the previous pass
/// (`RunShareCardView` uses the same ones for the same "read as unmistakably RunUp" reason).
struct DailyGoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailyGoalsSnapshot

    private var isLight: Bool { snapshot.isLightMode }
    private var colors: [Color] { WidgetAccentPalette.ringColors(themeID: snapshot.accentThemeID, isLight: isLight) }
    /// The ring's "rose" swatch — used for the eyebrow and corner glow so both always match
    /// whatever accent she actually picked, not a fixed brand color.
    private var roseColor: Color { colors[1] }
    private var violetColor: Color { colors[2] }

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
                RadialGradient(colors: [roseColor.opacity(isLight ? 0.16 : 0.3), .clear], center: .topLeading, startRadius: 0, endRadius: 130)
            }
        }
    }

    private var smallBody: some View {
        VStack(spacing: 10) {
            ring
            streakLabel(size: 15, showSuffix: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediumBody: some View {
        HStack(alignment: .center, spacing: 18) {
            ring
            VStack(alignment: .leading, spacing: 6) {
                Text("OBJECTIFS DU JOUR · \(snapshot.dailyGoalsDone)/\(snapshot.dailyGoalsTotal)")
                    .font(.custom("DMSans-Bold", size: 9.5))
                    .tracking(1.1)
                    .foregroundColor(roseColor)
                remainingText
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundColor(textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                streakLabel(size: 16, showSuffix: true)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// "Encore 110 kcal actives et 2400 pas." with the two real numbers picked out in the ring's
    /// own colors — same "name what's actually left" idea as the mockup's "Il te reste 2,8 km et
    /// 18 min actives.", with our real 3 goals instead of that concept's distance/time framing.
    private var remainingText: Text {
        guard snapshot.activeCaloriesRemaining > 0 || snapshot.stepsRemaining > 0 else {
            return Text("Objectifs du jour atteints 🎉")
        }
        var parts: [Text] = []
        if snapshot.activeCaloriesRemaining > 0 {
            parts.append(Text("\(snapshot.activeCaloriesRemaining) kcal actives").foregroundColor(roseColor).fontWeight(.bold))
        }
        if snapshot.stepsRemaining > 0 {
            parts.append(Text("\(snapshot.stepsRemaining) pas").foregroundColor(violetColor).fontWeight(.bold))
        }
        let joined = parts.count == 2 ? parts[0] + Text(" et ") + parts[1] : parts[0]
        return Text("Encore ") + joined + Text(".")
    }

    private var ring: some View {
        WidgetRingView(progress: snapshot.progress, colors: colors, size: 64, isLight: isLight)
            .shadow(color: .black.opacity(isLight ? 0.14 : 0.4), radius: 6, x: 0, y: 3)
    }

    private func streakLabel(size: CGFloat, showSuffix: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").font(.system(size: size * 0.68))
            Text("\(snapshot.streak)").font(.custom("BebasNeue-Regular", size: size))
            if showSuffix {
                Text("JOURS DE SÉRIE").font(.custom("DMSans-SemiBold", size: size * 0.42)).tracking(0.4)
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
