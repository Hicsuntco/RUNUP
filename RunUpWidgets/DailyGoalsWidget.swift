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
        dailyGoalsDone: 2, dailyGoalsTotal: 3, activeCaloriesRemaining: 110, stepsRemaining: 2400,
        weekStrip: [
            WidgetWeekDay(letter: "L", isDone: true, isToday: false),
            WidgetWeekDay(letter: "M", isDone: true, isToday: false),
            WidgetWeekDay(letter: "M", isDone: false, isToday: false),
            WidgetWeekDay(letter: "J", isDone: false, isToday: true),
            WidgetWeekDay(letter: "V", isDone: false, isToday: false),
            WidgetWeekDay(letter: "S", isDone: false, isToday: false),
            WidgetWeekDay(letter: "D", isDone: false, isToday: false)
        ]
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

/// Fourth pass on the visual design — the previous layout buried a 56pt ring under three lines of
/// small text, which read as timid next to Apple Fitness's own widget (whose entire design is
/// "the rings ARE the widget"). This pass makes the ring the hero: it nearly fills the small
/// size and anchors the medium one, with the done-count set inside it in the display face, and
/// the per-goal detail demoted to compact bars beside it. Also fixes a silent font fallback: the
/// old body used "DMSans-Medium", which was never registered in this target's UIAppFonts (only
/// Bold/SemiBold are) — it rendered as plain system font, part of why the widget felt generic.
struct DailyGoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailyGoalsSnapshot
    /// The timeline entry's date — for the footer date label (a widget render is a frozen frame;
    /// `.now` at body-evaluation time is the wrong clock to read).
    var entryDate: Date = .now

    /// "MER. 23 JUIL." — the medium footer's date stamp.
    private static let footerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private var isLight: Bool { snapshot.isLightMode }
    private var colors: [Color] { WidgetAccentPalette.ringColors(themeID: snapshot.accentThemeID, isLight: isLight) }
    /// The ring's "rose" swatch — used for accents and glows so both always match whatever accent
    /// she actually picked, not a fixed brand color.
    private var roseColor: Color { colors[1] }
    private var violetColor: Color { colors[2] }

    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: isLight ? [Color(hex: 0xFAFAFC), .white] : [Color(hex: 0x191922), Color(hex: 0x0E0E14)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    private var textPrimary: Color { isLight ? Color(hex: 0x15151C) : .white }
    private var text2: Color { isLight ? .black.opacity(0.5) : .white.opacity(0.5) }
    private var flameColor: Color { snapshot.streak > 0 ? Color(hex: 0xFFB03D) : text2 }

    /// French-style thousands grouping ("2 400", not "2400") for the steps count.
    private static let groupedNumber: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()

    private func grouped(_ value: Int) -> String {
        Self.groupedNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

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
                // Dual corner glows (rose top-left, violet bottom-right) — the same two-tone
                // atmosphere the app's own hero cards carry, instead of a single washed corner.
                RadialGradient(colors: [roseColor.opacity(isLight ? 0.14 : 0.30), .clear], center: .topLeading, startRadius: 0, endRadius: 150)
                RadialGradient(colors: [violetColor.opacity(isLight ? 0.10 : 0.22), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 150)
                // Ghost arc bleeding off the top-right corner — pure depth, no data. The flat
                // gradient alone read as empty around the content.
                Circle()
                    .stroke((isLight ? Color.black : Color.white).opacity(0.035), lineWidth: 13)
                    .frame(width: 170, height: 170)
                    .offset(x: 105, y: -75)
            }
        }
    }

    /// Small: the ring IS the widget — count inside, streak as a corner badge, nothing else.
    private var smallBody: some View {
        centerCountRing(size: 116, countSize: 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if snapshot.streak > 0 { streakBadge }
            }
    }

    private var mediumBody: some View {
        HStack(spacing: 15) {
            centerCountRing(size: 104, countSize: 32)
            VStack(alignment: .leading, spacing: 8) {
                // Header: eyebrow + streak — anchors the panel the way the app's own cards open
                // with an eyebrow, instead of dropping straight into bars.
                HStack(alignment: .center) {
                    Text("AUJOURD'HUI")
                        .font(.custom("DMSans-Bold", size: 8.5))
                        .tracking(1.8)
                        .foregroundColor(roseColor)
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").font(.system(size: 10))
                        Text("\(snapshot.streak)").font(.custom("BebasNeue-Regular", size: 15))
                    }
                    .foregroundColor(flameColor)
                }
                goalBar(index: 0, label: "SÉANCE", trailing: snapshot.progress[safe: 0] ?? 0 >= 1 ? nil : "À faire")
                goalBar(index: 1, label: "KCAL", trailing: snapshot.activeCaloriesRemaining > 0 ? "-\(grouped(snapshot.activeCaloriesRemaining))" : nil)
                goalBar(index: 2, label: "PAS", trailing: snapshot.stepsRemaining > 0 ? "-\(grouped(snapshot.stepsRemaining))" : nil)
                HStack(spacing: 8) {
                    weekDots
                    Spacer(minLength: 0)
                    Text(Self.footerDateFormatter.string(from: entryDate).uppercased())
                        .font(.custom("DMSans-SemiBold", size: 7))
                        .tracking(0.8)
                        .foregroundColor(text2.opacity(0.7))
                }
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The ring with the "2/3" count set inside it — one glance, one number, same read as the
    /// app's own RingsView hero.
    private func centerCountRing(size: CGFloat, countSize: CGFloat) -> some View {
        ZStack {
            WidgetRingView(progress: snapshot.progress, colors: colors, size: size, isLight: isLight)
                .shadow(color: .black.opacity(isLight ? 0.14 : 0.4), radius: size / 10.5, x: 0, y: size / 21)
            VStack(spacing: -2) {
                Text("\(snapshot.dailyGoalsDone)/\(snapshot.dailyGoalsTotal)")
                    .font(.custom("BebasNeue-Regular", size: countSize))
                    .foregroundColor(textPrimary)
                Text("BOUCLÉS")
                    .font(.custom("DMSans-Bold", size: 6.5))
                    .tracking(1.2)
                    .foregroundColor(text2)
            }
        }
    }

    /// One compact goal row: label, a gradient-filled bar in the goal's own ring color (same
    /// darkened→full sweep as the ring's own segments), and what's left — or a checkmark — on the
    /// trailing edge in the display face. `trailing: nil` means the goal is done.
    private func goalBar(index: Int, label: String, trailing: String?) -> some View {
        let pct = max(0, min(1, snapshot.progress[safe: index] ?? 0))
        let color = colors[safe: index] ?? roseColor
        return HStack(spacing: 8) {
            Text(label)
                .font(.custom("DMSans-Bold", size: 8))
                .tracking(0.8)
                .foregroundColor(text2)
                .frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(isLight ? 0.22 : 0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [color.darkened(0.28), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 5.5)
            Group {
                if let trailing {
                    Text(trailing)
                        .font(trailing == "À faire" ? .custom("DMSans-Bold", size: 8) : .custom("BebasNeue-Regular", size: 12))
                        .foregroundColor(trailing == "À faire" ? text2 : textPrimary.opacity(0.92))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .frame(minWidth: 37, alignment: .trailing)
        }
    }

    /// The week at a glance, compressed to 7 dots (done = filled rose, today = an open rose ring,
    /// rest = faint) — the previous lettered 15pt-circle row ate a third of the widget for
    /// information that only needs a hint.
    private var weekDots: some View {
        HStack(spacing: 4.5) {
            ForEach(Array(snapshot.weekStrip.enumerated()), id: \.offset) { _, day in
                if day.isToday && !day.isDone {
                    Circle().stroke(roseColor, lineWidth: 1.2).frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(day.isDone ? roseColor : text2.opacity(0.25))
                        .frame(width: 5.5, height: 5.5)
                }
            }
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill").font(.system(size: 8))
            Text("\(snapshot.streak)").font(.custom("BebasNeue-Regular", size: 12))
        }
        .foregroundColor(flameColor)
        .padding(.horizontal, 6.5)
        .padding(.vertical, 3)
        .background(flameColor.opacity(isLight ? 0.12 : 0.16), in: Capsule())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct DailyGoalsWidget: Widget {
    let kind = "DailyGoalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyGoalsProvider()) { entry in
            DailyGoalsWidgetView(snapshot: entry.snapshot, entryDate: entry.date)
        }
        .configurationDisplayName("Objectifs du jour")
        .description("Ta séance, tes calories actives et tes pas, d'un coup d'œil.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
