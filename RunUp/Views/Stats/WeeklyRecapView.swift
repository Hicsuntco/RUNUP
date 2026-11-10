import SwiftUI
import SwiftData

/// A dedicated "your week" moment — Strava's weekly email, but a full native screen reachable from
/// tapping the Sunday-evening local notification (`NotificationService.scheduleWeeklyRecapReminder`)
/// or the "Cette semaine" card in `StatsView`. `StatsView.weekCard` already surfaces this week's km
/// inline among many other trend cards; this exists because a recurring re-engagement push needs
/// somewhere worth actually opening — a real recap, not just a redirect back into the Stats tab.
/// Visual structure modeled on the "BILAN · ta semaine" reference (RUNUP 4.0 mockup, concept A ·
/// Midnight Rose): a colored 2×2 stat grid instead of one oversized hero number, a volume-per-day
/// bar chart, and a real personal-record callout — same 3 real metrics (km/séances/temps actif/
/// série) as before, no new data invented to match the mockup's own (different) stat set.
struct WeeklyRecapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La pastille d'écart flotte dans un coin — sauf aux tailles d'accessibilité, où elle
    /// passe dans le flux. Voir `statTile`.
    @Environment(\.dynamicTypeSize) private var tailleDuTexte
    @Query(sort: \RunRecord.date, order: .reverse) private var allRuns: [RunRecord]
    @State private var chartRevealed = false
    private var profile: UserProfile { appState.profile }

    /// LE CALCUL VIT DANS `BilanDeLaSemaine`, ET C'EST TOUT L'OBJET DE CE CHANTIER.
    ///
    /// Cet écran portait cinq définitions différentes de « la semaine », dans cinq propriétés
    /// privées d'une vue SwiftUI — donc aucune n'était vérifiable, et deux se contredisaient sur
    /// le même écran. Le détail de chacune est en tête de `BilanDeLaSemaine`, avec la règle qui
    /// les tranche : les kilomètres ne s'additionnent pas entre disciplines, le temps si.
    private var bilan: BilanDeLaSemaine {
        BilanDeLaSemaine(historique: allRuns, semaine: AdaptivePlanEngine.currentWeekRange())
    }

    private var weekDateRangeLabel: String {
        let start = bilan.semaine.lowerBound
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(start.formatted(.dateTime.day().locale(Locale.current)))-\(end.formatted(.dateTime.day().month(.wide).locale(Locale.current)))"
    }

    private var todayWeekdayIndex: Int { WidgetWeekDay.rangDuJour(.now) }

    /// Le libellé et la valeur du record, dans la langue courante. La décision de savoir s'il y
    /// EN A un appartient au bilan ; l'écrire appartient à la vue.
    private var recordAffiche: (label: String, value: String)? {
        switch bilan.record {
        case nil:
            return nil
        case .allure(let secParKm, let km):
            return (String(localized: "Nouveau record d'allure"),
                    String(localized: "\(PaceModel.formatDuration(secParKm))/km sur \(String(format: "%.1f", locale: Locale.current, km)) km"))
        case .distance(let km):
            return (String(localized: "Nouveau record de distance"),
                    String(format: "%.1f km", locale: Locale.current, km))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Was a hand-rolled copy of `BackTitleHeaderView` — the exact same
                // `HStack(spacing: 12) { BackChevronButton; VStack(spacing: 1) { eyebrow; title } }`
                // the component already renders, down to the 24pt title. Identical output (the
                // component adds a trailing `Spacer()`, which changes nothing inside a leading-
                // aligned VStack), and it picks up the catalog lookup the component does on its
                // title for free — both strings below are already keys in Localizable.xcstrings,
                // and a bare `Text(String)` never resolves through it (see `EyebrowLabel`).
                BackTitleHeaderView(
                    eyebrow: String(localized: "Semaine \(profile.weekNumber) · \(weekDateRangeLabel)"),
                    title: bilan.estLaMeilleureSemaine ? "Ta meilleure semaine" : "Bilan de la semaine",
                    titleSize: .title
                ) {
                    appState.go(.stats)
                }

                statsGrid

                volumeChart

                if let recordAffiche {
                    recordCard(recordAffiche)
                }

                if let allure = bilan.allureMoyenneSecParKm {
                    // LA VALEUR EST L'ACCESSOIRE DE L'EN-TÊTE, et non un voisin dans une pile.
                    //
                    // C'était `HStack { RUCardHeader; Text }`. Deux conséquences, les deux vues
                    // sur la capture en grand texte du 8 novembre : le titre, qui porte
                    // `lineLimit(1)`, rendait « Allure moy… » faute de place ; et VoiceOver
                    // lisait deux arrêts — le nom de la mesure, puis, séparément, un nombre.
                    // Confié au composant, le titre passe au-dessus de sa valeur au deuxième
                    // cran d'accessibilité, et les deux se lisent d'un seul tenant.
                    RUCardHeader(icon: "speedometer", title: "Allure moyenne") {
                        Text(verbatim: "\(PaceModel.formatDuration(allure))/km")
                            .displayStyle(.subtitle)
                            .foregroundColor(RUColor.textPrimary)
                    }
                    .padding(18)
                    .ruCard()
                }

                RUCardHeader(icon: "figure.run", title: "Courses de la semaine").padding(.top, 6)

                // La liste montre TOUT ce qu'elle a fait, et c'est écrit : un bilan de semaine
                // qui cacherait la sortie vélo du mardi ne serait pas un bilan de la semaine.
                if bilan.seances.isEmpty {
                    RUEmpty(forme: .ligne,
                            message: String(localized: "Pas encore de course cette semaine — tu as le temps."))
                        .padding(18)
                        .ruCard()
                } else {
                    VStack(spacing: 8) {
                        ForEach(bilan.seances) { run in
                            runRow(run)
                        }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, RUSpacing.tabBarBottomInset + RUSpacing.tabBarHeight + 62)
        }
        .background(RUColor.pageBackground)
        .onAppear {
            // The one genuinely verified achievement moment on this screen (a real best week, or
            // a real PR) — deserves a stronger confirmation than the plain page-open every other
            // stats screen gets.
            if bilan.estLaMeilleureSemaine || bilan.record != nil { Haptics.success() }
        }
    }

    /// 2×2 grid of equally-weighted stats, each its own color — replaces the old single oversized
    /// "distance totale" hero + a plain row of metrics underneath, matching the mockup's stat
    /// grid where the km figure is one cell among four, not a standalone hero.
    private var statsGrid: some View {
        let totalKm = bilan.kilometres
        let deltaKm = totalKm - bilan.kilometresSemainePrecedente
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(value: String(format: "%.1f", locale: Locale.current, totalKm), unit: "km", label: String(localized: "Parcourus"),
                         // L'UNITÉ, PARCE QUE SANS ELLE LE NOMBRE NE DIT RIEN. La pastille
                         // affichait « ▼ 16,6 » à côté de « 14,1 km » : un écart en
                         // KILOMÈTRES posé contre un total en kilomètres, sans rien pour les
                         // distinguer — et le premier réflexe est de le lire comme un
                         // pourcentage. Vu en regardant la capture de l'écran, pas en relisant
                         // le code.
                         chip: bilan.kilometresSemainePrecedente > 0 ? (deltaKm >= 0 ? "▲ \(String(format: "%.1f", locale: Locale.current, deltaKm)) km" : "▼ \(String(format: "%.1f", locale: Locale.current, -deltaKm)) km") : nil,
                         chipColor: deltaKm >= 0 ? RUColor.lime : RUColor.amber)
                // `.allDisciplines` ET NON `weekRuns` NU. Le compte porte bien sur tout — une
                // séance est une séance, qu'elle se courre, se roule ou se nage — mais
                // `RunRecordDiscipline` demande que « toutes » soit une décision ÉCRITE et non
                // l'absence de décision, et c'est exactement ce qui manquait aux quatre autres
                // agrégations de cet écran.
                statTile(value: "\(bilan.nombreDeSeances)", unit: nil, label: String(localized: "Séances"), chip: nil, chipColor: RUColor.lime)
            }
            HStack(spacing: 10) {
                statTile(value: PaceModel.formatTotalDuration(bilan.secondesActives), unit: nil, label: String(localized: "Temps actif"), chip: nil, chipColor: RUColor.cyan)
                statTile(value: "\(profile.streak)", unit: String(localized: "j"), label: String(localized: "Série"), chip: nil, chipColor: RUColor.amber)
            }
        }
    }

    /// LE BILAN HEBDOMADAIRE AVAIT SON PROPRE SYSTÈME, ET C'EST LA PREMIÈRE CAPTURE QUI L'A DIT.
    ///
    /// Cet écran n'avait jamais été photographié — `AppScreen` l'expose, le harnais ne le
    /// demandait pas. Sur l'image, ses quatre tuiles portent QUATRE couleurs : 8,1 en rose,
    /// 1 en vert, 42 min en turquoise, 23 j en ambre. Et leurs libellés sont en capitales
    /// espacées quand les tuiles de l'écran Stats, qui montrent les mêmes mesures, viennent de
    /// passer en minuscules grises.
    ///
    /// Deux écrans qui disent la même chose de deux façons : c'est précisément ce qui fait
    /// qu'une app se lit comme un assemblage. Le chiffre reprend l'encre du texte, le libellé
    /// reprend la micro-étiquette du système. Les couleurs sémantiques restent où elles
    /// servent — la pastille d'écart « ▼ 19,6 km » garde son ambre, parce que l'ambre y veut dire
    /// « moins bien que la semaine passée ».
    private func statTile(value: String, unit: String?, label: String, chip: String?, chipColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            RUChiffre(valeur: value, unite: unit)
            Text(label)
                .font(RUFont.sans(.small, weight: .medium))
                .foregroundColor(RUColor.text3)
                .lineLimit(1).minimumScaleFactor(0.8)
            if let chip, tailleDuTexte.isAccessibilitySize {
                StatChip(text: chip, color: chipColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RUSpacing.cardPadding)
        .ruCard()
        // Floats in a corner instead of sharing the vertical flow, so the one tile that has a
        // chip (the km delta vs. last week) doesn't push its own number down relative to the
        // other 3 tiles that don't.
        //
        // ── SAUF AUX TAILLES D'ACCESSIBILITÉ, OÙ LE COIN N'EST PLUS LIBRE ────────────────
        //
        // Au deuxième cran, « 14,1 » occupe toute la largeur de la tuile et la pastille lui
        // passait dessus : les deux se chevauchaient, le chiffre et son écart. Vu sur la
        // capture en grand texte.
        //
        // Elle rejoint alors le flux, sous le libellé. L'argument d'origine — ne pas décaler
        // ce chiffre-là par rapport aux trois autres — tient aux tailles ordinaires, où les
        // quatre tuiles s'alignent ; à ce cran-là, chaque tuile est déjà plus haute que large
        // et l'alignement ne se lit plus de toute façon.
        //
        // C'est aussi ce que fait déjà l'écran Stats, qui montre le MÊME écart dans le flux,
        // et avec son unité — « ▼ 16,6 km ». Deux écrans, un seul traitement.
        .overlay(alignment: .topTrailing) {
            if let chip, !tailleDuTexte.isAccessibilitySize {
                StatChip(text: chip, color: chipColor).padding(8)
            }
        }
    }

    private var volumeChart: some View {
        let bars = bilan.kilometresParJour
        let maxBar = max(bars.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            RUCardHeader(icon: "chart.bar.fill", title: "Volume par jour (km)")
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(bars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: RUSpacing.radiusBar)
                        // ── LA COULEUR SUIT LA DONNÉE, PAS LA DATE ───────────────────────────
                        //
                        // Le dégradé était accroché à AUJOURD'HUI. Sur la première capture de
                        // cet écran, ça donnait exactement l'inverse de ce qu'un graphique doit
                        // faire : mercredi, 0 km et jour courant, en rose vif ; lundi, 8,1 km et
                        // seule vraie donnée de la semaine, en gris. La seule couleur de la
                        // carte désignait la barre VIDE, et l'œil, qui lit le rose comme « c'est
                        // ça qu'il faut regarder », tombait sur un trait de quatre points. Ça
                        // ressemblait à une panne ; c'était un barème.
                        //
                        // Et le gris n'était pas n'importe lequel : `RUColor.line`, le jeton des
                        // FILETS de séparation, employé comme remplissage d'une barre de soixante
                        // points. Un jeton hors de son emploi, comme les teintes d'icône.
                        //
                        // Désormais : une barre qui porte des kilomètres prend l'accent, une
                        // barre vide prend `card2` — la sous-surface, donc « un emplacement sans
                        // rien dedans ». Aujourd'hui se marque sous l'axe, sur sa lettre.
                        .fill(
                            bars[i] > 0
                                ? AnyShapeStyle(RUColor.rose)
                                : AnyShapeStyle(RUColor.card2)
                        )
                        // Bars grow up from the baseline day-by-day on appear — same "revealed,
                        // not pre-drawn" treatment the Recap splits and the Home ring already get.
                        .frame(height: chartRevealed ? max(4, bars[i] / maxBar * 60) : 4)
                        .frame(maxWidth: .infinity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(Double(i) * 0.05), value: chartRevealed)
                        // No per-day km value was exposed, and "today" (when this week includes
                        // it) was marked by color alone.
                        .accessibilityLabel(i == todayWeekdayIndex ? String(localized: "\(DayStatus.fullNames[i]), aujourd'hui") : DayStatus.fullNames[i])
                        .accessibilityValue("\(String(format: "%.1f", locale: Locale.current, bars[i])) km")
                }
            }
            .frame(height: 60, alignment: .bottom)
            .onAppear { chartRevealed = true }
            HStack {
                // PAR INDICE, ET PAS PAR LA LETTRE. `DayStatus.letters` contient deux « M »
                // (mardi, mercredi) : un `ForEach(…, id: \.self)` sur ces lettres donne deux
                // éléments de même identité, ce que SwiftUI n'a pas le droit de départager —
                // il recycle, saute ou anime de travers, sans rien signaler.
                ForEach(DayStatus.letters.indices, id: \.self) { i in
                    Text(DayStatus.letters[i])
                        .font(RUFont.sans(.micro, weight: .bold))
                        // C'est ici qu'« aujourd'hui » se marque, maintenant que la barre dit la
                        // donnée : sous l'axe, sur la lettre du jour.
                        .foregroundColor(i == todayWeekdayIndex ? RUColor.rose : RUColor.text3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .ruCard()
    }

    /// La `.pr-banner` de la maquette : médaillon circulaire teinté avec un trophée, titre en
    /// gras, valeur en sous-titre. L'emoji 🏅 rendait la seule vraie récompense de l'écran plus
    /// petite et moins nette que n'importe quelle icône de l'app (un emoji ne suit ni le poids ni
    /// la couleur d'accent, et son rendu change d'une version d'iOS à l'autre) ; le médaillon lui
    /// donne la présence d'une banderole. Teinte rose comme la maquette — c'est l'accent de
    /// l'app, et le violet servait ici sans raison particulière.
    private func recordCard(_ record: (label: String, value: String)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(RUFont.icone(.large, weight: .medium))
                .foregroundColor(RUColor.rose)
                .frame(width: 30)
                // Sans son disque teinté : le rose reste au trophée.
            VStack(alignment: .leading, spacing: 2) {
                Text(record.label).font(RUFont.sans(.label, weight: .bold)).foregroundColor(RUColor.textPrimary)
                // No "+120 XP" suffix — no record-specific XP is ever granted (the 120 is the
                // ordinary per-debrief award), so the label promised a bonus that doesn't exist.
                Text(record.value)
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        // Surface neutre : l'accent reste au texte et à l'icône. Un rose
        // dilué donne sa version sale, et le contour de la même couleur la redisait.
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
        // Le trophée et le fond teinté sont décoratifs ; sans regroupement, VoiceOver lit le
        // libellé et sa valeur comme deux arrêts, sans dire qu'il s'agit d'un record.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.label), \(record.value)")
    }

    /// Le rythme d'une séance dans l'unité de SA discipline. Vide quand l'allure enregistrée
    /// n'est pas lisible — une sortie saisie sans durée n'a pas de rythme, et « 0:00/km » serait
    /// un chiffre inventé.
    private func rythmeAffiche(_ run: RunRecord) -> String {
        guard let secParKm = PaceModel.parseSecPerKm(run.avgPace), secParKm > 0 else { return "" }
        let (valeur, unite) = TimeFormat.rythme(run.discipline, secondesParKm: secParKm)
        return "\(valeur) \(unite)"
    }

    private func runRow(_ run: RunRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                // `titreAffiche` : voir `HistoryView`, oublié ici pour la même raison.
                Text(run.titreAffiche).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                Text(run.date.formatted(.dateTime.weekday(.wide).day().month().locale(Locale.current))).font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
            }
            Spacer()
            Text(String(format: "%.2f km", locale: Locale.current, run.distanceKm)).font(RUFont.mono(.body)).foregroundColor(RUColor.text2)
            // `TimeFormat.rythme` ET NON `avgPace + "/km"`. Le champ est stocké en secondes au
            // kilomètre pour toutes les disciplines ; c'est ce formateur qui le relit dans l'unité
            // que la discipline AFFICHE — au kilomètre à pied, aux cent mètres en bassin, en km/h
            // à vélo. Cette ligne écrivait « 3:00/km » sous une sortie vélo.
            Text(verbatim: rythmeAffiche(run)).font(RUFont.mono(.body)).foregroundColor(RUColor.text2)
        }
        .padding(RUSpacing.cardPadding)
        .ruCard(radius: RUSpacing.radiusCard)
    }
}
