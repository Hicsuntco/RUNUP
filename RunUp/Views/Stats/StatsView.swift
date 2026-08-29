import SwiftUI
import SwiftData

/// Progression analytics — real computations from `RunRecord` history and the same `PaceModel`
/// that seeds the training plan, replacing what used to be entirely fabricated numbers (a fixed
/// "VO2max 52.4" that never moved, 3 fixed race predictions, a fake training-load curve) with no
/// connection whatsoever to any real run.
struct StatsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]
    @State private var chartRevealed = false
    /// Records/prédiction/charge start collapsed — 6 dense analytical cards stacked at once read
    /// as a wall nobody actually reads. The 3 that answer "où j'en suis là" (totaux, cette
    /// semaine, allure récente) stay always visible; the deeper analysis is a tap away instead of
    /// scroll-past-and-ignore.
    @State private var showDeepAnalysis = false
    @State private var selectedRange: StatsRange = .month
    private var profile: UserProfile { appState.profile }

    /// Windows for the pace-trend chart — was hardcoded to "last 8 runs" regardless of how far
    /// back that actually reached (could be 2 weeks or 6 months depending how often she runs).
    private enum StatsRange: String, CaseIterable, Identifiable {
        case week = "7J", month = "4S", quarter = "3M", year = "1A"
        var id: Self { self }
        /// Le libellé long, pour la phrase sous le chiffre. « 4S » se lit dans une pastille
        /// parce que ses trois voisines lui donnent son échelle ; seul dans une phrase, non.
        var caption: String {
            switch self {
            case .week: return String(localized: "7 derniers jours")
            case .month: return String(localized: "4 dernières semaines")
            case .quarter: return String(localized: "3 derniers mois")
            case .year: return String(localized: "12 derniers mois")
            }
        }

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 28
            case .quarter: return 90
            case .year: return 365
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HeaderView(eyebrow: "Analyse · progression", title: runs.isEmpty ? "Ta progression démarre ici" : "Ta forme évolue") {
                    Button(action: { appState.go(.history) }) {
                        HStack(spacing: 5) {
                            Text("Historique").font(RUFont.sans(.small, weight: .semibold))
                            Text("›")
                        }
                        .foregroundColor(RUColor.text2)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }

                // Ordre repris de la maquette "Stats" : les totaux, puis les deux cartes de
                // tendance, puis seulement les deux raccourcis de navigation, réduits à une paire
                // compacte en bas de page. Avant, "Mes routes" — une simple destination —
                // s'intercalait pleine largeur entre les totaux et la semaine, coupant l'écran
                // d'analyse en deux avec un lien.
                if runs.isEmpty { firstDayBanner } else { summaryGrid }
                weekCard
                paceCard

                routesTile
                deepAnalysisToggle
                if showDeepAnalysis {
                    recordsCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    predictionCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    loadCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    // MARK: Summary — at-a-glance totals, the numbers a "progression" tab was otherwise missing
    // entirely (it jumped straight to trend/prediction cards with nothing grounding them).

    private var totalDistanceKm: Double { runs.reduce(0) { $0 + $1.distanceKm } }
    private var totalDurationSeconds: Int { runs.reduce(0) { $0 + $1.durationSeconds } }

    /// La grille des références : quatre tuiles à deux par rangée, chacune avec son en-tête, son
    /// chiffre et son unité — au lieu d'UNE carte pleine largeur découpée en quatre colonnes par
    /// des filets verticaux.
    ///
    /// Ce n'est pas un changement décoratif. À quatre colonnes, chaque chiffre recevait un quart
    /// de la largeur de l'écran : `summaryCell` portait `minimumScaleFactor(0.55)` sur la valeur
    /// et `0.7` sur le libellé, autrement dit le gabarit prévoyait que le contenu ne rentre pas.
    /// Un temps cumulé à trois chiffres (« 128h 40 ») s'affichait à 55 % de sa taille, à côté d'un
    /// « 12 » à taille pleine. À deux par rangée, chaque chiffre a la place d'être lu.
    ///
    /// Mêmes quatre données réelles qu'avant — total, nombre de sorties, temps cumulé, série.
    /// Chacune reçoit sa teinte, prise dans les jetons existants : aucune couleur nouvelle, mais
    /// quatre chiffres qui ne se ressemblent plus.
    /// Le jour 1, la grille affiche quatre zéros sous un titre qui dit « Ta progression démarre
    /// ici ». Les zéros sont exacts, mais quatre tuiles pour dire « rien » occupent le haut de
    /// l'écran avec l'absence de données au lieu de la promesse.
    ///
    /// Les deux cartes du bas ont déjà leur phrase d'attente ; c'est le résumé qui n'en avait pas.
    private var firstDayBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(icon: "chart.line.uptrend.xyaxis", tint: RUColor.rose,
                         title: "Rien à analyser pour l'instant",
                         subtitle: "C'est normal, tu viens de commencer")
            Text("Dès ta première sortie, cet écran affichera ton allure moyenne, ta charge d'entraînement et tes records — calculés sur tes courses, pas sur des moyennes.")
                .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ruHeroCard()
    }

    private var summaryGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RUStatTile(icon: "ruler", tint: RUColor.rose,
                           title: "Distance totale",
                           value: String(format: "%.0f", totalDistanceKm), unit: "km",
                           footnote: nil, progress: nil)
                RUStatTile(icon: "figure.run", tint: RUColor.violet,
                           title: "Sorties",
                           value: "\(runs.count)",
                           unit: runs.count > 1 ? "sorties" : "sortie",
                           footnote: nil, progress: nil)
            }
            HStack(spacing: 10) {
                RUStatTile(icon: "clock", tint: RUColor.cyan,
                           title: "Temps cumulé",
                           value: PaceModel.formatTotalDuration(totalDurationSeconds), unit: nil,
                           footnote: nil, progress: nil)
                RUStatTile(icon: "flame.fill",
                           tint: profile.streak > 0 ? RUColor.lime : RUColor.text3,
                           title: "Série",
                           value: "\(profile.streak)",
                           unit: profile.streak > 1 ? "jours" : "jour",
                           footnote: nil, progress: nil)
            }
        }
    }

    // MARK: Quick links — the two navigation affordances of the screen (heatmap: every GPS route
    // overlaid on one map, a purely personal "where have I already run" view rather than anything
    // competitive; and the deep-analysis disclosure).

    private var routedRunsCount: Int { runs.filter { $0.route.count > 1 }.count }

    /// Les `.stat-quicklinks` de la maquette : les deux seuls éléments de cet écran qui ne sont
    /// pas de l'analyse mais de la navigation (la carte des routes, et le dépliage de l'analyse
    /// approfondie), réunis en une paire de tuiles compactes côte à côte en bas de page. Chacun
    /// occupait avant toute la largeur — deux bandes pleine largeur au milieu d'un écran de
    /// cartes de données, pour ce qui n'est qu'« aller ailleurs » et « en voir plus ».
    /// Deux gestes différents, deux formes différentes.
    ///
    /// C'étaient deux tuiles jumelles, côte à côte, même gabarit, même chrome : seule la
    /// direction du chevron distinguait « ça t'emmène ailleurs » de « ça déplie ici ». Toute la
    /// grammaire de l'écran dit qu'elles font la même chose, et il faut lire le chevron — 10 pt,
    /// gris — pour découvrir que non. La forme doit porter le comportement, sinon il faut
    /// essayer pour savoir.
    ///
    /// « Mes routes » garde donc la tuile qui mène ailleurs. L'analyse approfondie devient ce
    /// qu'elle est : une ligne de dépliage, pleine largeur, juste au-dessus de ce qu'elle
    /// déplie, et qui dit dans son libellé ce que le geste va faire.
    private var routesTile: some View {
        Button(action: { appState.go(.heatmap) }) {
            HStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(RUColor.rose)
                    .frame(width: 34, height: 34)
                    .background(RUColor.rose.opacity(0.12), in: RoundedRectangle(cornerRadius: RUSpacing.radiusTile, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mes routes")
                        .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    Text(routedRunsCount > 0
                         ? String(localized: "\(routedRunsCount) parcours trackés")
                         : String(localized: "Dès ta 1re course trackée"))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(RUColor.text3)
            }
            .padding(12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .ruCard(radius: RUSpacing.radiusCompact)
        .accessibilityElement(children: .combine)
    }

    private var deepAnalysisToggle: some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.25)) { showDeepAnalysis.toggle() }
        }) {
            HStack(spacing: 8) {
                Text(showDeepAnalysis ? "Masquer l'analyse approfondie" : "Voir l'analyse approfondie")
                    .font(RUFont.sans(.body, weight: .semibold)).foregroundColor(RUColor.text2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(RUColor.text3)
                    .rotationEffect(.degrees(showDeepAnalysis ? 180 : 0))
                Spacer(minLength: 0)
                Text("Records, charge, prédiction")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text4)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    // MARK: This week — recency + consistency against the actual plan, missing before this: the
    // rest of the tab only ever looked at trailing windows (5 runs, 8 weeks), nothing anchored to
    // "where am I right now, against what my program actually asks of me this week."

    /// Same Monday-first week `AdaptivePlanEngine`/`WeeklyRecapView` use — this card links straight
    /// into `WeeklyRecapView`, so "this week" needs to mean the same date range in both places
    /// (this used to read `Calendar.current.dateInterval(of: .weekOfYear, ...)`, whose start-of-week
    /// follows the device's region setting — a mismatch with the recap screen on any non-Monday-
    /// first locale).
    private var thisWeekRuns: [RunRecord] {
        let range = AdaptivePlanEngine.currentWeekRange()
        return runs.filter { range.contains($0.date) }
    }

    private var thisWeekKm: Double { thisWeekRuns.reduce(0) { $0 + $1.distanceKm } }

    private var lastWeekKm: Double {
        let thisWeekStart = AdaptivePlanEngine.currentWeekRange().lowerBound
        guard let lastWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: thisWeekStart) else { return 0 }
        return runs.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }.reduce(0) { $0 + $1.distanceKm }
    }

    private var weekCard: some View {
        Button(action: { appState.go(.weeklyRecap) }) {
            VStack(alignment: .leading, spacing: 10) {
                // Même carte que sur l'accueil, littéralement le même composant.
                //
                // Cet écran comptait la semaine en SÉANCES (« 1/4 séances prévues ») là où
                // l'accueil la comptait en KILOMÈTRES (« 5,0/32 km sem. ») : mêmes courses, mêmes
                // dates, deux dénominateurs. Le kilomètre l'emporte parce que c'est celui du plan,
                // qu'il bouge à chaque sortie, et qu'un compteur de séances ne dit rien d'une
                // sortie écourtée. Les séances restent dites, en note sous la barre — une
                // précision, plus un dénominateur concurrent.
                RUCardHeader(icon: "calendar", tint: RUColor.rose,
                             title: "Cette semaine",
                             subtitle: "Face à la semaine passée") {
                    Text("›").font(RUFont.sans(.emphasis, weight: .bold)).foregroundColor(RUColor.text3)
                }
                WeekKmSummary(
                    doneKm: thisWeekKm,
                    plannedKm: profile.plannedWeeklyKm,
                    lastWeekKm: lastWeekKm,
                    footnote: profile.runningDays.isEmpty
                        ? nil
                        : (thisWeekRuns.count > 1
                           ? String(localized: "\(thisWeekRuns.count) séances sur \(profile.runningDays.count) prévues")
                           : String(localized: "\(thisWeekRuns.count) séance sur \(profile.runningDays.count) prévues"))
                )
            }
            .padding(16)
            .ruCard()
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Pace trend — was a fixed "VO2max 52.4" that never actually moved

    /// Runs inside `selectedRange`, oldest first — chart reads left-to-right as time moving
    /// forward, same order the fixed "last 8 runs" version always used.
    private var chartRuns: [RunRecord] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: .now) else { return [] }
        return runs.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    private var recentPacesSecPerKm: [Double] {
        chartRuns.compactMap { PaceModel.parseSecPerKm($0.avgPace) }
    }

    /// Index of the chart point that's her all-time best pace (same ≥1 km floor `bestPaceSecPerKm`
    /// already uses below) — nil when that run isn't inside the currently selected window, so an
    /// old PR from a year ago doesn't get flagged on a "7 jours" chart that never plots it.
    private var recordPointIndex: Int? {
        guard let best = bestPaceSecPerKm else { return nil }
        return recentPacesSecPerKm.firstIndex(where: { abs($0 - best) < 0.01 })
    }

    private var paceTrendAccessibilitySummary: String {
        guard let first = recentPacesSecPerKm.first, let last = recentPacesSecPerKm.last,
              let minPace = recentPacesSecPerKm.min(), let maxPace = recentPacesSecPerKm.max()
        else { return String(localized: "Pas encore assez de courses") }
        let trend: String
        if last < first - 2 { trend = String(localized: "en amélioration") } // fewer seconds/km = faster
        else if last > first + 2 { trend = String(localized: "en baisse") }
        else { trend = String(localized: "stable") }
        return "Allure \(trend), entre \(PaceModel.formatDuration(minPace)) et \(PaceModel.formatDuration(maxPace)) par kilomètre"
    }

    /// L'allure moyenne SUR LA FENÊTRE CHOISIE.
    ///
    /// Elle était figée sur les cinq dernières courses, quelle que soit la position du sélecteur
    /// posé juste au-dessus. Passer de « 7J » à « 1A » redessinait la courbe et laissait le
    /// chiffre héros — celui qu'on lit en premier, à 44 pt — sur les mêmes cinq courses. Un
    /// contrôle qui semble commander la carte n'en commandait que la moitié : c'est le genre de
    /// détail qui apprend à ne plus faire confiance à ce qu'on lit.
    private var recentAvgPace: Double? {
        average(of: recentPacesSecPerKm)
    }

    /// La même moyenne sur la fenêtre PRÉCÉDENTE de même durée : « les 4 semaines d'avant »
    /// quand on regarde 4 semaines. Comparer une fenêtre à un nombre fixe de courses ferait dire
    /// à la flèche n'importe quoi dès qu'on change d'échelle.
    private var previousAvgPace: Double? {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -selectedRange.days, to: .now),
              let previousStart = cal.date(byAdding: .day, value: -selectedRange.days, to: start)
        else { return nil }
        let window = runs.filter { $0.date >= previousStart && $0.date < start }
        return average(of: window.compactMap { PaceModel.parseSecPerKm($0.avgPace) })
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var rangePicker: some View {
        HStack(spacing: 3) {
            ForEach(StatsRange.allCases) { range in
                Button(action: {
                    Haptics.selection()
                    selectedRange = range
                }) {
                    Text(LocalizedStringKey(range.rawValue))
                        .font(RUFont.mono(10, weight: .medium))
                        .foregroundColor(selectedRange == range ? .white : RUColor.text2)
                        // 5 pt de marge verticale sur un texte de 12,5 donnaient des segments de
                        // 23 pt de haut. Le contrôle segmenté d'iOS en fait 32 : c'est le plancher
                        // que ce genre d'objet peut se permettre — les segments sont jointifs, une
                        // frappe imprécise tombe sur le voisin plutôt que dans le vide, ce qui
                        // n'est pas vrai d'une pastille isolée. En dessous, il n'y a plus d'excuse.
                        .padding(.horizontal, 9).padding(.vertical, 9)
                        // Same gradient fill as `SelectableChip` — a flat rose square inside this
                        // pill read flat/dated next to it.
                        .background(
                            selectedRange == range
                                ? AnyShapeStyle(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRange)
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RUColor.card2, in: Capsule())
    }

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            RUCardHeader(icon: "speedometer", tint: RUColor.violet,
                         title: "Allure moyenne",
                         subtitle: "Une sortie par point") {
                rangePicker
            }
            if let recentAvgPace {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(PaceModel.formatDuration(recentAvgPace)).displayStyle(44).foregroundColor(RUColor.textPrimary)
                    Text("/km").font(RUFont.sans(.emphasis)).foregroundColor(RUColor.text2)
                    // Poussé au bord droit (le `margin-left:auto` de la maquette) : collé au
                    // "/km", le delta se lisait comme une deuxième unité accrochée au chiffre
                    // héros ; à l'opposé de la ligne, il se lit comme ce qu'il est — une
                    // comparaison, en vis-à-vis de l'allure qu'elle commente.
                    Spacer(minLength: 8)
                    if let previousAvgPace {
                        let deltaSeconds = previousAvgPace - recentAvgPace // positive = faster now
                        StatChip(
                            text: deltaSeconds >= 0 ? "▲ \(Int(deltaSeconds.rounded()))″/km" : "▼ \(Int(-deltaSeconds.rounded()))″/km",
                            color: deltaSeconds >= 0 ? RUColor.lime : RUColor.amber
                        )
                    }
                }
                Text(chartRuns.count == 1
                     ? String(localized: "1 sortie · \(selectedRange.caption)")
                     : String(localized: "\(chartRuns.count) sorties · \(selectedRange.caption)"))
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)

                if recentPacesSecPerKm.count >= 2 {
                    Canvas { context, size in
                        let points = recentPacesSecPerKm
                        let minPace = points.min() ?? 0
                        let maxPace = points.max() ?? 1
                        let range = max(1, maxPace - minPace)
                        let stepX = size.width / CGFloat(points.count - 1)
                        var line = Path()
                        var fill = Path()
                        fill.move(to: CGPoint(x: 0, y: size.height))
                        var lastPoint = CGPoint.zero
                        var pointPositions: [CGPoint] = []
                        for (i, p) in points.enumerated() {
                            let t = CGFloat((p - minPace) / range) // 0 = fastest ... 1 = slowest
                            let point = CGPoint(x: CGFloat(i) * stepX, y: size.height * (0.15 + 0.7 * t))
                            if i == 0 { line.move(to: point) } else { line.addLine(to: point) }
                            fill.addLine(to: point)
                            lastPoint = point
                            pointPositions.append(point)
                        }
                        fill.addLine(to: CGPoint(x: size.width, y: size.height))
                        fill.closeSubpath()
                        context.fill(fill, with: .linearGradient(Gradient(colors: [RUColor.rose.opacity(0.35), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                        context.stroke(line, with: .color(RUColor.rose), lineWidth: 2.5)
                        context.fill(Path(ellipseIn: CGRect(x: lastPoint.x - 3.5, y: lastPoint.y - 3.5, width: 7, height: 7)), with: .color(RUColor.rose))

                        // Her all-time best pace, marked right on the trend line instead of only
                        // living in a separate "records" card further down — was invisible here
                        // even when the exact point plotted WAS the record.
                        if let recordIndex = recordPointIndex, recordIndex < pointPositions.count {
                            let p = pointPositions[recordIndex]
                            context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(RUColor.lime))
                            context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)).strokedPath(StrokeStyle(lineWidth: 1.5)), with: .color(RUColor.bg))
                            let labelY = max(9, p.y - 14)
                            context.draw(
                                Text("RECORD").font(RUFont.sans(.micro, weight: .bold)).foregroundColor(RUColor.lime),
                                at: CGPoint(x: min(max(p.x, 22), size.width - 22), y: labelY)
                            )
                        }
                    }
                    .frame(height: 70)
                    .padding(.top, 6)
                    // The trend shape itself carries zero VoiceOver content otherwise — the
                    // min/max text below it (when shown) only covers the endpoints, not the
                    // direction of change.
                    .accessibilityLabel("Tendance d'allure")
                    .accessibilityValue(paceTrendAccessibilitySummary)

                    if let minPace = recentPacesSecPerKm.min(), let maxPace = recentPacesSecPerKm.max(), minPace != maxPace {
                        HStack {
                            Text("Plus rapide \(PaceModel.formatDuration(minPace))/km")
                            Spacer()
                            Text("Plus lente \(PaceModel.formatDuration(maxPace))/km")
                        }
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .padding(.top, 4)
                    }
                } else {
                    Text("Pas assez de courses sur cette période — essaie une fenêtre plus large.")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                        .padding(.top, 6)
                }
            } else {
                // Depuis que le chiffre suit la fenêtre choisie, « vide » a deux sens très
                // différents : jamais couru, ou rien couru CETTE période. Dire « termine quelques
                // courses » à quelqu'un qui en a cinquante derrière lui, parce qu'il regarde les
                // 7 derniers jours, c'est le message qui donne tort à l'app.
                Text(runs.isEmpty
                     ? "Termine quelques courses pour voir ton allure évoluer ici."
                     : "Pas assez de courses sur cette période — essaie une fenêtre plus large.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .ruCard()
    }

    // MARK: Personal records — real bests pulled from history, not shown anywhere before this

    private var longestRun: RunRecord? { runs.max(by: { $0.distanceKm < $1.distanceKm }) }

    private var bestPaceSecPerKm: Double? {
        runs.compactMap { run -> Double? in
            guard run.distanceKm >= 1 else { return nil }
            return PaceModel.parseSecPerKm(run.avgPace)
        }.min()
    }

    /// Best single calendar week, across all of history — not just the 8-week window `loadCard`
    /// charts, so an older peak still shows up here.
    private var bestWeekKm: Double {
        // Monday-first weeks via the engine's own range — `Calendar.current` weeks start on the
        // device region's day (Sunday on en-US), which made this disagree with the week card.
        var weekTotals: [Date: Double] = [:]
        for run in runs {
            weekTotals[AdaptivePlanEngine.currentWeekRange(from: run.date).lowerBound, default: 0] += run.distanceKm
        }
        return weekTotals.values.max() ?? 0
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RUCardHeader(icon: "trophy.fill", tint: RUColor.amber,
                         title: "Records personnels",
                         subtitle: "Tes meilleures sorties")
            if runs.isEmpty {
                Text("Tes records apparaîtront ici après ta première course.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
            } else {
                HStack(spacing: 8) {
                    predictionTile("PLUS LONGUE", longestRun.map { String(format: "%.1f km", locale: Locale.current, $0.distanceKm) } ?? "—", highlighted: false)
                    predictionTile("MEILLEURE ALLURE", bestPaceSecPerKm.map { "\(PaceModel.formatDuration($0))/km" } ?? "—", highlighted: false)
                    predictionTile("MEILLEURE SEM.", bestWeekKm > 0 ? String(format: "%.0f km", bestWeekKm) : "—", highlighted: false)
                }
            }
        }
        .padding(16)
        .ruCard()
    }

    // MARK: Race predictions — was 3 fixed fake times regardless of any real performance

    /// The fastest real run of at least 2km, if any — the most credible reference to project
    /// race times from. Falls back to the same threshold-pace anchor already seeding the plan
    /// (target time / best recent perf / level) when there's no run history yet.
    private var bestRecentPerformance: (km: Double, secPerKm: Double)? {
        let candidates = runs.prefix(10).compactMap { run -> (Double, Double)? in
            guard run.distanceKm >= 2, let pace = PaceModel.parseSecPerKm(run.avgPace) else { return nil }
            return (run.distanceKm, pace)
        }
        return candidates.min(by: { $0.1 < $1.1 }).map { (km: $0.0, secPerKm: $0.1) }
    }

    private var predictionReferenceKm: Double { bestRecentPerformance?.km ?? 10 }
    private var predictionReferenceSecPerKm: Double {
        bestRecentPerformance?.secPerKm ?? PaceModel.zones(for: profile).thresholdSecPerKm
    }

    private func predictedSeconds(forKm targetKm: Double) -> Double {
        PaceModel.projectedPace(fromSecPerKm: predictionReferenceSecPerKm, fromKm: predictionReferenceKm, toKm: targetKm) * targetKm
    }

    /// A marathon-training runner never saw a marathon prediction here (the tile set was hardcoded
    /// to 5K/10K/semi) — swaps in MARATHON for 5K once the actual goal distance is long enough
    /// that a 5K prediction stops being the useful end of the set.
    private var predictionDistances: [(String, Double)] {
        if let km = profile.effectiveRaceDistanceKm, km >= 28 {
            return [("10 KM", 10), ("SEMI", 21.0975), ("MARATHON", 42.195)]
        }
        return [("5 KM", 5), ("10 KM", 10), ("SEMI", 21.0975)]
    }

    /// Which tile gets the "highlighted" treatment — used to always be a hardcoded 10K regardless
    /// of her actual goal; now it's whichever rendered distance is closest to it (falls back to
    /// 10K, the middle tile, when there's no specific goal distance to match against).
    private var highlightedPredictionIndex: Int {
        guard let km = profile.effectiveRaceDistanceKm else { return 1 }
        let dists = predictionDistances.map(\.1)
        return dists.indices.min(by: { abs(dists[$0] - km) < abs(dists[$1] - km) }) ?? 1
    }

    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RUCardHeader(icon: "target", tint: RUColor.rose2,
                         title: "Prédiction de course",
                         subtitle: "À partir de ta meilleure perf récente")
            HStack(spacing: 8) {
                ForEach(predictionDistances.indices, id: \.self) { i in
                    predictionTile(predictionDistances[i].0, PaceModel.formatDuration(predictedSeconds(forKm: predictionDistances[i].1)), highlighted: i == highlightedPredictionIndex)
                }
            }
            if bestRecentPerformance == nil {
                Text("Estimation basée sur ton profil — termine une course pour une prédiction plus précise.")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
            } else if profile.goalId == .race,
                      let raceKm = profile.effectiveRaceDistanceKm,
                      let chrono = profile.raceChrono,
                      let targetSeconds = PaceModel.parseChronoSeconds(chrono, distance: profile.raceDistance) {
                let deltaSeconds = targetSeconds - predictedSeconds(forKm: raceKm)
                Text("Objectif \(profile.goalDisplay) → ")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    + Text(deltaSeconds >= 0
                           ? "en avance de \(Int(deltaSeconds))″"
                           : "\(Int(-deltaSeconds))″ à gagner")
                        .font(RUFont.sans(.small, weight: .bold)).foregroundColor(deltaSeconds >= 0 ? RUColor.lime : RUColor.amber)
                    + Text(" sur ton objectif.").font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
            }
        }
        .padding(16)
        .ruHeroCard()
    }

    private func predictionTile(_ label: String, _ value: String, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            // Was a bare `Text(label)` — a `String`-typed param never resolves through the String
            // Catalog (only the `LocalizedStringKey` initializer does), so "5 KM"/"10 KM"/"SEMI"
            // silently never localized despite the app having EN/ES translations. Pre-existing gap,
            // fixed in passing since this function was already touched for the MARATHON tile.
            Text(LocalizedStringKey(label)).font(RUFont.sans(.micro, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
            Text(value).displayStyle(22).foregroundColor(highlighted ? RUColor.rose2 : RUColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(highlighted ? RUColor.rose.opacity(0.14) : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(highlighted ? RUColor.rose.opacity(0.3) : RUColor.line, lineWidth: RUSpacing.hairline))
    }

    // MARK: Training load — was a fixed fake bar chart + fake "ratio charge 1.1"

    private var weeklyDistances: [Double] {
        // Same Monday-first anchoring as `bestWeekKm` — see comment there.
        let cal = Calendar.current
        var weekTotals: [Date: Double] = [:]
        for run in runs {
            weekTotals[AdaptivePlanEngine.currentWeekRange(from: run.date).lowerBound, default: 0] += run.distanceKm
        }
        let thisWeekStart = AdaptivePlanEngine.currentWeekRange().lowerBound
        return (0..<8).reversed().compactMap { offset in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) else { return nil }
            return weekTotals[weekStart] ?? 0
        }
    }

    /// Acute (this week) vs. chronic (last 4 weeks' average) training load — a standard, real
    /// workload-ratio calculation (values around 0.8–1.3 are typically considered a "sweet spot";
    /// consistently above ~1.5 is a common overload signal). Deliberately built from the SAME
    /// Monday-anchored week buckets `weeklyDistances` plots as bars below it — a rolling
    /// 7-day/28-day window anchored on `.now` disagreed with those calendar-week bars mid-week
    /// (the printed ratio could visually contradict what the bars showed).
    private var acuteChronicRatio: Double? {
        let bars = weeklyDistances
        guard bars.count >= 4, let acute = bars.last else { return nil }
        let last4 = bars.suffix(4)
        let chronicWeeklyAvg = last4.reduce(0, +) / Double(last4.count)
        guard chronicWeeklyAvg > 0 else { return nil }
        return acute / chronicWeeklyAvg
    }

    private func loadZoneLabel(_ ratio: Double) -> String {
        if ratio > 1.5 { return String(localized: "Charge élevée") }
        if ratio < 0.8 { return String(localized: "Charge faible") }
        return "Zone optimale"
    }

    private var loadCard: some View {
        let bars = weeklyDistances
        let maxBar = max(bars.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            RUCardHeader(icon: "chart.bar.fill", tint: RUColor.cyan,
                         title: "Charge d'entraînement",
                         subtitle: "Sur 8 semaines") {
                if let ratio = acuteChronicRatio {
                    StatChip(text: loadZoneLabel(ratio), color: ratio > 1.5 ? RUColor.amber : RUColor.cyan)
                }
            }
            if runs.isEmpty {
                Text("Ta charge d'entraînement s'affichera ici après tes premières courses.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
            } else {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(bars.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: RUSpacing.radiusBar)
                            .fill(i == bars.count - 1 ? RUColor.rose : RUColor.line)
                            // Same grow-from-baseline reveal as WeeklyRecapView's volume chart.
                            .frame(height: chartRevealed ? max(4, bars[i] / maxBar * 70) : 4)
                            .frame(maxWidth: .infinity)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(Double(i) * 0.04), value: chartRevealed)
                            // No per-week value was ever exposed, and "this week" (the last bar)
                            // was marked by color alone — VoiceOver had nothing beyond a silent bar.
                            .accessibilityLabel(i == bars.count - 1
                                ? "Cette semaine"
                                : String(localized: "Il y a \(bars.count - 1 - i) semaine\(bars.count - 1 - i > 1 ? "s" : "")"))
                            .accessibilityValue("\(String(format: "%.1f", locale: Locale.current, bars[i])) km")
                    }
                }
                .frame(height: 70, alignment: .bottom)
                .onAppear { chartRevealed = true }
                HStack {
                    Text("S-7").font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    Spacer()
                    if let ratio = acuteChronicRatio {
                        Text("ratio charge \(String(format: "%.1f", locale: Locale.current, ratio))").font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    }
                    Spacer()
                    Text("Cette sem.").font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                }
            }
        }
        .padding(16)
        .ruCard()
    }
}
