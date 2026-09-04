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

/// L'anneau de l'accueil, posé sur l'écran d'accueil.
///
/// La passe précédente avait retiré l'anneau au profit d'un chiffre plat, au motif qu'un widget
/// doit se lire comme un tableau d'affichage et non comme une carte de l'app. Le résultat s'est
/// avéré terne à l'usage : hors du chiffre coloré, tout était gris sur noir, l'œil n'avait qu'un
/// seul point d'accroche, et la version moyenne répétait quatre fois la même cellule.
///
/// Le pari est inverse ici — le widget est un morceau de l'app posé sur le téléphone. Il dessine
/// donc L'ANNEAU DE L'ACCUEIL, pas une imitation : `RingSegmentGeometry` est le fichier partagé
/// que `DailyGoalsBarsView` utilise déjà, écrit exactement pour ça (son en-tête annonce un
/// `WidgetRingView` qui avait disparu, et que voici de retour). Découpe, écart entre arcs, sens de
/// rotation et plage du dégradé viennent tous de là : ils ne peuvent plus diverger.
struct WidgetRingView: View {
    /// Le rang d'origine dans [Séance, Calories, Pas] et l'avancement. Le rang voyage avec
    /// l'objectif plutôt que d'être sa position : un jour de repos n'a que deux objectifs, et sans
    /// lui « calories » hériterait de la couleur de la séance.
    struct Goal { var slot: Int; var progress: Double }

    var goals: [Goal]
    var size: CGFloat
    var colors: [Color]
    var isLight: Bool

    private static let canvas: CGFloat = 100
    /// Plus épais que les 15 % de l'app, et c'est voulu : l'anneau est ici dessiné à 64-96 points
    /// au lieu de 96-180. Le même POURCENTAGE donnerait un trait visuellement plus grêle, la
    /// surface du disque croissant au carré du rayon là où le trait ne croît que linéairement.
    private static let stroke: CGFloat = 17
    private static let lightTrack = 0.26
    private static let darkTrack = 0.22

    var body: some View {
        ZStack {
            ForEach(Array(goals.enumerated()), id: \.offset) { i, goal in
                let color = colors[min(max(0, goal.slot), colors.count - 1)]
                let seg = RingSegmentGeometry.segment(at: i, count: goals.count)
                let pct = max(0, min(1, goal.progress))
                let fillEnd = seg.trimStart + (seg.trimEnd - seg.trimStart) * pct

                // La piste porte une teinte sombre de SA couleur, pas un gris neutre : même vide,
                // l'arc dit à quel objectif il appartient.
                Circle()
                    .trim(from: seg.trimStart, to: seg.trimEnd)
                    .stroke(color.opacity(isLight ? Self.lightTrack : Self.darkTrack),
                            style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round))

                // Le dégradé balaie tout l'arc, pas seulement sa part remplie : se remplir en
                // révèle davantage, d'où le « ça s'éclaire en se terminant » des anneaux d'Apple.
                Circle()
                    .trim(from: seg.trimStart, to: fillEnd)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color, color.vivid(0.22)]),
                            center: .center,
                            startAngle: .degrees(seg.gradientStartDegrees),
                            endAngle: .degrees(seg.gradientEndDegrees)
                        ),
                        style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round)
                    )
            }
        }
        // Le `trim` d'un cercle démarre à 3 heures : on tourne pour que le premier arc parte de midi.
        .rotationEffect(.degrees(-90))
        .frame(width: Self.canvas, height: Self.canvas)
        .scaleEffect(size / Self.canvas)
        .frame(width: size, height: size)
        // La légende à côté énonce les trois mêmes valeurs en toutes lettres : annoncer l'anneau
        // ferait entendre deux fois la même chose à qui l'écoute.
        .accessibilityHidden(true)
    }
}

struct DailyGoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailyGoalsSnapshot
    /// La date de l'entrée : un rendu de widget est une image figée, `.now` au moment où le corps
    /// s'évalue n'est pas la bonne horloge.
    var entryDate: Date = .now

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()

    /// Groupement des milliers selon la locale : « 2 400 » en français, « 2,400 » en anglais.
    ///
    /// Était figé sur `fr_FR` — le même défaut que la montre avait déjà corrigé de son côté, et
    /// qui était resté ici. Une anglophone lisait « 2 400 » sur son écran d'accueil.
    private static let groupedNumber: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        return f
    }()

    private func grouped(_ value: Int) -> String {
        Self.groupedNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var isLight: Bool { snapshot.isLightMode }
    /// [rose2, rose, violet] — l'accent qu'elle a réellement choisi dans l'app, jamais une couleur
    /// fixe, et dans l'ordre où `DailyGoalsBarsView.fillColors` les rend en interne.
    private var colors: [Color] { WidgetAccentPalette.ringColors(themeID: snapshot.accentThemeID, isLight: isLight) }
    private var bg: Color { isLight ? .white : .black }
    private var textPrimary: Color { isLight ? Color(hex: 0x15151C) : .white }
    private var text2: Color { isLight ? .black.opacity(0.45) : .white.opacity(0.42) }
    private var flameColor: Color { snapshot.streak > 0 ? Color(hex: 0xFFB03D) : text2 }

    /// Les objectifs réellement en jeu : deux un jour de repos, trois sinon. L'anneau se partage
    /// alors en deux arcs plutôt que d'en dessiner un troisième qui ne pourra jamais se remplir.
    private var goals: [WidgetRingView.Goal] {
        let p = snapshot.progress
        let all = (0..<3).map { WidgetRingView.Goal(slot: $0, progress: p[safe: $0] ?? 0) }
        return snapshot.isRestDay ? Array(all.dropFirst()) : all
    }

    private var sessionValue: String {
        if snapshot.isRestDay { return String(localized: "Repos") }
        return (snapshot.progress[safe: 0] ?? 0) >= 1 ? "✓" : String(localized: "À faire")
    }
    private var caloriesValue: String {
        snapshot.activeCaloriesRemaining > 0 ? "-\(grouped(snapshot.activeCaloriesRemaining))" : "✓"
    }
    private var stepsValue: String {
        snapshot.stepsRemaining > 0 ? "-\(grouped(snapshot.stepsRemaining))" : "✓"
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

    /// Petit : l'anneau, et un seul chiffre sous lui.
    ///
    /// La légende à trois lignes a été essayée et coupée à l'écran : 158 points de large, moins
    /// les marges, moins l'anneau, il restait cinquante-huit points pour trois valeurs et leurs
    /// libellés. Le rendu a fait ce qu'il devait : couper chaque ligne à une ou deux lettres. Une
    /// maquette HTML ne subit pas cette contrainte de largeur, d'où l'erreur.
    ///
    /// Le petit widget n'a donc qu'un travail : dire d'un coup d'œil où on en est. C'est
    /// exactement ce que l'anneau dit, et le détail attend le moyen, qui a la largeur pour lui.
    private var smallBody: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            WidgetRingView(goals: goals, size: 74, colors: colors, isLight: isLight)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(snapshot.dailyGoalsDone)/\(snapshot.dailyGoalsTotal)")
                    .font(.custom("\(DisplayFont.family)-Bold", size: 17))
                    .foregroundColor(textPrimary)
                Text("bouclés")
                    .font(.custom("\(DisplayFont.family)-SemiBold", size: 10.5))
                    .foregroundColor(text2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if snapshot.streak > 0 { streakBadge.padding(9) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(snapshot.dailyGoalsDone) sur \(snapshot.dailyGoalsTotal) objectifs bouclés"))
    }

    /// Moyen : l'anneau, et la légende qui occupe VRAIMENT la largeur.
    ///
    /// La colonne de droite ne s'étirait pas — elle prenait la place de son contenu et laissait un
    /// tiers de la carte vide. Et chaque ligne se lisait à l'envers, « À faire Séance » au lieu de
    /// « Séance … à faire » : la valeur venait avant son libellé, ce qui marche sous un chiffre
    /// centré et pas dans une phrase.
    private var mediumBody: some View {
        HStack(spacing: 14) {
            WidgetRingView(goals: goals, size: 92, colors: colors, isLight: isLight)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(Self.weekdayFormatter.string(from: entryDate).capitalized)
                        .font(.custom("\(DisplayFont.family)-Bold", size: 15))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    if snapshot.streak > 0 { streakBadge }
                }
                legendRow(slot: 0, value: sessionValue, label: "Séance", muted: snapshot.isRestDay)
                legendRow(slot: 1, value: caloriesValue, label: "kcal")
                legendRow(slot: 2, value: stepsValue, label: "Pas")
                Spacer(minLength: 0)
                weekDots
            }
            // C'est CE modificateur qui manquait : sans lui la colonne se contente de la largeur
            // de son texte, et la carte reste vide sur sa droite.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Une ligne de légende : la pastille de l'arc, son libellé, et la valeur poussée à droite.
    ///
    /// Le libellé AVANT la valeur, et la valeur alignée au bord droit. L'ordre inverse donnait
    /// « À faire Séance » ; celui-ci se lit comme une ligne de tableau, et l'alignement à droite
    /// met les trois valeurs sur une même colonne — c'est ce qui les rend comparables d'un coup
    /// d'œil au lieu de flotter chacune après un mot de longueur différente.
    private func legendRow(slot: Int, value: String, label: String, muted: Bool = false) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(colors[min(max(0, slot), colors.count - 1)].opacity(muted ? 0.35 : 1))
                .frame(width: 7, height: 7)
            Text(LocalizedStringKey(label))
                .font(.custom("\(DisplayFont.family)-SemiBold", size: 11))
                .foregroundColor(text2)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(value)
                .font(.custom("\(DisplayFont.family)-Bold", size: 13))
                .foregroundColor(muted ? text2 : textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private var weekDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(snapshot.weekStrip.enumerated()), id: \.offset) { _, day in
                if day.isToday && !day.isDone {
                    Circle().stroke(colors[1], lineWidth: 1.3).frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(day.isDone ? colors[1] : text2.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill").font(.system(size: 9))
            Text("\(snapshot.streak)").font(.custom("\(DisplayFont.family)-Bold", size: 11))
        }
        .foregroundColor(flameColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
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
