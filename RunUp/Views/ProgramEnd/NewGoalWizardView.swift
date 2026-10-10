import SwiftUI

/// Condensed 3-step new-goal wizard (goal → race details → days → building). Mirrors
/// `NewGoalFlow` in screensD.jsx.
struct NewGoalWizardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var goal: GoalType?
    @State private var distance: RaceDistance = .k10
    @State private var chrono: String = RaceDistance.k10.chronoPresets[1]
    @State private var raceDate = Calendar.current.date(byAdding: .day, value: 60, to: .now)!
    /// Le D+ de la course, saisi en texte libre — même champ, mêmes règles qu'à l'inscription :
    /// vide et zéro sont la même réponse, « je ne sais pas ».
    @State private var raceElevationGain: String = ""
    /// Le format du triathlon, et ce qu'elle nage aujourd'hui.
    ///
    /// Le format a une valeur par défaut — l'olympique, le plus couru — et le niveau de natation
    /// n'en a PAS, volontairement : c'est ce qui le rend obligatoire. Même règle qu'à
    /// l'inscription, et pour la même raison (voir `NiveauDeNage`) : c'est la seule réponse de
    /// cet écran dont une valeur supposée peut faire du mal.
    @State private var triathlonFormat: TriathlonFormat = .olympique
    /// Le format du duathlon. Pas de compagnon « niveau de vélo » : l'app mesure le vélo,
    /// donc il n'y a rien à demander dessus. Voir `DuathlonFormat`.
    @State private var duathlonFormat: DuathlonFormat = .standard
    @State private var nageNiveau: NiveauDeNage?
    @State private var days: Set<Int> = [1, 2, 4, 6]
    @State private var building = false
    @State private var buildPct: Double = 0
    /// Séparé de `buildPct`, et c'est tout l'objet du correctif ci-dessous.
    @State private var buildFinished = false
    private static let buildDuration: Double = 2.2

    private let goals: [GoalType] = GoalType.allCases.filter { $0 != .restart && $0.estProposable }

    /// L'étape « ta course » sert à la course ET à l'ultra — un ultra-trail EST une course, avec
    /// une question de plus. Sans ce branchement, choisir « Préparer un ultra-trail » ici sautait
    /// directement aux jours de la semaine : ni distance, ni date, ni dénivelé. Le plan produit
    /// n'avait alors aucune ligne d'arrivée à viser, donc ni bloc spécifique ni affûtage.
    private var estCourseOuUltra: Bool { goal == .race || goal == .ultraTrail }
    private var estTriathlon: Bool { goal == .triathlon }
    private var estDuathlon: Bool { goal == .duathlon }
    /// Le minimum exigé par l'objectif en cours de choix. Voir `GoalType.joursMinimumParSemaine`.
    private var minimumJours: Int { goal?.joursMinimumParSemaine ?? 2 }
    /// Les trois objectifs qui ont une deuxième étape. `periodiseVersUneDate` dit presque la
    /// même chose et pas tout à fait : HYROX a une date et n'a jamais eu d'étape ici, son format
    /// étant fixe. Garder les deux notions distinctes évite de donner au triathlon la mauvaise
    /// étape le jour où HYROX en gagnerait une.
    private var aUneDeuxiemeEtape: Bool { estCourseOuUltra || estTriathlon || estDuathlon }

    /// Les formats à proposer, selon l'objectif. « Autre distance » n'en fait pas partie : cet
    /// assistant n'a pas de champ de texte libre, contrairement à l'inscription.
    private var formats: [RaceDistance] { RaceDistance.choix(pour: goal).filter { $0 != .other } }

    /// Le D+ exigé pour un ultra, et seulement pour lui — même règle qu'à l'inscription.
    private var deniveleManquant: Bool {
        goal == .ultraTrail && (Int(raceElevationGain.trimmingCharacters(in: .whitespaces)) ?? 0) <= 0
    }

    /// Le niveau de natation exigé pour un triathlon, et seulement pour lui — même forme que le
    /// dénivelé juste au-dessus, et même raison : sans ce nombre le plan ne peut pas dimensionner
    /// la seule discipline qu'il ne saura jamais mesurer.
    private var nageManquante: Bool { estTriathlon && nageNiveau == nil }

    @Environment(SubscriptionService.self) private var subscriptions

    var body: some View {
        ZStack {
            RUColor.bg.ignoresSafeArea()
            if !subscriptions.unlocks(.raceGoal) {
                // Se fixer une nouvelle course, c'est demander à RUNUP de construire une
                // périodisation — base, spécifique, affûtage, calée sur une date. C'est
                // exactement ce que Plus vend. L'objectif DÉJÀ en cours, lui, reste consultable :
                // on ne reprend pas ce qui a été donné.
                //
                // L'EN-TÊTE VIT ICI AUSSI, ET C'EST LA CORRECTION. Cette branche n'en avait
                // aucun — ni croix, ni chevron — et l'écran est un `fullScreenCover`, donc pas
                // renvoyable au doigt. Une personne non abonnée qui touchait « Refaire un
                // programme » tombait sur une carte de vente dont on ne sortait QU'EN TUANT
                // L'APP. Et la seconde porte était pire : programme terminé, l'app lui demande
                // de choisir la suite, et l'écran du choix se referme sur elle.
                VStack(alignment: .leading, spacing: 16) {
                    BackTitleHeaderView(title: "Nouvel objectif", titleSize: 20) { dismiss() }
                        .padding(.top, 8)
                    ScrollView { PlusLockCard(feature: .raceGoal) }
                }
                .padding(.horizontal, RUSpacing.pagePadding)
            } else if building {
                buildingView
            } else {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BackTitleHeaderView(title: "Nouvel objectif", titleSize: 20) {
                    if step == 0 { dismiss() } else { step -= 1 }
                }
                .padding(.top, 8)

                switch step {
                case 0: goalStep
                case 1 where estCourseOuUltra: raceStep
                case 1 where estTriathlon: triathlonStep
                case 1 where estDuathlon: duathlonStep
                default: daysStep
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.bottom, 40)
        }
    }

    private var goalStep: some View {
        VStack(spacing: 8) {
            ForEach(goals) { g in
                SelectableCard(selected: goal == g, emoji: g.emoji, title: g.title, subtitle: nil) { goal = g }
            }
            Button("CONTINUER") { step = aUneDeuxiemeEtape ? 1 : 2 }
                .buttonStyle(PrimaryButtonStyle(isDisabled: goal == nil))
                .disabled(goal == nil)
                .padding(.top, 8)
        }
        // Sur le VStack et non sur chaque carte : posé dans le `ForEach`, ce modificateur serait
        // installé une fois par objectif et se déclencherait autant de fois à chaque choix.
        //
        // Les formats d'ultra et ceux de route ne se mélangent jamais : garder « 10 km »
        // sélectionné après avoir choisi l'ultra-trail aurait fait construire une préparation de
        // cent kilomètres de montagne sur dix kilomètres de route.
        .onChange(of: goal) { _, nouveau in
            // Le triathlon ne se mesure pas en distances de course : son chrono vient du FORMAT.
            // Sans cette branche, choisir « triathlon » laissait un temps de 10 km sélectionné,
            // et le plan se serait affûté vers 47 minutes pour une épreuve de trois heures.
            if nouveau == .triathlon {
                chrono = triathlonFormat.chronoPresets[safe: 1] ?? ""
            }
            // Même raison pour le duathlon : son chrono vient du FORMAT, pas d'une distance de
            // course. Sans cette branche, le choisir laisserait un temps de 10 km sélectionné.
            if nouveau == .duathlon {
                chrono = duathlonFormat.chronoPresets[safe: 1] ?? ""
                return
            }
            guard let premier = RaceDistance.choix(pour: nouveau).first else { return }
            distance = premier
            chrono = premier.chronoPresets[safe: 1] ?? ""
        }
    }

    private var raceStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Distance", color: RUColor.text3).padding(.bottom, 10)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(formats, id: \.self) { d in
                    Button(action: { distance = d; chrono = d.chronoPresets[safe: 1] ?? "" }) {
                        Text(d.label).displayStyle(20).foregroundColor(distance == d ? RUColor.rose2 : RUColor.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(distance == d ? RUColor.card2 : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusLarge, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusLarge, style: .continuous).stroke(distance == d ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(distance == d ? .isSelected : [])
                }
            }
            if goal == .ultraTrail {
                EyebrowLabel(text: "Le dénivelé positif", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
                ObTextField(placeholder: "Ex. 4000", text: $raceElevationGain, keyboard: .numberPad)
            }
            EyebrowLabel(text: "Chrono visé", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(distance.chronoPresets, id: \.self) { t in
                    SelectableChip(label: t, selected: chrono == t) { chrono = t }
                }
            }
            EyebrowLabel(text: "Date de la course", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            DatePicker(
                "",
                selection: $raceDate,
                in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(RUColor.colorScheme)
            .padding(13)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
            Button("CONTINUER") { step = 2 }
                .buttonStyle(PrimaryButtonStyle(isDisabled: deniveleManquant))
                .disabled(deniveleManquant)
                .padding(.top, 20)
        }
    }

    /// L'ÉTAPE DU DUATHLON : format → chrono → date. Trois questions, pas quatre.
    ///
    /// C'est ici que le triathlon s'est fait prendre : cet assistant liste les objectifs
    /// `estProposable` exactement comme l'inscription, donc ouvrir le robinet sans lui donner
    /// son étape y aurait fait apparaître le duathlon sans sa question de format — et le plan
    /// se serait construit sans distances ni temps d'effort, sous le bon nom.
    ///
    /// Rien sur le vélo, pour la raison écrite partout dans ce lot : l'app le mesure.
    private var duathlonStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Format", color: RUColor.text3).padding(.bottom, 10)
            VStack(spacing: 8) {
                ForEach(DuathlonFormat.allCases) { f in
                    SelectableCard(selected: duathlonFormat == f, emoji: nil, title: f.title, subtitle: f.resume) {
                        duathlonFormat = f
                        chrono = f.chronoPresets[safe: 1] ?? ""
                    }
                }
            }

            EyebrowLabel(text: "Chrono visé", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(duathlonFormat.chronoPresets, id: \.self) { t in
                    SelectableChip(label: t, selected: chrono == t) { chrono = t }
                }
            }

            EyebrowLabel(text: "Date de l'épreuve", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            DatePicker(
                "",
                selection: $raceDate,
                in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(RUColor.colorScheme)
            .padding(13)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

            Button("CONTINUER") { step = 2 }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 20)
        }
    }

    /// L'étape du triathlon : format → ce qu'elle nage aujourd'hui → chrono → date.
    ///
    /// Même forme que `raceStep` — une grille, un chrono, une date — avec une question de plus,
    /// qui est la plus importante des quatre. Les trois distances sont le sous-titre de chaque
    /// format : c'est ce qui l'identifie sans employer de marque déposée (voir
    /// `TriathlonFormat`).
    private var triathlonStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Format", color: RUColor.text3).padding(.bottom, 10)
            VStack(spacing: 8) {
                ForEach(TriathlonFormat.allCases) { f in
                    SelectableCard(selected: triathlonFormat == f, emoji: nil, title: f.title, subtitle: f.resume) {
                        triathlonFormat = f
                        chrono = f.chronoPresets[safe: 1] ?? ""
                    }
                }
            }

            EyebrowLabel(text: "Aujourd'hui, tu nages combien sans t'arrêter ?", color: RUColor.text3)
                .padding(.top, 20).padding(.bottom, 10)
            VStack(spacing: 8) {
                ForEach(NiveauDeNage.allCases) { n in
                    SelectableCard(selected: nageNiveau == n, emoji: nil, title: n.title, subtitle: n.subtitle) {
                        nageNiveau = n
                    }
                }
            }

            if let avertissement {
                Text(avertissement)
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(13)
                    .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    .padding(.top, 10)
            }

            EyebrowLabel(text: "Chrono visé", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(triathlonFormat.chronoPresets, id: \.self) { t in
                    SelectableChip(label: t, selected: chrono == t) { chrono = t }
                }
            }

            EyebrowLabel(text: "Date de l'épreuve", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            DatePicker(
                "",
                selection: $raceDate,
                in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(RUColor.colorScheme)
            .padding(13)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

            Button("CONTINUER") { step = 2 }
                .buttonStyle(PrimaryButtonStyle(isDisabled: nageManquante))
                .disabled(nageManquante)
                .padding(.top, 20)
        }
    }

    /// La phrase qui dit l'écart entre le format et ce qu'elle nage, quand il y en a un.
    /// Identique à celle de l'inscription, et pour la même raison : on donne le nombre, pas un
    /// avis. Voir `TriathlonDetailsStepView.avertissement`.
    private var avertissement: LocalizedStringKey? {
        guard let niveau = nageNiveau, niveau.ecartNotable(pour: triathlonFormat) else { return nil }
        guard let metres = niveau.metresEnContinu else {
            return "La natation partira de zéro, et c'est très bien — mais apprendre à durer dans l'eau demande un bassin et quelqu'un sur le bord, pas une case de plus dans un plan. Le programme construira le vélo et la course, et montera la natation prudemment."
        }
        return "\(triathlonFormat.nageMetres) m le jour J, contre \(metres) m aujourd'hui. Le plan montera progressivement, et la natation sera la discipline qui prend le plus de place dans ta semaine."
    }

    private var daysStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Tes jours de course", color: RUColor.text3).padding(.bottom, 10)
            HStack(spacing: 7) {
                ForEach(0..<7) { i in
                    let on = days.contains(i)
                    Button(action: { if on { days.remove(i) } else { days.insert(i) } }) {
                        Text(DayStatus.letters[i]).displayStyle(15).foregroundColor(on ? .white : RUColor.text2)
                            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Button("CONSTRUIRE MON PROGRAMME") { building = true }
                // Le minimum vient de l'objectif CHOISI ICI, et pas de celui en cours : c'est
                // le nouveau plan qu'on dimensionne. Un triathlon en exige trois.
                .buttonStyle(PrimaryButtonStyle(isDisabled: days.count < minimumJours))
                .disabled(days.count < minimumJours)
                .padding(.top, 20)
        }
    }

    private var buildingView: some View {
        VStack(spacing: 20) {
            // Was a fixed pct: 70 — a gauge that never actually moved or finished reads as fake
            // progress; this now genuinely animates to 100% over the same wait `scheduleFinish`
            // uses before the new program is actually ready.
            RingView(pct: buildPct, color: RUColor.rose, size: 100, strokeWidth: 7) {
                // `buildFinished` et non `buildPct >= 100`. `withAnimation` change la valeur
                // IMMÉDIATEMENT et n'anime que le rendu : `buildPct` valait donc 100 dès la
                // première image, et la coche verte de fin s'affichait au centre d'un anneau qui
                // commençait tout juste à se remplir. Deux secondes de contradiction à l'écran.
                Text(buildFinished ? "✓" : "🎯")
                    .font(.system(size: 26))
                    .foregroundColor(buildFinished ? RUColor.lime : RUColor.textPrimary)
            }
            Text("Ton nouveau\nprogramme arrive").displayStyle(22).multilineTextAlignment(.center).foregroundColor(RUColor.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // L'animation démarrait dans l'action du bouton, donc dans le même tour de boucle que le
        // basculement qui fait APPARAÎTRE cet écran : l'anneau n'avait jamais été rendu à zéro
        // quand on lui demandait d'aller à cent, et il surgissait déjà rempli avant de se
        // reprendre — le saut. Ici, la vue est posée à zéro, puis animée.
        .task { await runBuild() }
    }

    private func runBuild() async {
        withAnimation(.easeInOut(duration: Self.buildDuration)) { buildPct = 100 }
        try? await Task.sleep(for: .seconds(Self.buildDuration))
        guard !Task.isCancelled else { return }
        buildFinished = true
        finish()
    }

    private func finish() {
        let result = AdaptivePlanEngine.NewGoalResult(
            goal: goal ?? .health,
            distance: estCourseOuUltra ? distance : nil,
            // Le chrono et la date appartiennent aussi au triathlon — il a une ligne d'arrivée,
            // donc un affûtage à caler dessus. Les lui refuser aurait rendu son plan OUVERT :
            // ni bloc spécifique, ni affûtage, donc aucun enchaînement vélo→course et aucune
            // séance de transition. Exactement le défaut que `periodiseVersUneDate` décrit pour
            // l'ultra-trail, reproduit un objectif plus loin.
            chrono: aUneDeuxiemeEtape ? chrono : nil,
            raceDate: aUneDeuxiemeEtape ? raceDate : nil,
            runningDays: Array(days),
            raceElevationGainM: goal == .ultraTrail ? Int(raceElevationGain.trimmingCharacters(in: .whitespaces)) : nil,
            triathlonFormat: estTriathlon ? triathlonFormat.rawValue : nil,
            nageNiveau: estTriathlon ? nageNiveau?.rawValue : nil,
            duathlonFormat: estDuathlon ? duathlonFormat.rawValue : nil
        )
        AdaptivePlanEngine.startNewProgram(result, profile: appState.profile)
        NotificationService.shared.rescheduleDailyReminder(for: appState.profile)
        Haptics.success()
        appState.toast(String(localized: "Ton nouveau programme est prêt"))
        dismiss()
        appState.go(.home)
    }
}
