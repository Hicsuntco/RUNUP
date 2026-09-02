import SwiftUI

/// Le plan complet. Les séances de la semaine en cours viennent des données générées par
/// `AdaptivePlanEngine`, adaptées une fois par semaine à partir du RPE moyen de la semaine
/// précédente (voir `refreshProgramForCurrentDate`) — jamais après une seule course. Les autres
/// semaines montrent un aperçu type généré de la même façon, annoncé comme tel puisque leur
/// difficulté exacte dépend d'une adaptation qui n'a pas encore eu lieu.
///
/// # Pourquoi une courbe plutôt qu'une liste
///
/// L'écran a eu deux vies, et la deuxième n'a pas suffi. Il a d'abord empilé 8 à 16 cartes
/// identiques, chacune repliable ; on les a ensuite groupées par phase, avec les semaines passées
/// derrière un dépliant. C'était moins dense, mais toujours la même chose : une liste de boîtes
/// grises où chaque ligne dit « Semaine 7 · ~34 km » et où rien ne distingue la 7 de la 8.
///
/// Or un plan périodisé N'EST PAS une liste. C'est une forme : le volume monte pendant la Base,
/// culmine en Spécifique, retombe à l'Affûtage, avec une semaine allégée qui revient. C'est
/// exactement ce qu'on achète en payant un plan adaptatif, et c'était la seule chose que l'écran
/// ne montrait pas — il fallait déplier douze lignes et retenir douze nombres pour la deviner.
///
/// Trois mécanismes — la carte de la semaine en cours, l'accordéon des semaines à venir, le
/// dépliant des semaines faites — sont donc remplacés par un seul : une barre par semaine, en
/// couleur de phase, et sous elle la semaine choisie, dépliée. La semaine en cours est celle qui
/// est choisie à l'ouverture, parce que c'est celle qu'on vient voir ; les autres sont à un geste.
struct PlanView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    /// La semaine que la page détaille. `nil` avant le premier calcul, puis toujours une valeur —
    /// la semaine en cours à l'ouverture.
    @State private var selectedWeek: Int?
    /// Instantané de `computeWeekSummaries()`, calculé au premier affichage et rafraîchi seulement
    /// quand la semaine avance. En propriété calculée, il relancerait
    /// `AdaptivePlanEngine.generateWeekSessions` pour CHAQUE semaine du plan à la moindre
    /// re-évaluation de la vue — et le graphique en dépend, donc à chaque changement de sélection.
    @State private var weekSummaries: [WeekSummary] = []
    /// Les jours de la semaine affichée, mis en cache pour la même raison que `weekSummaries`.
    ///
    /// Pour une semaine autre que celle en cours, `dayList` régénère les séances par
    /// `AdaptivePlanEngine`. La carte est visible en permanence maintenant — elle n'est plus
    /// derrière un dépliement — donc l'appeler depuis le corps de la vue relancerait cette
    /// génération à chaque re-évaluation, y compris celles que la sélection déclenche.
    @State private var selectedDays: [(String, PlannedDay, DayStatus.State?)] = []

    private struct WeekSummary: Identifiable {
        var id: Int { number }
        var number: Int
        var block: AdaptivePlanEngine.TrainingBlock
        var estimatedKm: Int
        var isDone: Bool
        var isCurrent: Bool
    }

    /// Real program shape — a race goal periodizes toward the actual race date (variable length,
    /// not a fixed 9 weeks); every other goal is open-ended (`totalWeeks == nil`), so there's no
    /// fixed "whole plan" to show — the preview window below just looks a reasonable distance ahead.
    private var shape: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
    }

    /// Les semaines que la page dessine et laisse parcourir.
    ///
    /// Un plan de course est borné (20 semaines au plus, voir `ProgramShape.compute`) et sa forme
    /// EST l'information : on le montre en entier. Un programme ouvert n'a pas de fin — après un
    /// an, l'ancienne borne `weekNumber + 7` aurait dessiné 59 barres de trois points et généré
    /// 59 semaines de séances à chaque ouverture de l'écran. Sa forme se répète toutes les
    /// 4 semaines : une fenêtre autour de la semaine en cours dit tout ce qu'il y a à dire.
    private var weekRange: ClosedRange<Int> {
        if let total = shape.totalWeeks { return 1...max(1, total) }
        let hi = profile.weekNumber + 7
        return max(1, profile.weekNumber - 8)...max(hi, 8)
    }

    private func computeWeekSummaries() -> [WeekSummary] {
        weekRange.map { number in
            let sessions = number == profile.weekNumber
                ? profile.weekSessions
                : AdaptivePlanEngine.generateWeekSessions(weekNumber: number, tier: profile.weekTier, profile: profile)
            return WeekSummary(
                number: number,
                block: AdaptivePlanEngine.trainingBlock(forWeek: number, shape: shape),
                estimatedKm: estimatedKm(for: sessions),
                isDone: number < profile.weekNumber,
                isCurrent: number == profile.weekNumber
            )
        }
    }

    private var currentWeek: WeekSummary? { weekSummaries.first { $0.isCurrent } }

    private var selected: WeekSummary? {
        weekSummaries.first { $0.number == selectedWeek } ?? currentWeek
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackTitleHeaderView(eyebrow: String(localized: "Ton programme · \(profile.goalDisplay)"), title: "Le plan complet") {
                    appState.go(.home)
                }

                // Le plan COMPLET est ce que Plus vend : la périodisation sur plusieurs
                // semaines, sa forme, et son recalcul après chaque sortie. La séance du jour
                // reste gratuite sur l'accueil — c'est elle qui donne envie de voir la suite, et
                // la cacher reviendrait à vendre quelque chose que personne n'a goûté.
                PlusSection(feature: .adaptivePlan, teaserHeight: 200) {
                    VStack(alignment: .leading, spacing: 18) {
                        volumeChart

                        weekNavigator

                        if let week = selected {
                            weekCard(week)
                        }

                        planShapeNote
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .onAppear {
            weekSummaries = computeWeekSummaries()
            if selectedWeek == nil { selectedWeek = profile.weekNumber }
            refreshSelectedDays()
        }
        .onChange(of: selectedWeek) { _, _ in refreshSelectedDays() }
        // La liste des jours est mise en cache dans `selectedDays` — sans ceci, une séance
        // déplacée depuis la feuille resterait affichée à son ancien jour jusqu'à ce qu'on quitte
        // l'écran. Le déplacement aurait bien eu lieu, et l'écran dirait le contraire.
        .onChange(of: profile.weekSessions) { _, _ in refreshSelectedDays() }
        .onChange(of: profile.weekNumber) { _, week in
            weekSummaries = computeWeekSummaries()
            // La semaine avance pendant que l'écran est ouvert : suivre le mouvement plutôt que
            // laisser la page détailler une semaine qui vient de devenir passée.
            selectedWeek = week
            refreshSelectedDays()
        }
    }

    // MARK: La forme du plan

    /// Une barre par semaine, en couleur de phase, hauteur proportionnelle au volume estimé.
    ///
    /// Les barres sont étroites — seize semaines dans une largeur d'écran — donc bien en dessous
    /// des 44 pt des règles d'Apple. C'est le même arbitrage que pour un contrôle segmenté : elles
    /// sont jointives, une frappe imprécise tombe sur la voisine et non dans le vide, et la zone
    /// tapable couvre toute la hauteur du graphique. Pour viser sans se tromper, le sélecteur
    /// juste en dessous offre deux vraies cibles de 44 pt.
    private var volumeChart: some View {
        let maxKm = max(1, weekSummaries.map(\.estimatedKm).max() ?? 1)
        return VStack(alignment: .leading, spacing: 14) {
            RUCardHeader(icon: "chart.bar.fill", tint: RUColor.rose,
                         title: "La forme du plan",
                         subtitle: "Volume estimé, semaine par semaine")
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(weekSummaries) { week in
                    volumeBar(week, maxKm: maxKm)
                }
            }
            .frame(height: 108)
            phaseBar
            deloadNote
        }
        .padding(16)
        .ruCard()
    }

    /// Ce que la barre grise veut dire.
    ///
    /// La barre de phases sert de légende aux trois couleurs de périodisation — Base, Spécifique,
    /// Affûtage. Elle ne pouvait pas nommer la quatrième : une semaine de décharge n'est pas une
    /// phase, c'en est un creux À L'INTÉRIEUR d'une phase, et l'ajouter à une barre de progression
    /// aurait décrit un plan qui n'existe pas.
    ///
    /// Résultat : la seule barre qui rompt le rythme, celle que l'œil va chercher en premier
    /// parce qu'elle est grise et courte, était la seule que rien n'expliquait. C'est d'autant
    /// plus dommage que c'est la meilleure chose que le graphique ait à raconter — le moment où le
    /// programme allège de lui-même pour laisser la charge se transformer en progrès.
    ///
    /// Une ligne, et seulement quand le plan affiché en contient : une légende qui nomme une
    /// couleur absente apprend à ignorer les légendes.
    @ViewBuilder private var deloadNote: some View {
        if weekSummaries.contains(where: { $0.block == .deload }) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(RUColor.text3)
                    .frame(width: 10, height: 10)
                Text("En gris, les semaines de décharge : le volume baisse exprès, c'est là que les progrès se fixent.")
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }

    /// La barre de phases, sous le graphique.
    ///
    /// Elle avait disparu, et c'était une erreur. Le graphique et elle ne disent pas la même
    /// chose : l'un montre le VOLUME semaine par semaine, elle montre où l'on en est dans la
    /// périodisation — « 3 semaines de Base sur 6 » se lit sur elle d'un coup d'œil, alors qu'il
    /// faut compter les barres pour le déduire du graphique. Elle sert aussi de légende : ses
    /// trois libellés nomment les trois couleurs juste au-dessus, ce qu'une rangée de pastilles
    /// faisait moins bien puisqu'elle n'ajoutait rien d'autre.
    ///
    /// Elle ne s'affiche que pour un plan à date de course. Un programme ouvert n'a ni Spécifique
    /// ni Affûtage : trois segments dont deux resteraient vides décriraient un plan qui n'existe
    /// pas.
    @ViewBuilder private var phaseBar: some View {
        if shape.totalWeeks != nil {
            PhaseProgressBar(phases: [
                PhaseSegment(name: "Base", done: min(profile.weekNumber, shape.baseWeeks), total: shape.baseWeeks, color: RUColor.rose),
                PhaseSegment(name: "Spécifique", done: max(0, min(profile.weekNumber - shape.baseWeeks, shape.specificWeeks)), total: shape.specificWeeks, color: RUColor.rose2),
                PhaseSegment(name: "Affûtage", done: max(0, min(profile.weekNumber - shape.baseWeeks - shape.specificWeeks, shape.taperWeeks)), total: shape.taperWeeks, color: RUColor.violet)
            ])
        } else {
            phaseLegend
        }
    }

    private func volumeBar(_ week: WeekSummary, maxKm: Int) -> some View {
        let isSelected = week.number == selected?.number
        let height = max(5, CGFloat(week.estimatedKm) / CGFloat(maxKm) * 84)
        return Button(action: {
            Haptics.selection()
            withAnimation(.easeOut(duration: 0.2)) { selectedWeek = week.number }
        }) {
            VStack(spacing: 5) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(blockColor(week.block))
                    // Les semaines faites reculent sans disparaître : elles font partie de la
                    // forme — c'est même par elles qu'on voit la progression — mais elles ne sont
                    // plus d'actualité.
                    .opacity(week.isDone ? 0.3 : 1)
                    .frame(height: height)
                // Le repère de la semaine en cours. Il ne dépend pas de la sélection : on doit
                // pouvoir regarder la semaine 12 sans perdre de vue où l'on en est.
                Circle()
                    .fill(week.isCurrent ? RUColor.textPrimary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(RUColor.textPrimary.opacity(0.55), lineWidth: 1.5)
                        .frame(height: height + 8)
                        .padding(.bottom, 5)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(String(localized: "Semaine \(week.number), \(week.block.label), environ \(week.estimatedKm) kilomètres"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// La légende de repli, pour un programme ouvert : ses phases réellement présentes, dans leur
    /// ordre d'apparition. La barre à trois segments ne convient pas là — il n'y a ni Spécifique
    /// ni Affûtage à remplir — mais les couleurs du graphique ont quand même besoin d'être nommées.
    private var phaseLegend: some View {
        var seen: [AdaptivePlanEngine.TrainingBlock] = []
        for week in weekSummaries where !seen.contains(week.block) { seen.append(week.block) }
        return HStack(spacing: 14) {
            ForEach(seen, id: \.rawValue) { block in
                HStack(spacing: 5) {
                    Circle().fill(blockColor(block)).frame(width: 7, height: 7)
                    Text(block.label).font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private func blockColor(_ block: AdaptivePlanEngine.TrainingBlock) -> Color {
        switch block {
        case .base: return RUColor.rose
        case .specifique: return RUColor.rose2
        case .affutage: return RUColor.violet
        case .deload: return RUColor.text3
        }
    }

    // MARK: Le sélecteur de semaine

    /// Deux flèches de 44 pt et le nom de la semaine. Le graphique au-dessus sert à voir et à
    /// sauter ; celui-ci sert à viser — et il donne à VoiceOver un chemin linéaire là où seize
    /// barres n'en donnent pas.
    private var weekNavigator: some View {
        HStack(spacing: 10) {
            navButton(systemName: "chevron.left", enabled: (selected?.number ?? weekRange.lowerBound) > weekRange.lowerBound) {
                step(-1)
            }
            VStack(spacing: 1) {
                Text(selected.map { String(localized: "Semaine \($0.number)") } ?? "")
                    .font(RUFont.sans(.label, weight: .bold))
                    .foregroundColor(RUColor.textPrimary)
                Text(weekSubtitle)
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            navButton(systemName: "chevron.right", enabled: (selected?.number ?? weekRange.upperBound) < weekRange.upperBound) {
                step(1)
            }
        }
    }

    private var weekSubtitle: String {
        guard let week = selected else { return "" }
        if week.isCurrent { return String(localized: "Cette semaine · \(week.block.label)") }
        if week.isDone { return String(localized: "Faite · \(week.block.label)") }
        return String(localized: "À venir · \(week.block.label)")
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? RUColor.textPrimary : RUColor.text4)
                .frame(width: 32, height: 32)
                .background(RUColor.card, in: Circle())
                .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .accessibilityLabel(systemName == "chevron.left"
                            ? String(localized: "Semaine précédente")
                            : String(localized: "Semaine suivante"))
    }

    private func step(_ delta: Int) {
        let next = (selected?.number ?? profile.weekNumber) + delta
        guard weekRange.contains(next) else { return }
        Haptics.selection()
        withAnimation(.easeOut(duration: 0.2)) { selectedWeek = next }
    }

    // MARK: La semaine choisie

    /// Une seule carte, quelle que soit la semaine regardée. Il y en avait trois formes — la
    /// semaine en cours, une ligne dépliable pour les suivantes, la même en plus pâle pour les
    /// passées — pour montrer exactement le même contenu.
    private func weekCard(_ week: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("Semaine \(week.number)")
                        .font(RUFont.sans(.title, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                    blockPill(week.block)
                    Spacer(minLength: 8)
                }
                Text(week.isCurrent
                     ? String(localized: "~\(week.estimatedKm) km · \(completedCount)/\(plannedCount) séances faites")
                     : (week.isDone
                        ? String(localized: "~\(week.estimatedKm) km · résumé type de cette semaine passée")
                        : String(localized: "~\(week.estimatedKm) km · s'ajustera selon ta forme")))
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
            }

            VStack(spacing: 4) {
                ForEach(selectedDays, id: \.0) { letter, day, state in
                    dayRow(letter: letter, day: day, state: state)
                }
            }

            // Le décalage, offert sur la semaine en cours et sur elle seule.
            //
            // C'est la seule semaine qui existe vraiment : `weekSessions` la persiste, les
            // suivantes sont régénérées à chaque affichage. Proposer le geste sur une semaine
            // future donnerait un déplacement effacé à la prochaine ouverture de l'écran, sans
            // que rien ne le signale — pire qu'une fonction absente.
            //
            // Une action nommée sous la liste plutôt qu'une poignée sur chaque ligne : elle se
            // voit, elle s'explique, et elle ne remet pas sur les sept lignes la densité qu'on
            // vient d'en retirer.
            if week.isCurrent && plannedCount > 0 {
                Button(action: { Haptics.selection(); appState.openMoveSession() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock").font(.system(size: 12, weight: .semibold))
                        Text("Déplacer une séance").font(RUFont.sans(.small, weight: .semibold))
                    }
                    .foregroundColor(RUColor.text2)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            } else if !week.isCurrent && !week.isDone {
                // Une semaine à venir ne porte AUCUN déplacement, et sans cette ligne rien ne le
                // dit : on décale une séance cette semaine, on avance d'une semaine, on la
                // retrouve à son ancien jour, et on conclut que le déplacement n'a pas marché.
                //
                // Elle donne aussi le vrai remède. Si le conflit revient chaque semaine, ce ne
                // sont pas les séances qu'il faut déplacer une par une — ce sont les jours de
                // course, qui se règlent une fois pour toutes.
                Button(action: { Haptics.selection(); appState.programSettingsPresented = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                        Text("Cette semaine suit tes jours de course · Les modifier")
                            .font(RUFont.sans(.small, weight: .semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    /// La phrase qui décrit la forme du programme, en bas et en petit : elle est la même toutes
    /// les semaines, et le graphique en haut la montre désormais mieux qu'elle ne la dit.
    @ViewBuilder private var planShapeNote: some View {
        if let total = shape.totalWeeks {
            Text("\(total) semaines en 3 phases, calées sur ta date de course. Le plan s'ajuste chaque semaine selon ta forme — pas séance par séance.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text3).lineSpacing(3)
        } else {
            Text("Programme ouvert, sans date de fin — une semaine plus légère toutes les 4 semaines. Il s'ajuste chaque semaine selon ta forme.")
                .font(RUFont.sans(.small)).foregroundColor(RUColor.text3).lineSpacing(3)
        }
    }

    /// La phase, en pastille, à côté du numéro de la semaine regardée.
    private func blockPill(_ block: AdaptivePlanEngine.TrainingBlock) -> some View {
        Text(block.label)
            .font(RUFont.sans(.small, weight: .bold))
            .tracking(0.2)
            .foregroundColor(RUColor.rose)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RUColor.rose.opacity(0.10), in: Capsule())
    }

    private var completedCount: Int { profile.weekSessions.filter(\.completed).count }
    private var plannedCount: Int { profile.weekSessions.filter { ($0.session?.durationMinutes ?? 0) > 0 }.count }

    /// Rendues par un `Text(String)` nu (elles transitent par un tuple), donc localisées ici :
    /// une abréviation de jour n'est pas la même dans les trois langues.
    private static let dayLetters = [
        String(localized: "Lun"), String(localized: "Mar"), String(localized: "Mer"),
        String(localized: "Jeu"), String(localized: "Ven"), String(localized: "Sam"),
        String(localized: "Dim")
    ]

    private func refreshSelectedDays() {
        selectedDays = selected.map { dayList(for: $0) } ?? []
    }

    private func dayList(for week: WeekSummary) -> [(String, PlannedDay, DayStatus.State?)] {
        if week.isCurrent {
            return profile.weekSessions.map { day in
                (Self.dayLetters[day.weekday], day, profile.weekStrip.first { $0.weekday == day.weekday }?.state)
            }
        }
        let preview = AdaptivePlanEngine.generateWeekSessions(weekNumber: week.number, tier: profile.weekTier, profile: profile)
        return preview.map { (Self.dayLetters[$0.weekday], $0, nil) }
    }

    private func dayRow(letter: String, day: PlannedDay, state: DayStatus.State?) -> some View {
        let session = day.session
        let isRest = session == nil || session?.durationMinutes == 0
        let isToday = state == .today
        let family = isRest ? SessionFamily.rest : (session?.family ?? .endurance)
        return HStack(spacing: 10) {
            Text(letter).font(RUFont.sans(.small, weight: .semibold)).foregroundColor(RUColor.text3).frame(width: 30, alignment: .leading)
            // La bande. Deux pixels et demi de couleur, et la semaine cesse d'être une liste pour
            // devenir une forme : on voit trois séances d'endurance, un fractionné, une sortie
            // longue, sans lire une seule ligne. C'est l'écart le plus net entre notre plan et
            // celui des apps qui se lisent d'un coup d'œil.
            RoundedRectangle(cornerRadius: RUSpacing.radiusBar, style: .continuous)
                .fill(isRest ? Color.clear : family.tint)
                .frame(width: 3, height: 34)
            dayIcon(session: session, isRest: isRest, completed: day.completed, isToday: isToday)
            VStack(alignment: .leading, spacing: 1) {
                Text(session?.displayTitle ?? String(localized: "Repos"))
                    .font(RUFont.sans(.label, weight: isToday ? .semibold : .regular))
                    .foregroundColor(isRest ? RUColor.text3 : RUColor.textPrimary)
                // Le sous-titre ne s'affiche plus que sur la ligne du jour.
                //
                // C'est une phrase de coaching — « installe l'endurance de fond, allure confort » —
                // et elle est tirée d'un petit répertoire : sur sept lignes, elle se répétait
                // presque à l'identique et représentait à elle seule la moitié du texte de la
                // carte. Répétée, elle n'apprend plus rien et fait le gris qui noie les titres ;
                // sur la seule séance qu'on va faire aujourd'hui, elle redevient un conseil. Le
                // détail complet de n'importe quelle séance reste dans `SessionDetailSheet`.
                if isToday, let subtitle = session?.displaySubtitle, !isRest {
                    Text(subtitle).font(RUFont.sans(.small)).foregroundColor(RUColor.text3).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let session, !isRest {
                // Remontées de 10/9 à 11/10 : c'était le plus petit texte de l'app, en gris, en
                // chasse fixe, et il portait les deux chiffres pour lesquels on ouvre la ligne.
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(session.durationMinutes)′ · \(session.zone)").font(RUFont.mono(11)).foregroundColor(RUColor.text2)
                    Text("\(session.pace)/km").font(RUFont.mono(10)).foregroundColor(RUColor.text3)
                }
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 10)
        // `.sesh.active` de la maquette : la ligne du jour se détache par un fond très légèrement
        // teinté + un liseré rose, au lieu d'une puce "aujourd'hui" posée au milieu de la ligne
        // qui poussait le titre de la séance et décalait la colonne durée/allure d'un jour à
        // l'autre. Teinte, pas aplat — l'accent reste un liseré et une icône.
        .background(isToday ? RUColor.rose.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: RUSpacing.radiusChip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RUSpacing.radiusChip, style: .continuous)
                .stroke(isToday ? RUColor.rose.opacity(0.3) : Color.clear, lineWidth: RUSpacing.hairline)
        )
        .contentShape(Rectangle())
        // La maquette déplie le détail de la séance du jour directement sous sa ligne
        // (`.sesh-detail` : échauffement / corps de séance / retour au calme). L'app a déjà mieux
        // que ça — `SessionDetailSheet` dérive cette structure par archétype (footing continu vs
        // fractionné vs tempo, plus les formats HYROX) au lieu du même gabarit pour tout — donc on
        // ouvre cette feuille plutôt que d'en dupliquer une version appauvrie ici. Seule la ligne
        // d'aujourd'hui réagit : c'est la seule séance dont `todaySession` décrit vraiment le
        // contenu.
        .onTapGesture { if isToday { appState.openSessionDetail() } }
        // Chaque ligne était 3 à 5 arrêts VoiceOver sans lien (jour, titre, sous-titre, durée,
        // allure), et "aujourd'hui" / "faite" ne vivaient plus que dans la couleur depuis que la
        // puce et le ✓ ont fusionné dans l'icône de type.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dayRowAccessibilityLabel(day: day, isToday: isToday, isRest: isRest))
        .accessibilityAddTraits(isToday ? .isButton : [])
    }

    /// L'icône `.sesh-icon` de la maquette : une tuile qui annonce le TYPE du jour d'un coup
    /// d'œil, là où il n'y avait qu'une pastille de 6 pt rose ou grise ne distinguant que
    /// "course / repos". Le type vient de `WorkoutSession.isIntervalSession`, la seule
    /// classification que le modèle expose réellement (déjà partagée par `SessionDetailSheet` et
    /// l'écran Live) — aucune catégorie inventée au-delà de repos / endurance / fractionné.
    private func dayIcon(session: WorkoutSession?, isRest: Bool, completed: Bool, isToday: Bool) -> some View {
        let family = isRest ? SessionFamily.rest : (session?.family ?? .endurance)
        // Le ✓ d'une séance faite continue de primer sur le symbole de famille : « c'est fait »
        // répond à une question plus pressante que « c'était quoi ». La couleur, elle, reste celle
        // de la famille — sinon une semaine terminée redevient un mur uniforme.
        let symbol = completed ? "checkmark" : family.symbol
        let tint = family.tint
        return Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 30, height: 30)
            .background(tint.opacity(isRest ? 0.06 : 0.14), in: RoundedRectangle(cornerRadius: RUSpacing.radiusTile, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusTile, style: .continuous).stroke(isToday ? RUColor.rose.opacity(0.35) : RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    private func dayRowAccessibilityLabel(day: PlannedDay, isToday: Bool, isRest: Bool) -> String {
        var parts: [String] = [isToday ? String(localized: "\(DayStatus.fullNames[day.weekday]), aujourd'hui") : DayStatus.fullNames[day.weekday]]
        parts.append(isRest ? String(localized: "repos") : (day.session?.displayTitle ?? String(localized: "repos")))
        if let session = day.session, !isRest {
            parts.append(String(localized: "\(session.durationMinutes) minutes, \(session.zone), allure \(session.pace) par kilomètre"))
        }
        if day.completed { parts.append(String(localized: "séance faite")) }
        return parts.joined(separator: ", ")
    }

    private func paceMinutesPerKm(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
        return m + s / 60
    }

    private func estimatedKm(for sessions: [PlannedDay]) -> Int {
        let total = sessions.compactMap { day -> Double? in
            guard let session = day.session, session.durationMinutes > 0, let paceMin = paceMinutesPerKm(session.pace) else { return nil }
            return Double(session.durationMinutes) / paceMin
        }.reduce(0, +)
        return Int(total.rounded())
    }
}
