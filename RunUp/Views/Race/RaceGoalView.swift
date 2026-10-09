import SwiftUI

/// Race/objective detail — mirrors `RaceScreen` in screensB.jsx. Title/date/pace/prep are all
/// dynamic, computed from the real profile state (race target, `PaceModel`, `AdaptivePlanEngine`)
/// instead of a fixed 10K pacing table shown regardless of the actual goal or distance.
struct RaceGoalView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }
    @State private var jourJOuvert = false
    @State private var jourJTriathlonOuvert = false

    private var shape: AdaptivePlanEngine.ProgramShape {
        AdaptivePlanEngine.ProgramShape.compute(goal: profile.goalId, raceDate: profile.raceDate, from: profile.programStartDate ?? .now)
    }

    private var formatDuTriathlon: TriathlonFormat? {
        profile.triathlonFormat.flatMap(TriathlonFormat.init(rawValue:))
    }

    /// Le temps visé d'un triathlon, en minutes.
    ///
    /// Lu ICI et pas par `PaceModel.parseChronoSeconds` : celui-là décide de l'unité d'après la
    /// DISTANCE de course, et un triathlon n'en a pas — `raceDistance` est nil pour cet objectif.
    /// Il aurait donc lu « 2:35 » comme deux minutes trente-cinq.
    ///
    /// Le format est toujours « H:MM », celui des quatre jeux de temps de finisseur. Tout le
    /// reste — « finir », un texte libre mal formé — rend zéro, et l'écran se tait au lieu
    /// d'afficher des totaux calculés sur rien.
    private var minutesVisees: Int {
        guard let chrono = profile.raceChrono else { return 0 }
        let bouts = chrono.split(separator: ":").compactMap { Int($0) }
        guard bouts.count == 2, bouts[0] >= 0, (0..<60).contains(bouts[1]) else { return 0 }
        return bouts[0] * 60 + bouts[1]
    }

    /// Real target pace (seconds/km) implied by the goal chrono over the goal distance — falls
    /// back to the reference threshold pace `PaceModel` already seeds the plan from when there's
    /// no race chrono (progress/weight/restart/health goals).
    private var racePaceSecPerKm: Double? {
        guard let chrono = profile.raceChrono,
              let km = profile.effectiveRaceDistanceKm,
              let totalSeconds = PaceModel.parseChronoSeconds(chrono, distance: profile.raceDistance),
              km > 0
        else { return nil }
        return totalSeconds / km
    }

    private var targetPaceLabel: String {
        PaceModel.formatDuration(racePaceSecPerKm ?? PaceModel.zones(for: profile).thresholdSecPerKm)
    }

    /// Splits the real goal distance into 3-4 pacing phases around the real target pace, instead
    /// of a fixed "1-3 / 4-8 / 9 / 10 km @ 4:52.../4:20" table that only ever made sense for a 10K.
    private var pacingPlan: [(String, String, String)] {
        let km = profile.effectiveRaceDistanceKm ?? 10
        let base = racePaceSecPerKm ?? PaceModel.zones(for: profile).thresholdSecPerKm
        let totalKm = max(3, Int(km.rounded()))
        let startEnd = max(1, Int((Double(totalKm) * 0.2).rounded()))
        let cruiseEnd = min(totalKm - 1, max(startEnd + 1, Int((Double(totalKm) * 0.75).rounded())))

        func rangeLabel(_ a: Int, _ b: Int) -> String { a == b ? "\(a) km" : "\(a)-\(b) km" }

        var plan: [(String, String, String)] = [
            (rangeLabel(1, startEnd), String(localized: "Départ contrôlé"), PaceModel.formatDuration(base + 8)),
            (rangeLabel(startEnd + 1, cruiseEnd), String(localized: "Rythme cible"), PaceModel.formatDuration(base))
        ]
        if cruiseEnd + 1 < totalKm {
            plan.append((rangeLabel(cruiseEnd + 1, totalKm - 1), String(localized: "Relance"), PaceModel.formatDuration(max(60, base - 5))))
        }
        plan.append((rangeLabel(totalKm, totalKm), String(localized: "Sprint final"), PaceModel.formatDuration(max(60, base - 20))))
        return plan
    }

    /// La stratégie du jour J des formats qui n'ont PAS de tableau d'allure au kilomètre, ou nil
    /// pour une course de route — qui, elle, en a un vrai.
    ///
    /// Deux formats la prennent, pour la même raison et pas pour la même : un HYROX n'est pas une
    /// course continue, et un ultra-trail n'a pas d'allure cible. Dans les deux cas, un découpage
    /// « 1-20 km / 21-75 km / 76-99 km / Sprint final » serait un tableau d'une fausse précision
    /// sur une épreuve qui ne se court pas comme ça. « Sprint final » au centième kilomètre d'un
    /// 100 miles est même l'inverse d'un conseil.
    private var strategieStructurelle: [(String, String)]? {
        switch profile.goalId {
        case .hyrox: return hyroxStrategy
        case .ultraTrail: return ultraStrategy
        default: return nil
        }
    }

    /// Ce qui décide d'un ultra, et aucune de ces quatre lignes n'est une allure.
    private var ultraStrategy: [(String, String)] {
        [
            (String(localized: "Les deux premières heures"), String(localized: "plus lentement que ton envie — en ultra personne ne gagne au départ, beaucoup y perdent")),
            (String(localized: "Les montées"), String(localized: "marche les raides : au-delà d'une certaine pente, marcher coûte moins et va aussi vite. Ce n'est pas un renoncement, c'est la technique")),
            (String(localized: "Les descentes"), String(localized: "elles décident de l'état de tes quadriceps à mi-course — se retenir tôt est ce qui rend la fin possible")),
            (String(localized: "Manger et boire"), String(localized: "à chaque ravitaillement, pas quand le corps réclame : quand il réclame, il est déjà trop tard"))
        ]
    }

    /// Real structural race-day guidance for HYROX — no fake per-km split table (the format isn't
    /// a continuous run), but real pace/effort advice grounded in what actually determines a HYROX
    /// result: running under accumulated station fatigue, not raw running speed alone.
    private var hyroxStrategy: [(String, String)] {
        [
            (String(localized: "Segments course (8 × 1 km)"), String(localized: "vise \(targetPaceLabel) /km sur chaque segment, même sous fatigue — pas l'allure d'un 8 km isolé")),
            (String(localized: "Stations"), String(localized: "technique avant vitesse — un geste propre coûte moins cher qu'un geste rapide et cassé")),
            (String(localized: "Gestion globale"), String(localized: "les 4 premiers km + stations posent le rythme, les 4 derniers décident du chrono"))
        ]
    }

    /// Only goals that periodize toward a date have a real race day with a distance/chrono to
    /// pace against — for `.progress`/`.restart`/`.weight`/`.health` this screen used to show a
    /// "JOURS" countdown to nothing, a fabricated "ALLURE" from `PaceModel`'s generic threshold,
    /// and a full race-day pacing table built on a hardcoded 10 km fallback (`?? 10` above) — all
    /// meaningless for a goal with no actual race.
    ///
    /// `periodiseVersUneDate` et non une liste écrite ici : cette ligne portait `== .race ||
    /// == .hyrox`, donc une préparation d'ultra-trail — qui a pourtant une date, une distance et
    /// un dossard — voyait le compte à rebours d'un objectif ouvert.
    private var hasRealRaceDay: Bool { profile.goalId.periodiseVersUneDate }

    /// Le dénivelé de la course, pour la troisième tuile d'un ultra.
    ///
    /// C'est LUI et non une allure. Pour un 100 km en vingt heures, « 12:00 /km » est un nombre
    /// juste et inutile : personne ne court un ultra à une allure cible, et l'afficher sous le
    /// mot ALLURE invite à la viser. Le D+ est ce qu'on relit avant de partir.
    private var deniveleLabel: String? {
        guard let d = profile.raceElevationGainM, d > 0 else { return nil }
        // L'unité est dans la VALEUR et non dans l'étiquette : « D+ » s'écrit pareil dans les
        // trois langues de l'app, donc l'étiquette n'a rien à traduire.
        return "\(d) m"
    }

    private var goalTitle: String {
        profile.goalDisplay.contains("·") ? String(profile.goalDisplay.split(separator: "·").first ?? "").trimmingCharacters(in: .whitespaces) : profile.goalDisplay
    }

    private var goalTarget: String {
        guard let part = profile.goalDisplay.split(separator: "·").last else { return profile.goalDisplay }
        return String(part).trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BackTitleHeaderView(eyebrow: "Ton objectif", title: goalTitle, titleSize: 24) { appState.go(.profile) }
                Text(dateLine).font(RUFont.sans(.body)).foregroundColor(RUColor.text2).padding(.leading, 34)

                if hasRealRaceDay {
                    HStack(spacing: 10) {
                        tile(profile.daysUntilRace.map(String.init) ?? "—", String(localized: "JOUR\((profile.daysUntilRace ?? 2) > 1 ? "S" : "")"), highlighted: true)
                        tile(goalTarget, "OBJECTIF", highlighted: false)
                        if let deniveleLabel {
                            tile(deniveleLabel, "D+", highlighted: false)
                        } else {
                            tile(targetPaceLabel, "ALLURE", highlighted: false)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        tile("\(profile.weekNumber)", "SEMAINE", highlighted: true)
                        tile(goalTarget, "OBJECTIF", highlighted: false)
                        tile("\(profile.streak)", "SÉRIE", highlighted: false)
                    }
                }

                // LA FORME DU PLAN SE VEND, ET ELLE ÉTAIT DONNÉE ICI. L'accueil supprime la
                // carte du programme sans abonnement, le Plan floute sa forme derrière un
                // `PlusSection` — et cet écran, atteignable en permanence depuis la pastille
                // d'objectif du Profil, affichait en clair « Semaine 4/16 », la barre de
                // progression et Base / Spécifique / Affûtage avec l'état réel de chaque bloc.
                // C'est mot pour mot ce que l'argumentaire vend. Soit le verrou de l'accueil
                // mentait, soit cet écran fuyait ; c'était le second.
                //
                // Ce qui reste libre : le titre de l'objectif, la date et les trois tuiles. La
                // ligne est celle qu'a déjà tracée l'accueil — la séance du jour reste gratuite,
                // la FORME du plan se vend.
                PlusSection(feature: .adaptivePlan, teaserHeight: 140) {
                VStack(spacing: 10) {
                    HStack {
                        RUCardHeader(icon: "calendar", tint: RUColor.rose, title: "Préparation")
                        if let total = shape.totalWeeks {
                            StatChip(text: String(localized: "Semaine \(min(profile.weekNumber, total))/\(total)"), color: RUColor.lime)
                        }
                    }
                    if let total = shape.totalWeeks {
                        LinearBar(fraction: min(1, Double(profile.weekNumber) / Double(total)), color: RUColor.rose, height: 8, gradient: LinearGradient(colors: [RUColor.rose, RUColor.lime], startPoint: .leading, endPoint: .trailing))
                        HStack {
                            phaseLabel(String(localized: "Base"), state: phaseState(endWeek: shape.baseWeeks))
                            Spacer()
                            phaseLabel(String(localized: "Spécifique"), state: phaseState(endWeek: shape.baseWeeks + shape.specificWeeks))
                            Spacer()
                            phaseLabel(String(localized: "Affûtage"), state: phaseState(endWeek: total))
                        }
                    } else {
                        Text("Programme ouvert, sans date de fin fixe.")
                            .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    }
                }
                .padding(RUSpacing.cardPadding)
                .ruCard()
                }

                // A per-km pacing table with a "Sprint final" phase only makes sense for a
                // continuous road-race distance — HYROX alternates running with functional
                // stations, so it gets its own honest, structural strategy instead of a fake
                // per-km split table over a format that isn't a straight run.
                if !hasRealRaceDay {
                    VStack(alignment: .leading, spacing: 8) {
                        RUCardHeader(icon: "location.fill", tint: RUColor.violet, title: "Où tu en es")
                        Text(LocalizedStringKey(progressSummary))
                            .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
                    }
                    .padding(RUSpacing.cardPadding)
                    .ruCard()
                } else if let strategie = strategieStructurelle {
                    RUCardHeader(icon: "flag.checkered", tint: RUColor.rose2, title: "Stratégie · jour J")
                    VStack(spacing: 6) {
                        ForEach(strategie.indices, id: \.self) { i in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: RUSpacing.radiusBar).fill(RUColor.text4).frame(width: 3, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(strategie[i].0).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                    Text(strategie[i].1).font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(2)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                        }
                    }
                    // LES TROIS AUTRES QUESTIONS, CELLES QUE LE PLAN NE POSE PAS. Un ultra se perd
                    // au ventre, au contrôle du sac et à trois heures du matin bien plus souvent
                    // qu'aux jambes, et aucune des quatre lignes ci-dessus n'en parle.
                    if profile.goalId == .ultraTrail {
                        Button { jourJOuvert = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(RUColor.violet)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Ravitaillement, matériel, la nuit")
                                        .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                    Text("Ce que le plan ne te dit pas, et qui décide autant")
                                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(RUColor.text3)
                            }
                            .padding(RUSpacing.cardPadding)
                            .ruCard()
                        }
                        .buttonStyle(PressableStyle())
                    }
                    // LA MÊME PORTE POUR LE TRIATHLON, et pour la même raison : le plan dit quoi
                    // faire cette semaine, et rien de la JOURNÉE. Un triathlon se perd au ventre
                    // — on ne mange pas dans l'eau, et tout ce qu'il faudra pour la course se
                    // prend sur le vélo — et en transition, qui pèse près d'un dixième d'un
                    // format court.
                    if profile.goalId == .triathlon, let format = formatDuTriathlon {
                        Button { jourJTriathlonOuvert = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(RUColor.violet)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Ravitaillement, transitions, combinaison")
                                        .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                    Text("Ce que le plan ne te dit pas, et qui décide autant")
                                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(RUColor.text3)
                            }
                            .padding(RUSpacing.cardPadding)
                            .ruCard()
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityHint(Text(format.resume))
                    }
                } else {
                    RUCardHeader(icon: "speedometer", tint: RUColor.rose2, title: "Stratégie d'allure · jour J")
                    VStack(spacing: 6) {
                        ForEach(pacingPlan.indices, id: \.self) { i in
                            let isLast = i == pacingPlan.count - 1
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: RUSpacing.radiusBar).fill(isLast ? RUColor.rose : RUColor.text4).frame(width: 3, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pacingPlan[i].1).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                    Text(pacingPlan[i].0).font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                                }
                                Spacer()
                                (Text(pacingPlan[i].2).font(RUFont.display(18)).foregroundColor(isLast ? RUColor.rose2 : RUColor.textPrimary)
                                    + Text(verbatim: " /km").font(RUFont.sans(.micro)).foregroundColor(RUColor.text2))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                        }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .sheet(isPresented: $jourJOuvert) {
            UltraRaceDaySheet(tempsDeffortSecondes: AdaptivePlanEngine.tempsDeffortCourse(profile))
                .runUpSheetStyle()
        }
        .sheet(isPresented: $jourJTriathlonOuvert) {
            if let format = formatDuTriathlon {
                TriathlonRaceDaySheet(format: format, minutesVisees: minutesVisees)
                    .runUpSheetStyle()
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private var progressSummary: String {
        switch profile.goalId {
        case .weight: return "Pas de date fixe pour ce genre d'objectif — le programme ajuste ton volume semaine après semaine pour que la charge reste tenable dans la durée."
        case .health: return "Pas de course à préparer ici — le coach cale un rythme régulier, adapté à ta forme du jour, pour construire l'habitude sur la durée."
        case .restart: return "Reprise en douceur : le programme remonte le volume progressivement pour éviter la blessure, avant de repartir sur un rythme plus soutenu."
        default: return "Objectif ouvert, sans date de fin fixe — le programme continue de progresser semaine après semaine selon ta forme."
        }
    }

    private var dateLine: String {
        guard let date = profile.raceDate else { return String(localized: "Date à définir") }
        return Self.dateFormatter.string(from: date)
    }

    private enum PhaseState { case done, current, upcoming }

    /// A phase reads "done" once the program has moved past its last week, "current" while the
    /// program is inside it, "upcoming" otherwise — replaces a fixed "Base ✓ / Spécifique ● /
    /// Affûtage" that never actually reflected which block the program was in.
    private func phaseState(endWeek: Int) -> PhaseState {
        if profile.weekNumber > endWeek { return .done }
        let block = AdaptivePlanEngine.trainingBlock(forWeek: profile.weekNumber, shape: shape)
        let isCurrent = (block == .base && endWeek == shape.baseWeeks)
            || (block == .specifique && endWeek == shape.baseWeeks + shape.specificWeeks)
            || (block == .affutage && endWeek == (shape.totalWeeks ?? endWeek))
        return isCurrent ? .current : .upcoming
    }

    private func phaseLabel(_ name: String, state: PhaseState) -> some View {
        let suffix: String
        switch state {
        case .done: suffix = " ✓"
        case .current: suffix = " ●"
        case .upcoming: suffix = ""
        }
        return Text("\(name)\(suffix)").font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
    }

    private func tile(_ value: String, _ label: String, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            // Free-text values ("Sous 1h30", a custom chrono) must shrink in a third-of-screen
            // tile, not wrap or clip on 320-375pt phones.
            Text(value).displayStyle(30).foregroundColor(highlighted ? RUColor.rose2 : RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .padding(.horizontal, 6)
            // Was a bare `Text(label)` — never resolved through the String Catalog (pre-existing
            // gap on JOURS/OBJECTIF/ALLURE too), fixed in passing since this function was already
            // touched for the new SEMAINE/SÉRIE tiles.
            Text(LocalizedStringKey(label)).font(RUFont.sans(.micro, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(highlighted ? RUColor.card2 : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusLarge, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusLarge, style: .continuous).stroke(highlighted ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
    }
}
