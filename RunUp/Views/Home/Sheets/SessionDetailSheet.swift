import SwiftUI

/// Bottom sheet reached by tapping the home hero card. Mirrors `SessionDetailSheet` in screensC.jsx.
struct SessionDetailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var moved = false

    private var session: WorkoutSession { appState.profile.todaySession }

    /// The real archetype titles from `AdaptivePlanEngine` fall into 3 shapes — a footing/sortie
    /// longue IS an easy continuous effort throughout (no separate warmup/cooldown block at a
    /// different pace makes sense there), a tempo run is one sustained threshold effort, and only
    /// a "Fractionné"/"Rappel d'allure" session is actually structured as reps + recovery. Every
    /// session used to show the same "warmup + N×800m + cooldown" regardless of which of these it
    /// actually was.
    private var steps: [(String, String, Color)] {
        // `session.title` reste EN FRANÇAIS en permanence : c'est l'identifiant interne d'archétype
        // sur lequel les tests ci-dessous classent la séance. Seul l'affichage passe par
        // `displayTitle`. Ne pas localiser ni toucher à cette classification.
        let title = session.title.lowercased()
        let warmup = (String(localized: "Échauffement"), String(localized: "10-15′ · Z2 · footing relâché"), RUColor.cyan)
        let cooldown = (String(localized: "Retour au calme"), String(localized: "5-10′ · Z1 · marche + étirements"), RUColor.lime)

        // HYROX sessions are structurally different from a running-only week — a "compromised
        // running" block or a functional circuit isn't a warmup/interval/cooldown shape at all,
        // so this branches before the running-only logic below ever gets a chance to mislabel it
        // as a generic "Course continue".
        if appState.profile.goalId == .hyrox {
            return hyroxSteps(kind: session.kind, warmup: warmup, cooldown: cooldown)
        }

        // Les séances d'ultra, de même, ne sont pas des séances de route : une côte où l'on MARCHE
        // et une descente répétée tomberaient toutes deux dans « Course continue », avec une
        // allure cible qui ne veut rien dire sur l'une ni sur l'autre.
        //
        // Et contrairement à la branche HYROX juste au-dessus, ce classement-ci lit `kind` et non
        // le titre : les `kind` sont arrivés avec les séances d'ultra, et c'est l'identité
        // indépendante de la langue. Classer par sous-chaîne française quand un champ dédié
        // existe, c'est reconduire une faiblesse qu'on n'est plus obligé de porter.
        if appState.profile.goalId == .ultraTrail, let kind = session.kind {
            return ultraSteps(kind: kind, warmup: warmup, cooldown: cooldown)
        }

        if session.isIntervalSession {
            return [
                warmup,
                (intervalDescription, String(localized: "\(session.pace) /km · \(session.zone) · récupération entre chaque"), RUColor.rose),
                cooldown
            ]
        }
        if title.contains("tempo") {
            return [
                warmup,
                (String(localized: "Bloc tempo"), String(localized: "\(max(10, session.durationMinutes - 20))′ · \(session.pace) /km · \(session.zone) · effort soutenu et continu"), RUColor.rose),
                cooldown
            ]
        }
        // Footing / sortie longue / sortie courte / découverte / récup — the whole run is the
        // target effort, not a warmup building up to something else.
        return [(String(localized: "Course continue"), "\(session.durationMinutes)′ · \(session.pace) /km · \(session.zone)", RUColor.rose)]
    }

    /// Le découpage des séances HYROX, par `kind`.
    ///
    /// # DEUX CHOSES QUE CETTE FONCTION FAISAIT MAL
    ///
    /// Elle aiguillait sur des SOUS-CHAÎNES DE TITRE — « compromise », « simulation », « tempo » —
    /// alors que son voisin `ultraSteps` lit le `kind`, et que le commentaire de l'appelant disait
    /// déjà pourquoi : « Classer par sous-chaîne française quand un champ dédié existe, c'est
    /// reconduire une faiblesse qu'on n'est plus obligé de porter. »
    ///
    /// Et cette faiblesse avait une conséquence vivante : un FOOTING HYROX ne contient aucun des
    /// trois mots cherchés. Il tombait donc dans le repli et s'affichait « Circuit fonctionnel ·
    /// stations enchaînées, technique avant charge » — la description d'un circuit de musculation
    /// sur une sortie en endurance. Rien ne plantait, et l'écran disait le contraire de la séance.
    ///
    /// # LES CHARGES SONT CELLES DE SA DIVISION
    ///
    /// Elles s'affichent ICI et pas dans le sous-titre de la séance, pour une raison mécanique :
    /// `displaySubtitle` lit `kind.subtitleKey`, une clé STATIQUE du catalogue, et jette le
    /// sous-titre composé par l'archétype. Les archétypes HYROX interpolaient pourtant
    /// « charge standard » / « charge renforcée » dans le leur depuis le début — du texte qui
    /// n'a jamais atteint un écran. Cet écran-ci a le profil, donc la division, donc les kilos.
    ///
    /// Division inconnue — un profil d'avant les quatre divisions officielles — et les stations
    /// sont nommées sans charge. On ne devine pas si elle pousse 102 ou 202 kg.
    private func hyroxSteps(kind: SessionKind?, warmup: (String, String, Color),
                            cooldown: (String, String, Color)) -> [(String, String, Color)] {
        let charges = appState.profile.hyroxDivision
            .flatMap { HyroxDivision(rawValue: $0) }?.charges

        /// Les stations, avec leur charge quand on la connaît. `rangs` les restreint à une
        /// famille ; sans lui, les huit dans l'ordre de la course.
        func stations(_ rangs: [Int]? = nil) -> [(String, String, Color)] {
            guard let charges else {
                return [(String(localized: "Les huit stations"),
                         String(localized: "choisis ta division pour voir tes charges"),
                         RUColor.text3)]
            }
            let toutes = charges.stations
            let choisies = rangs?.compactMap { toutes.indices.contains($0) ? toutes[$0] : nil }
                ?? toutes
            return choisies.map { ($0.nom, $0.prescription, RUColor.rose2) }
        }

        // UNE SÉANCE DE FAMILLE NE MONTRE QUE SES DEUX STATIONS. Afficher les huit sur une séance
        // qui en travaille deux ferait lire une liste dont six lignes ne concernent pas le jour.
        if let kind, let famille = ChargesHyrox.FamilleDeStations.pour(kind) {
            return [(String(localized: "\(session.durationMinutes)′ · deux stations"),
                     String(localized: "\(session.zone) · à charge de course, technique avant charge"),
                     RUColor.rose)]
                + stations(famille.rangs)
        }

        switch kind {
        case .hyroxCompromisedRun3, .hyroxCompromisedRun6, .hyroxCompromisedRunLight2:
            return [
                warmup,
                (String(localized: "\(intervalDescription) + fonctionnel"),
                 String(localized: "\(session.pace) /km entre les blocs · \(session.zone) · enchaîne course et mouvement, sans repos complet"),
                 RUColor.rose),
                cooldown
            ]

        case .hyroxLightSimulation:
            return [warmup,
                    (String(localized: "\(ChargesHyrox.Format.segmentsDeCourse) × \(ChargesHyrox.Format.courseParSegmentM) m + \(ChargesHyrox.Format.segmentsDeCourse) stations"),
                     String(localized: "format complet HYROX · \(session.zone) · gère l'effort sur l'ensemble, pas juste la course"),
                     RUColor.rose)]
                + stations() + [cooldown]

        case .hyroxTempoSled:
            let sled = charges.map {
                String(localized: "sled push \($0.sledPushKg) kg, sled pull \($0.sledPullKg) kg")
            } ?? String(localized: "sled push et sled pull")
            return [
                warmup,
                (String(localized: "Tempo + sled"),
                 String(localized: "\(max(10, session.durationMinutes - 20))′ · \(session.pace) /km · \(session.zone) · allure seuil entrecoupée de \(sled)"),
                 RUColor.rose),
                cooldown
            ]

        // LES FOOTINGS SONT DES COURSES, et c'est ce que l'écran doit dire. Ils tombaient dans le
        // repli « circuit fonctionnel » faute d'être reconnus.
        // `tempoRun` EST DANS CETTE LISTE, et il fallait y penser : le bloc spécifique HYROX
        // prescrit maintenant un vrai tempo de course, avec le type générique. Sans cette ligne,
        // il tombait dans le repli « circuit fonctionnel » — le défaut que les footings viennent
        // de subir, reconduit le jour même par la séance que je venais d'ajouter.
        case .hyroxBaseFooting, .hyroxMaintenanceFooting, .hyroxRecoveryFooting, .tempoRun:
            return [(String(localized: "Course continue"),
                     String(localized: "\(session.durationMinutes)′ · \(session.pace) /km · \(session.zone)"),
                     RUColor.rose)]

        // Les circuits et les rappels techniques : la séance EST les huit stations. Un échauffement
        // et un retour au calme de coureuse n'ont pas de sens dessus — la préparation du mouvement
        // fait partie du circuit.
        default:
            return [(String(localized: "Circuit fonctionnel"),
                     String(localized: "\(session.durationMinutes)′ · \(session.zone) · stations enchaînées, technique avant charge"),
                     RUColor.rose)]
                + stations()
        }
    }

    /// Le découpage des séances d'ultra, par `kind`.
    ///
    /// Trois d'entre elles n'ont AUCUN équivalent sur route, et c'est pour ça qu'elles existent :
    /// la côte où marcher est la technique, la descente qui prépare les quadriceps du jour J, et
    /// le second jour d'un enchaînement, qui se court précisément sur des jambes déjà entamées.
    ///
    /// Les sorties longues portent en plus la consigne de ravitaillement — et elles la portent ICI
    /// parce que c'est l'écran qu'on lit avant de partir. Dire « teste ton alimentation en sortie
    /// longue » dans un écran d'objectif qu'on ouvre une fois, c'est ne pas le dire.
    private func ultraSteps(kind: SessionKind, warmup: (String, String, Color),
                            cooldown: (String, String, Color)) -> [(String, String, Color)] {
        let ravitaillement = (
            String(localized: "Ravitaillement"),
            String(localized: "une prise toutes les \(UltraRaceDay.minutesEntreDeuxPrises) min, à la montre — c'est la séance où tu testes ce que tu mangeras le jour J"),
            RUColor.lime
        )

        switch kind {
        case .ultraHillRepeats:
            return [
                warmup,
                (String(localized: "Côtes de 3 à 5 min"), String(localized: "\(session.zone) · marche dès que la pente l'impose : en ultra c'est la technique, pas un échec"), RUColor.rose),
                cooldown
            ]
        case .ultraDescentWork:
            return [
                warmup,
                (String(localized: "Descentes répétées"), String(localized: "monte tranquille, descends en contrôle · ce sont tes quadriceps qu'on prépare, pas un chrono"), RUColor.rose),
                cooldown
            ]
        case .ultraPowerHike:
            return [(String(localized: "Marche rapide en côte"), String(localized: "\(session.durationMinutes)′ · le cardio doit monter autant qu'en courant · tes bâtons si tu en auras le jour J"), RUColor.rose)]
        case .ultraNightRun:
            return [(String(localized: "À la frontale"), String(localized: "\(session.durationMinutes)′ · en terrain, avec LES DEUX frontales du jour J · le faisceau écrase le relief, tu iras moins vite"), RUColor.cyan)]
        case .ultraLongRun, .ultraSpecificLongRun, .easedLongRun:
            return [
                (String(localized: "Temps debout"), String(localized: "\(session.durationMinutes)′ · \(session.zone) · c'est la durée qui compte, pas la distance"), RUColor.rose),
                ravitaillement
            ]
        case .ultraBackToBackDay1:
            return [
                (String(localized: "Temps debout"), String(localized: "\(session.durationMinutes)′ · \(session.zone) · demain tu repars dessus, donc garde-en"), RUColor.rose),
                ravitaillement
            ]
        case .ultraBackToBackDay2:
            return [
                (String(localized: "Sur les jambes de la veille"), String(localized: "\(session.durationMinutes)′ · \(session.zone) · c'est la seconde moitié de ta course, en répétition — et elle doit être inconfortable"), RUColor.rose),
                ravitaillement
            ]
        default:
            // Footings d'endurance, d'entretien, rappel de terrain, récup : tout l'effort est la
            // cible, il n'y a pas de bloc à distinguer.
            return [(String(localized: "Course continue"), "\(session.durationMinutes)′ · \(session.pace) /km · \(session.zone)", RUColor.rose)]
        }
    }

    /// Pulls the exact "N × distance" straight from the archetype's own title (e.g. "5 × 500 m",
    /// "6 × 800 m", "3 × 1 km") instead of assuming every interval session is 800m repeats.
    private var intervalDescription: String {
        // L'expression régulière porte sur le titre français interne : ne pas y toucher. Seul le
        // repli, qui est du texte affiché, passe par le catalogue.
        if let range = session.title.range(of: #"\d+\s*×\s*\d+\s?(m|km)"#, options: .regularExpression) {
            return String(session.title[range])
        }
        return String(localized: "Fractionné")
    }

    private var isRestDay: Bool { session.durationMinutes == 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        RUCardHeader(icon: isRestDay ? "moon.zzz.fill" : "figure.run", title: isRestDay ? "Aujourd'hui" : "Séance clé")
                        Text(session.displayTitle).displayStyle(.title).foregroundColor(RUColor.textPrimary)
                    }
                    Spacer()
                    if let adj = session.adjustment {
                        StatChip(text: adj, color: RUColor.rose2)
                    }
                }
                .padding(.top, 8)

                if isRestDay {
                    Text(session.displaySubtitle)
                        .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
                        .padding(.top, 18)
                } else {
                    RUMetricRow(spacing: 18) {
                        MetricColumn(value: "\(session.durationMinutes)′", label: "Durée")
                        MetricColumn(value: session.pace, label: "Allure cible")
                        MetricColumn(value: session.zone, label: "Zone", valueColor: RUColor.rose2)
                    }
                    .padding(.top, 18)

                    EyebrowLabel(text: "Structure de la séance", color: RUColor.text3).padding(.top, 24).padding(.bottom, 10)

                    VStack(spacing: 6) {
                        ForEach(steps.indices, id: \.self) { i in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: RUSpacing.radiusBar).fill(steps[i].2).frame(width: 3, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(steps[i].0).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                    Text(steps[i].1).font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .ruCard(radius: RUSpacing.radiusInner, fill: RUColor.card2)
                        }
                    }

                    if let adj = session.adjustment {
                        // Two different mechanisms can set this same field (see `WorkoutSession.
                        // adjustment`) — a week-boundary tier bump/ease from LAST week's average
                        // RPE ("Niveau X"), or a same-day reactive lightening from TODAY's sleep/
                        // yesterday's RPE (`AdaptivePlanEngine.applySameDayAdjustmentIfNeeded`,
                        // always prefixed "Allégée"). Explaining the tier-change copy on a same-day
                        // reason (or vice versa) would just be wrong about why this looks different.
                        Group {
                            if adj.hasPrefix("Allégée") {
                                Text("Cette séance a été allégée aujourd'hui d'après ta forme du jour — la semaine reprend son cours normal demain.")
                            } else {
                                Text("Le coach a ajusté cette semaine à \"\(adj)\" d'après ta forme la semaine dernière.")
                            }
                        }
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text2)
                        .lineSpacing(3)
                        .padding(14)
                        .ruCard(radius: RUSpacing.radiusCard)
                        .padding(.top, 18)
                    }

                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            // L'encart du bas n'est plus posé ici : `runUpSheetStyle` le donne à toutes les
            // feuilles, d'une seule valeur. Voir `RUSpacing.sheetBottomInset`.
        }
        // LE PIED DE LA FEUILLE EST ÉPINGLÉ, Y COMPRIS SA BRANCHE « DÉPLACÉE ».
        //
        // Les deux états partent ensemble : « Déplacer à demain / DÉMARRER », et la confirmation
        // qui les remplace une fois la séance déplacée. Épingler seulement le premier aurait
        // fait disparaître la barre d'un coup au moment où l'on déplace — la feuille se serait
        // réorganisée sous les doigts, juste après un geste.
        //
        // Le `padding(.top, 16)` des deux branches tombe : `ruBarreDuBas` pose ses marges.
        .ruBarreDuBas {
            if moved {
                Text("Séance déplacée à demain ✓")
                    .font(RUFont.sans(.label, weight: .semibold))
                    .foregroundColor(RUColor.lime)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    // Surface neutre : l'accent reste au texte et à l'icône. Un lime
                    // dilué donne sa version sale, et le contour de la même couleur la redisait.
                    .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Button("Déplacer à demain") {
                        // Really swaps today/tomorrow in the plan — this used to only set
                        // the local `moved` flag and claim success without touching
                        // `weekSessions` at all.
                        if AdaptivePlanEngine.moveTodaySessionToTomorrow(appState.profile) {
                            moved = true
                            appState.publishWidgetSnapshot()
                            appState.toast(String(localized: "Séance déplacée à demain"))
                        } else {
                            appState.toast(String(localized: "Impossible de déplacer cette séance — dernier jour de la semaine."))
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: {
                        dismiss()
                        appState.startRun()
                    }) {
                        HStack { Image(systemName: "play.fill"); Text("DÉMARRER") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
}
