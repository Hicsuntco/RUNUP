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
        // `.empty`, not the demo placeholder — outside the gallery, fabricated "2/3 bouclés"
        // numbers on a fresh install would be the exact fake-data the app refuses everywhere else.
        completion(DailyGoalsEntry(date: .now, snapshot: DailyGoalsSnapshot.load() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyGoalsEntry>) -> Void) {
        let snapshot = DailyGoalsSnapshot.load() ?? .empty
        let entry = DailyGoalsEntry(date: .now, snapshot: snapshot)
        // The app calls `WidgetCenter.shared.reloadAllTimelines()` itself the moment anything
        // actually changes (`AppState.publishWidgetSnapshot`) — this hourly fallback only covers
        // the rare case that never fires (app force-quit mid-sync, etc.), not the normal path.
        var entries = [entry]
        // A second entry at midnight flips the footer date/"today" dot on time — WidgetKit defers
        // budgeted `.after` reloads overnight, so without it the widget showed yesterday's date
        // well into the morning.
        if let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) {
            entries.append(DailyGoalsEntry(date: midnight, snapshot: snapshot))
        }
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}

/// Fifth pass on the visual design. The previous (fourth) pass made a ring the hero — refined, but
/// still a soft gradient card with corner glows, closer to the app's own energetic in-app cards
/// than the flat, high-contrast "scoreboard" look she wants for the Home Screen specifically (real
/// references: solid black tiles, oversized flat numbers, tiny tracked-caps labels, zero
/// gradients/glow anywhere). This pass drops the ring, the gradient background, and both radial
/// glows in favor of a flat fill and huge Bebas Neue numerals — same real data as before
/// (`DailyGoalsSnapshot`), just presented the way the reference does.
struct DailyGoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailyGoalsSnapshot
    /// The timeline entry's date — for the footer date label (a widget render is a frozen frame;
    /// `.now` at body-evaluation time is the wrong clock to read).
    var entryDate: Date = .now

    /// "MER. 23 JUIL." — the medium footer's date stamp.
    private static let footerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        // Le GABARIT, pas un format figé : « EEE d MMM » rend « mer. 3 sept. » en français et
        // « Wed 3 Sep » en anglais, mais l'ordre des éléments diffère selon les langues, et un
        // format écrit en dur impose l'ordre français à tout le monde.
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return f
    }()

    private var isLight: Bool { snapshot.isLightMode }
    /// [rose2, rose, violet] — whichever accent she actually picked in-app, never a fixed color,
    /// so the widget always matches. `rose` (index 1) is the one flat hero color this design
    /// spends everywhere else stays neutral white/gray.
    private var colors: [Color] { WidgetAccentPalette.ringColors(themeID: snapshot.accentThemeID, isLight: isLight) }
    private var roseColor: Color { colors[1] }

    /// Flat, not a gradient — the whole point of this pass. Pure white in light mode, pure black
    /// in dark, same "no gradient anywhere" rule the in-app light-mode pass applies too.
    private var bg: Color { isLight ? .white : .black }
    private var textPrimary: Color { isLight ? Color(hex: 0x15151C) : .white }
    private var text2: Color { isLight ? .black.opacity(0.45) : .white.opacity(0.4) }
    private var flameColor: Color { snapshot.streak > 0 ? Color(hex: 0xFFB03D) : text2 }

    /// Groupement des milliers selon la locale : « 2 400 » en français, « 2,400 » en anglais.
    ///
    /// Était figé sur `fr_FR`, comme la date au-dessus — le même défaut que la montre avait déjà
    /// corrigé de son côté, et qui était resté ici. Une anglophone lisait « 2 400 » et
    /// « mer. 3 sept. » sur son écran d'accueil.
    private static let groupedNumber: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
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
        .containerBackground(for: .widget) { bg }
    }

    /// Small: one huge flat number ("2/3 BOUCLÉS"), two compact sub-stats below, streak as a
    /// corner badge — no ring, no card chrome, just numbers on flat black/white.
    private var smallBody: some View {
        VStack(spacing: 3) {
            Spacer(minLength: 0)
            Text("\(snapshot.dailyGoalsDone)/\(snapshot.dailyGoalsTotal)")
                .font(DisplayFont.font(46))
                .foregroundColor(roseColor)
            Text("bouclés")
                .font(.custom("\(DisplayFont.family)-Bold", size: 11))
                .tracking(0.2)
                .foregroundColor(text2)
            Spacer(minLength: 0)
            HStack {
                subStat(label: "Pas", value: snapshot.stepsRemaining > 0 ? "-\(grouped(snapshot.stepsRemaining))" : "✓")
                Spacer()
                subStat(label: "kcal", value: snapshot.activeCaloriesRemaining > 0 ? "-\(grouped(snapshot.activeCaloriesRemaining))" : "✓", trailing: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if snapshot.streak > 0 { streakBadge }
        }
    }

    private func subStat(label: String, value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            Text(value).font(.custom("\(DisplayFont.family)-Bold", size: 15)).foregroundColor(textPrimary)
            Text(LocalizedStringKey(label)).font(.custom("\(DisplayFont.family)-Bold", size: 9.5)).tracking(0.2).foregroundColor(text2)
        }
    }

    /// Medium: the same flat hero number leads, a 2x2 grid of real stats underneath (séance/kcal/
    /// pas/série — everything `DailyGoalsSnapshot` actually carries, nothing invented), week dots
    /// and the date along the bottom.
    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(snapshot.dailyGoalsDone)/\(snapshot.dailyGoalsTotal)")
                    .font(DisplayFont.font(32))
                    .foregroundColor(roseColor)
                Text("bouclés")
                    .font(.custom("\(DisplayFont.family)-Bold", size: 10))
                    .tracking(0.2)
                    .foregroundColor(text2)
                Spacer(minLength: 0)
                Text(Self.footerDateFormatter.string(from: entryDate))
                    .font(.custom("\(DisplayFont.family)-SemiBold", size: 9))
                    .tracking(0.2)
                    .foregroundColor(text2)
            }
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                // `String(localized:)` et pas la chaîne brute : `gridCell` affiche sa valeur avec
                // `Text(String)`, qui ne traduit rien. Ces deux mots-là restaient donc en français
                // pour tout le monde, juste au-dessus d'un libellé qui, lui, se traduisait.
                gridCell(
                    value: snapshot.isRestDay
                        ? String(localized: "Repos")
                        : ((snapshot.progress[safe: 0] ?? 0) >= 1 ? "✓" : String(localized: "À faire")),
                    label: "Séance"
                )
                gridCell(value: "\(snapshot.streak)", label: "Série", valueColor: flameColor)
                gridCell(value: snapshot.activeCaloriesRemaining > 0 ? "-\(grouped(snapshot.activeCaloriesRemaining))" : "✓", label: "kcal")
                gridCell(value: snapshot.stepsRemaining > 0 ? "-\(grouped(snapshot.stepsRemaining))" : "✓", label: "Pas")
            }
            Spacer(minLength: 0)
            weekDots
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func gridCell(value: String, label: String, valueColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.custom("\(DisplayFont.family)-Bold", size: 15)).foregroundColor(valueColor ?? textPrimary)
            Text(LocalizedStringKey(label)).font(.custom("\(DisplayFont.family)-Bold", size: 9)).tracking(0.2).foregroundColor(text2)
        }
    }

    /// The week at a glance, compressed to 7 dots (done = filled rose, today = an open rose ring,
    /// rest = faint) — a hint, not a full lettered row.
    private var weekDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(snapshot.weekStrip.enumerated()), id: \.offset) { _, day in
                if day.isToday && !day.isDone {
                    Circle().stroke(roseColor, lineWidth: 1.3).frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(day.isDone ? roseColor : text2.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill").font(.system(size: 9.5))
            Text("\(snapshot.streak)").font(DisplayFont.font(14))
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
