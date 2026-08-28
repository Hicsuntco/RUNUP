import SwiftUI
import SwiftData

/// "Programme" home screen — mirrors `ProgScreen` in screensA.jsx.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    // Scoped to unread only — this query exists solely to badge the bell icon with a count, but
    // an unscoped `@Query` fetched every notification ever created (unbounded, grows for the
    // app's whole lifetime) just to filter it back down to unread right after. NotificationsSheet
    // has its own separate `@Query` for the full list it actually displays.
    @Query(filter: #Predicate<AppNotification> { !$0.read }) private var unreadNotifications: [AppNotification]
    /// Borné aux trois dernières semaines, et c'est largement suffisant : `runs` ne sert QU'À
    /// `weeklyKm`, qui somme cette semaine et la précédente. Sans cette borne, l'écran ouvert tous
    /// les jours au lancement chargeait TOUT l'historique — chaque ligne portant son tracé GPS
    /// sérialisé, soit des dizaines de mégaoctets après quelques centaines de courses — pour
    /// produire deux additions hebdomadaires. Et il le rechargeait à chaque retour sur l'onglet,
    /// puisque `RootTabView` recrée l'écran courant à chaque navigation.
    ///
    /// Trois semaines plutôt que deux : une marge qui absorbe les semaines à cheval sur un
    /// changement de mois ou d'année sans jamais rogner la comparaison.
    @Query private var runs: [RunRecord]
    /// UNE ligne, et seulement pour savoir s'il en existe une.
    ///
    /// `runs` ci-dessus est borné aux trois dernières semaines : `runs.isEmpty` y signifie « rien
    /// couru depuis trois semaines », pas « jamais couru ». S'en servir pour l'état du premier
    /// jour souhaiterait la bienvenue à quelqu'un qui revient après un mois d'arrêt. Une requête
    /// non bornée dirait la vérité mais rechargerait tout l'historique — tracés GPS compris — à
    /// chaque retour sur l'onglet, ce que le commentaire ci-dessus existe précisément pour
    /// éviter. `fetchLimit = 1` répond à la question sans payer ce prix.
    @Query private var firstRunProbe: [RunRecord]

    /// Aucune course enregistrée, jamais — l'état du premier jour.
    private var hasNeverRun: Bool { firstRunProbe.isEmpty }

    init() {
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: .now) ?? .distantPast
        _runs = Query(
            filter: #Predicate<RunRecord> { $0.date >= cutoff },
            sort: \RunRecord.date,
            order: .reverse
        )
        var probe = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\RunRecord.date)])
        probe.fetchLimit = 1
        _firstRunProbe = Query(probe)
    }

    private var profile: UserProfile { appState.profile }
    private var isFreeRun: Bool { profile.programPhase == .freerun }
    private var unreadCount: Int { unreadNotifications.count }

    var body: some View {
        Group {
            switch profile.programPhase {
            case .recovery: RecoveryView()
            case .choice: ChoiceView()
            default: mainContent
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HeaderView(
                    // La date du jour, pas "Semaine 4/9" : la carte programme juste en dessous
                    // affiche déjà la semaine ET le bloc, donc l'eyebrow ne faisait que répéter
                    // l'information la plus proche à l'écran. Une date ancre le prénom dans le
                    // vrai jour, comme la maquette (`.greet` au-dessus de `.greet-name`).
                    //
                    // Le prénom SEUL, sans salutation. « Salut Charlotte » se lit une fois avec
                    // plaisir et cent fois comme un automatisme ; le prénom seul, sous la date du
                    // jour, dit la même chose sans faire semblant de dire bonjour.
                    eyebrow: isFreeRun ? String(localized: "Mode course libre") : todayDateEyebrow,
                    title: profile.name
                ) {
                    HStack(spacing: 8) {
                        streakChip
                        Button(action: { appState.openNotifications() }) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(RUColor.card)
                                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                                    .frame(width: 36, height: 36)
                                    .overlay(Image(systemName: "bell").font(.system(size: 15)).foregroundColor(RUColor.textPrimary))
                                if unreadCount > 0 {
                                    Circle().fill(RUColor.rose).frame(width: 8, height: 8)
                                        .overlay(Circle().stroke(RUColor.bg, lineWidth: 1.5))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(unreadCount > 0
                            ? String(localized: "Notifications, \(unreadCount) non lues")
                            : String(localized: "Notifications"))
                        // L'avatar est parti : le Profil est un onglet maintenant, ce bouton
                        // était un second chemin vers la même destination, à côté d'une barre
                        // d'onglets qui la montre en permanence. L'en-tête de la maquette est
                        // d'ailleurs réduit à la date, au nom et à la pastille de série — elle
                        // ne pose pas d'avatar ici, précisément pour cette raison.
                        //
                        // La cloche reste : les notifications n'ont pas d'onglet, et la maquette
                        // ne les omet pas au sens d'une décision de les supprimer.
                    }
                }

                // Ordre repris de la maquette "Accueil" : les objectifs du jour (l'anneau), puis
                // la bande de chiffres repères, puis la séance — la séance reste l'ancre visuelle
                // de l'écran, et tout ce qui est "plan / programme" passe après elle au lieu de
                // s'intercaler entre l'en-tête et elle.
                ringsCard

                quickStatsRow

                sessionCard

                programWeekCard

                if isFreeRun {
                    Text("Pas de plan fixe — le coach te propose de quoi garder la forme, jour après jour.")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                // Descendu tout en bas : c'est une action de maintenance, rare et à moitié
                // destructive (le programme repart à la semaine 1), qui occupait jusqu'ici la
                // deuxième place de l'écran ouvert tous les jours. La maquette n'a rien de tel
                // en haut — elle enchaîne directement anneau → chiffres → séance.
                // Ouvre le même assistant "nouvel objectif" que Profil/Plus de réglages et que
                // l'écran de fin de programme (ChoiceView) — il ne remplace que
                // objectif/distance/allure/jours, rien de personnel (nom, blessures, cycle...).
                Button(action: { appState.newGoalWizardPresented = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 11))
                        Text("Refaire un programme").font(RUFont.sans(.small, weight: .semibold))
                    }
                    .foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    /// The week strip and the program teaser, merged into ONE card (owner's call — they're two
    /// halves of the same information, "où j'en suis cette semaine / dans le programme", and
    /// lived at opposite ends of the screen). Tapping anywhere opens the full plan. In course
    /// libre there's no program to tease, so the card is just the days, not tappable.
    private var programWeekCard: some View {
        let shape = planShape
        let block = AdaptivePlanEngine.trainingBlock(forWeek: profile.weekNumber, shape: shape)
        return Button(action: { appState.go(.plan) }) {
            VStack(alignment: .leading, spacing: 12) {
                // Combined separately from `weekStrip` below — that already exposes one element
                // per day (see `dayAccessibilityLabel`); flattening it into this same combine would
                // undo that per-day granularity instead of adding to it.
                Group {
                    if !isFreeRun {
                        HStack {
                            // L'objectif revient ici. Il était passé dans `quickStatsRow`, mais
                            // « 20KM · 1:45 » n'est pas UN chiffre : c'est une distance et un
                            // temps collés, trois fois plus large que le « J-58 » d'à côté. Dans
                            // une bande de chiffres séparés par des filets, ça donnait trois
                            // colonnes de largeurs incomparables et des filets posés au hasard.
                            // Sa place est en eyebrow de la carte qui parle du programme — c'est
                            // là qu'il était, et c'était juste. Le J-x, lui, EST un chiffre court
                            // et reste dans la bande.
                            RUCardHeader(icon: "map.fill", tint: RUColor.rose, title: String(localized: "Ton programme · \(profile.goalDisplay)"))
                            Text("→").foregroundColor(RUColor.rose2)
                        }
                        Text("\(weekEyebrow) · Bloc \(block.label)").displayStyle(17).foregroundColor(RUColor.textPrimary)
                    }
                }
                .accessibilityElement(children: .combine)
                weekStrip
                if !isFreeRun {
                    if let total = shape.totalWeeks {
                        PhaseProgressBar(phases: [
                            PhaseSegment(name: "Base", done: min(profile.weekNumber, shape.baseWeeks), total: shape.baseWeeks, color: RUColor.rose),
                            PhaseSegment(name: "Spécifique", done: max(0, min(profile.weekNumber - shape.baseWeeks, shape.specificWeeks)), total: shape.specificWeeks, color: RUColor.rose2),
                            PhaseSegment(name: "Affûtage", done: max(0, min(profile.weekNumber - shape.baseWeeks - shape.specificWeeks, shape.taperWeeks)), total: shape.taperWeeks, color: RUColor.violet)
                        ], showLabels: false)
                        Text("\(total) semaines · voir le plan complet").font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    } else {
                        Text("Programme ouvert · voir le plan complet").font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    }
                }
            }
            .padding(14)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
        .disabled(isFreeRun)
    }

    /// Shows the real date number (today circled), not just the bare weekday letter — so it's
    /// unambiguous which real calendar day each cell is, instead of an abstract L/M/M/J/V/S/D
    /// that says nothing about "today" until you count.
    private var weekStrip: some View {
        HStack(spacing: 5) {
            ForEach(profile.weekStrip) { day in
                let (bg, border, color): (Color, Color, Color) = {
                    switch day.state {
                    case .done: return (RUColor.rose, RUColor.rose, .white)
                    case .today: return (RUColor.rose.opacity(0.12), RUColor.rose.opacity(0.5), RUColor.rose2)
                    case .rest: return (RUColor.card, RUColor.line, RUColor.text4)
                    case .upcoming: return (RUColor.card, RUColor.line, RUColor.text2)
                    }
                }()
                VStack(spacing: 5) {
                    Text(day.displayLetter).displayStyle(11).foregroundColor(color)
                    ZStack {
                        if day.state == .today {
                            Circle().stroke(RUColor.rose2, lineWidth: 1.5).frame(width: 19, height: 19)
                        }
                        if day.state == .done {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(color)
                        } else {
                            Text("\(Calendar.current.component(.day, from: day.date))")
                                .font(RUFont.sans(.small, weight: day.state == .today ? .bold : .regular))
                                .foregroundColor(color)
                        }
                    }
                    .frame(width: 19, height: 19)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                // Each cell (weekday letter + a date number or checkmark, colored by state) was
                // 2-3 separate disconnected VoiceOver stops with no indication of which day is
                // today, done, or a rest day — that information lived only in color/border, never
                // announced.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(dayAccessibilityLabel(day))
                .background(bg, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(border, lineWidth: RUSpacing.hairline))
            }
        }
    }

    private func dayAccessibilityLabel(_ day: DayStatus) -> String {
        let dayNumber = Calendar.current.component(.day, from: day.date)
        let name = "\(DayStatus.fullNames[day.weekday]) \(dayNumber)"
        switch day.state {
        case .today: return String(localized: "\(name), aujourd'hui")
        case .done: return String(localized: "\(name), séance faite")
        case .rest: return String(localized: "\(name), repos")
        case .upcoming: return String(localized: "\(name), à venir")
        }
    }

    /// Was one big `Button` wrapping the FAIT/DÉMARRER buttons INSIDE it — nested SwiftUI buttons
    /// have unreliable hit-testing (the outer button can swallow or fight taps meant for the
    /// inner ones), which is almost certainly why the FAIT/DÉMARRER row felt inconsistent to tap.
    /// A plain `VStack` with `.onTapGesture` for "open the detail sheet" opens exactly the same
    /// way, but SwiftUI correctly gives priority to the real `Button`s nested inside a tap-gesture
    /// container (unlike inside an actual `Button`), so FAIT/DÉMARRER get their own reliable taps.
    private var sessionCard: some View {
        let session = profile.todaySession
        let isRestDay = session.durationMinutes == 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                sessionTag(isRestDay)
                Spacer()
                if let adj = session.adjustment {
                    StatChip(text: adj, color: RUColor.rose2)
                }
            }
            // Un jour de repos, cette carte n'a rien à faire faire : ni durée, ni allure, ni
            // boutons. Elle gardait pourtant le corps de 23 pt des jours de séance, ce qui
            // faisait de « REPOS » le bloc le plus lourd de l'écran — la hiérarchie disait
            // l'inverse de l'information. Le titre recule d'un cran et la carte se contente
            // d'une ligne, pour que le regard aille à l'anneau et aux chiffres de la semaine,
            // qui eux ont quelque chose à dire ce jour-là.
            Text(session.displayTitle)
                .displayStyle(isRestDay ? 18 : 23)
                .foregroundColor(isRestDay ? RUColor.text2 : RUColor.textPrimary)
                .padding(.top, 8)

            if isRestDay {
                // Le sous-titre du modèle et la phrase d'explication disaient déjà la même
                // chose deux fois de suite (« Jour de repos — laisse ton corps récupérer », puis
                // « Pas de séance prévue — profite-en pour récupérer »). Une seule suffit.
                Text(session.displaySubtitle)
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    .padding(.top, 4)
            } else if profile.seanceDoneToday {
                Text(session.displaySubtitle).font(RUFont.sans(.small)).foregroundColor(RUColor.text2).padding(.top, 4)
                Text("Séance faite aujourd'hui ✓")
                    .font(RUFont.sans(.body, weight: .semibold)).foregroundColor(RUColor.lime)
                    .padding(.top, 14)
            } else {
                Text(session.displaySubtitle).font(RUFont.sans(.small)).foregroundColor(RUColor.text2).padding(.top, 4)
                HStack(spacing: 16) {
                    MetricColumn(value: "\(session.durationMinutes)′", label: "Durée")
                    MetricColumn(value: session.pace, label: "Allure")
                    MetricColumn(value: session.zone, label: "Zone", valueColor: RUColor.rose2)
                }
                .padding(.top, 14)

                HStack(spacing: 8) {
                    // For a strength session, a treadmill run, or just forgetting to hit
                    // record — logging it shouldn't require the full GPS flow.
                    Button(action: { appState.markTodaySessionDone() }) {
                        HStack { Image(systemName: "checkmark"); Text("FAIT") }
                            // Matches DÉMARRER's PrimaryButtonStyle typography (la police de titrage
                            // font) so the two read as one paired control, not two mismatched
                            // buttons — the outline vs. filled chrome from SecondaryButtonStyle
                            // is what should carry the "lower emphasis" signal, not the font.
                            .font(RUFont.display(16))
                            .tracking(1)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: { appState.startRun() }) {
                        HStack { Image(systemName: "play.fill"); Text("DÉMARRER") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.top, 15)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture { appState.openSessionDetail() }
        .ruCard()
        // The manual-debrief sheet presents from RootTabView now — anchored here it could only
        // ever appear while this specific card was mounted on screen.
    }

    /// Replaces the old "forme du jour" readiness ring — that score barely moved week to week and
    /// wasn't tied to anything she could act on. Total km run this week, compared against last
    /// week, is the number every runner already watches and tries to beat — real, concrete, and
    /// it visibly changes after every run instead of drifting inside a narrow band.
    private func weeklyKm(weeksAgo: Int) -> Double {
        let cal = Calendar.current
        let thisWeekStart = AdaptivePlanEngine.currentWeekRange().lowerBound
        guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeekStart) else { return 0 }
        let range = AdaptivePlanEngine.currentWeekRange(from: weekStart)
        return runs.filter { range.contains($0.date) }.reduce(0) { $0 + $1.distanceKm }
    }

    /// La bande `.simplestats` de la maquette : deux ou trois chiffres repères séparés par des
    /// filets, posés à même la page (pas de carte) entre l'anneau et la séance.
    ///
    /// Remplace l'ancienne carte pleine largeur "Cette semaine · N km", qui dépensait une carte
    /// entière pour un seul chiffre. Rien d'inventé : le km de la semaine et la comparaison avec
    /// la semaine dernière sont les mêmes calculs qu'avant (`weeklyKm`), l'objectif hebdo affiché
    /// en dénominateur est `plannedWeeklyKm` (le vrai plan de la semaine, 0 en course libre — le
    /// dénominateur disparaît alors au lieu d'être inventé), et le J-x / l'objectif ne sont pas
    /// nouveaux non plus : ils étaient jusqu'ici enterrés dans l'eyebrow de la carte programme.
    /// Reste tapable vers les Stats, comme la carte qu'elle remplace.
    private var quickStatsRow: some View {
        let thisWeek = weeklyKm(weeksAgo: 0)
        let lastWeek = weeklyKm(weeksAgo: 1)
        let delta = thisWeek - lastWeek
        let planned = profile.plannedWeeklyKm
        return Button(action: { appState.go(.stats) }) {
            // Encadrée par deux filets pleine largeur. Sans eux, la bande de chiffres ET la ligne
            // « semaine dernière / Mes stats » flottaient toutes deux à même la page, sans rien
            // pour dire qu'elles forment un bloc ni où il s'arrête : ça se lisait comme un trou
            // entre deux cartes, pas comme une intention. Des filets plutôt qu'une carte, parce
            // qu'une quatrième carte identique empilée aurait ramené l'écran à une pile de boîtes
            // interchangeables — c'est justement ce que le passage à une bande devait défaire.
            VStack(spacing: 10) {
                Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                HStack(spacing: 0) {
                    quickStat(
                        value: String(format: "%.1f", locale: Locale.current, thisWeek),
                        suffix: planned > 0 ? "/\(Int(planned.rounded()))" : nil,
                        label: "km sem."
                    )
                    if let days = profile.daysUntilRace {
                        quickStatDivider
                        quickStat(value: String(localized: "J-\(days)"), suffix: nil, label: "avant course")
                    }
                }
                HStack(spacing: 6) {
                    Text(weeklyComparisonText(delta: delta, lastWeek: lastWeek))
                        .font(RUFont.sans(.small))
                        .foregroundColor(weeklyComparisonColor(delta: delta, lastWeek: lastWeek))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text("Mes stats").font(RUFont.sans(.small, weight: .semibold)).foregroundColor(RUColor.text3)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(RUColor.text3)
                }
                Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var quickStatDivider: some View {
        Rectangle().fill(RUColor.line).frame(width: RUSpacing.hairline, height: 34)
    }

    private func quickStat(value: String, suffix: String?, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value).displayStyle(21).foregroundColor(RUColor.textPrimary)
                if let suffix {
                    Text(suffix).font(RUFont.sans(.body, weight: .semibold)).foregroundColor(RUColor.text3)
                }
            }
            .lineLimit(1)
            // Les colonnes se partagent la largeur à parts égales (`maxWidth: .infinity`) : on
            // rétrécit plutôt que de tronquer si un chiffre déborde le sien.
            .minimumScaleFactor(0.6)
            Text(LocalizedStringKey(label))
                .font(RUFont.sans(.micro, weight: .bold)).tracking(0.8).textCase(.uppercase)
                .foregroundColor(RUColor.text3)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        // Sans ça, VoiceOver lit la valeur et son libellé comme deux arrêts sans lien — même
        // traitement que `MetricColumn`, dont cette colonne est la variante centrée.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(label)) + Text(", ") + Text(value + (suffix ?? "")))
    }

    /// La pastille dégradée `.session-card .tag` de la maquette, à la place de l'eyebrow rose
    /// discret : c'est le seul endroit de l'écran où la maquette remplit vraiment avec l'accent,
    /// et ça fait de la carte séance l'ancre visuelle de la page. Un jour de repos garde une
    /// pastille neutre — il n'y a rien à mettre en avant.
    private func sessionTag(_ isRestDay: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isRestDay ? "moon.zzz.fill" : "bolt.fill").font(.system(size: 9, weight: .bold))
            Text(LocalizedStringKey(isRestDay ? "Aujourd'hui" : "Séance du jour"))
                .font(RUFont.sans(.micro, weight: .bold)).tracking(1).textCase(.uppercase)
        }
        .foregroundColor(isRestDay ? RUColor.text2 : .white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isRestDay
                ? AnyShapeStyle(RUColor.card2)
                : AnyShapeStyle(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom)),
            in: Capsule()
        )
        .overlay(Capsule().stroke(isRestDay ? RUColor.line : Color.clear, lineWidth: RUSpacing.hairline))
    }

    private func weeklyComparisonText(delta: Double, lastWeek: Double) -> String {
        // Le premier jour, « pas de course enregistrée » est exact et ne sert à rien : c'est une
        // comparaison avec un passé qui n'existe pas encore, posée sous deux zéros. Distinguer
        // « jamais couru » de « rien couru la semaine dernière » demande une phrase de plus et
        // change ce que l'écran dit d'elle.
        if hasNeverRun {
            return String(localized: "Ta première sortie lancera ta série.")
        }
        guard lastWeek > 0 else {
            return String(localized: "Semaine dernière : pas de course enregistrée.")
        }
        let deltaText = String(format: "%.1f", locale: Locale.current, abs(delta))
        if delta > 0.05 { return String(localized: "+\(deltaText) km vs la semaine dernière") }
        if delta < -0.05 { return String(localized: "-\(deltaText) km vs la semaine dernière") }
        return String(localized: "Comme la semaine dernière")
    }

    private func weeklyComparisonColor(delta: Double, lastWeek: Double) -> Color {
        guard lastWeek > 0, delta > 0.05 else { return RUColor.text2 }
        return RUColor.lime
    }

    /// Légende verticale `.ring-legend` de la maquette (pastille · nom de l'objectif · valeur
    /// alignée à droite) à la place de la rangée horizontale de trois valeurs : les trois
    /// objectifs y étaient serrés côte à côte et surtout désignés par leur unité ("séance",
    /// "/400 KCAL", "/6000 PAS") plutôt que par leur nom, ce qui obligeait à décoder la couleur
    /// de l'anneau pour savoir de quel objectif on parle. Une ligne par objectif, nommée, laisse
    /// aussi la valeur respirer au lieu d'être tronquée.
    private var ringsCard: some View {
        let p = profile
        // Same array `DailyGoalsBarsView` draws its bars in, so each stat's color always matches
        // its bar's actual color.
        let goalColors = DailyGoalsBarsView.fillColors
        return Button(action: { appState.go(.rings) }) {
            HStack(spacing: 16) {
                // Un cran plus grand que les 72 pt d'avant : la maquette donne à l'anneau presque
                // la moitié de la largeur du contenu. On ne va pas jusque-là (ce serait dépasser
                // l'anneau héros de l'écran "Ta journée", qui doit rester le plus grand), mais
                // 96 pt lui rend le poids d'élément principal de la carte.
                DailyGoalsBarsView(progress: p.dailyGoalsProgress, size: 96)
                VStack(alignment: .leading, spacing: 9) {
                    RUCardHeader(title: String(localized: "Tes objectifs · \(p.dailyGoalsDone)/\(p.dailyGoalsTotal) bouclés"))
                    ringLegendRow(
                        name: "Séance du jour",
                        value: p.isRestDayToday
                            ? String(localized: "Repos")
                            : (p.seanceDoneToday ? String(localized: "Faite") : String(localized: "À faire")),
                        color: goalColors[0]
                    )
                    ringLegendRow(name: "Calories actives", value: "\(Int(p.activeCaloriesToday))/\(Int(p.activeCaloriesGoal))", color: goalColors[1])
                    ringLegendRow(name: "Pas", value: "\(Int(p.stepsToday))/\(Int(p.stepsGoal))", color: goalColors[2])
                }
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    private func ringLegendRow(name: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(LocalizedStringKey(name))
                .font(RUFont.sans(.body, weight: .semibold))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 6)
            Text(value)
                .font(RUFont.sans(.small, weight: .medium))
                .foregroundColor(RUColor.text3)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        // Sinon VoiceOver lit la pastille, le nom et la valeur comme trois arrêts distincts —
        // et la pastille, seule porteuse de la correspondance avec l'anneau, ne dit rien du tout.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(name)) + Text(", ") + Text(value))
    }

    /// `profile.streak` was already tracked (`AdaptivePlanEngine.applyDebrief`) and shown deep in
    /// Stats/Readiness/Club, but never on Home — the screen actually opened every day, where a
    /// visible streak does the most to make her not want to break it.
    private var streakChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").font(.system(size: 12))
            Text("\(profile.streak)").font(RUFont.sans(.label, weight: .bold))
        }
        .foregroundColor(profile.streak > 0 ? RUColor.amber : RUColor.text3)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RUColor.card, in: Capsule())
        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        // Was just "5" to VoiceOver with no context — the flame icon that gives it meaning
        // visually carries no information for someone who can't see it.
        .accessibilityElement(children: .combine)
        // Deux clés entières plutôt qu'un « jour\(s) » recollé : le pluriel ne se fabrique pas en
        // ajoutant un « s » dans les autres langues.
        .accessibilityLabel(profile.streak > 1
            ? String(localized: "Série, \(profile.streak) jours")
            : String(localized: "Série, \(profile.streak) jour"))
    }

    /// La date du jour, en toutes lettres — `EyebrowLabel` la passe en capitales comme tous les
    /// eyebrows de l'app.
    private var todayDateEyebrow: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale.current))
    }

    /// "Semaine 4/9" when the program has a real end (a race goal periodizes toward one), else
    /// just "Semaine 4" — matches the mockup's "SEM. 4/9" without claiming a total for the
    /// open-ended goals (progress/weight/restart/health) that genuinely don't have one.
    private var weekEyebrow: String {
        if let total = planShape.totalWeeks {
            return String(localized: "Semaine \(profile.weekNumber)/\(total)")
        }
        return String(localized: "Semaine \(profile.weekNumber)")
    }

    private var planShape: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
    }

}
