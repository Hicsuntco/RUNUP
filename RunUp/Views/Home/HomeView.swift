import SwiftUI
import SwiftData

/// "Programme" home screen — mirrors `ProgScreen` in screensA.jsx.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptions
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
    // La sonde « a-t-elle déjà couru une fois » a disparu avec la bande de chiffres : elle
    // n'existait que pour choisir entre deux phrases de comparaison, et la carte de la semaine ne
    // pose plus cette question — un premier jour s'y lit « 0,0 / 32 km », ce qui est à la fois
    // exact et suffisant. Une requête SwiftData de moins à chaque retour sur l'onglet.

    init() {
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: .now) ?? .distantPast
        _runs = Query(
            filter: #Predicate<RunRecord> { $0.date >= cutoff },
            sort: \RunRecord.date,
            order: .reverse
        )
    }

    private var profile: UserProfile { appState.profile }
    private var isFreeRun: Bool { profile.programPhase == .freerun }
    private var unreadCount: Int { unreadNotifications.count }

    var body: some View {
        Group {
            // Les phases de fin de programme — récupération encadrée, puis choix d'un nouvel
            // objectif — REMPLACENT l'accueil. C'est juste quand on suit un programme : pendant
            // la récupération, l'app doit dire de ne pas courir, et c'est tout son propos.
            //
            // Sans abonnement, il n'y a pas de programme, donc pas de phase à respecter — et
            // surtout ces deux écrans ne portent aucun bouton pour partir courir. Une abonnée
            // dont l'abonnement s'arrête en pleine récupération se retrouvait donc devant une app
            // de course sans aucun moyen de courir, sans rien à l'écran pour l'expliquer.
            switch planUnlocked ? profile.programPhase : .active {
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
                    title: profile.name,
                    // 32 au lieu des 24 par défaut. Le prénom est la première chose de l'écran et
                    // il avait la taille d'un titre de section ; les écrans qui paraissent
                    // modernes ouvrent presque tous sur un mot posé grand, puis descendent vite.
                    // C'est l'ÉCART entre les tailles qui crée la hiérarchie, pas leur valeur.
                    titleSize: 32
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

                // La séance d'abord.
                //
                // L'ordre venait de la maquette — anneau, chiffres, séance — et la maquette a
                // raison sur un écran qu'on consulte. Celui-ci n'est pas consulté, il est utilisé :
                // on l'ouvre pour savoir ce qu'on court aujourd'hui, et c'est la seule carte qui
                // porte un bouton. Elle arrivait en troisième position, après deux blocs qui
                // regardent en arrière. Ce qui se fait passe donc avant ce qui s'est fait.
                //
                // L'anneau ne perd rien à venir en second : c'est un état, pas une action, et il
                // reste au-dessus de la ligne de flottaison.
                // Le programme entier — la séance du jour comprise — fait partie de RUNUP Plus.
                //
                // Sans lui, l'accueil ne devient pas vide : il redevient ce qu'il est pour qui ne
                // suit pas de plan. On court quand on veut, on enregistre, on garde ses anneaux
                // du jour et sa série. Le bouton DÉMARRER est exactement le même — verrouiller la
                // possibilité de courir dans une app de course n'aurait aucun sens, et c'est
                // précisément ce qui peuple le Club et fait vivre le fil.
                //
                // Ce qui manque est nommé et montré juste en dessous, plutôt que simplement
                // absent : personne ne peut vouloir un programme dont il ignore l'existence.
                if planUnlocked {
                    sessionCard

                    ringsCard

                    programWeekCard
                } else {
                    freeRunCard

                    ringsCard

                    // Sans la ligne « ce qui reste gratuit » : les trois quarts de l'écran
                    // au-dessus SONT la version gratuite en fonctionnement — la carte pour
                    // partir courir, les anneaux du jour, la série. Le rappeler par écrit
                    // au-dessous, c'est décrire ce qu'on a sous les yeux.
                    PlusLockCard(feature: .adaptivePlan, showsFreeReminder: false)
                }

                // `planUnlocked` en plus d'`isFreeRun` : sans abonnement, cette ligne promettait
                // un coach qui est lui aussi derrière le verrou, deux centimètres sous une carte
                // qui explique déjà qu'il n'y a pas de programme. Elle disait donc la même chose
                // une deuxième fois, en annonçant une aide qui n'arrivera pas.
                if isFreeRun && planUnlocked {
                    Text("Pas de plan fixe — le coach te propose de quoi garder la forme, jour après jour.")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
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
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            RUCardHeader(icon: "map.fill", tint: RUColor.rose,
                                         title: String(localized: "Ton programme · \(profile.goalDisplay)"))
                            // Le compte à rebours, en texte gris au bout de la ligne. Il était
                            // une capsule rose remplie ; il se lit aussi bien sans, et il cesse
                            // de réclamer l'attention d'un bouton alors qu'on ne peut pas le
                            // toucher. La flèche qui l'accompagnait est partie pour de bon : la
                            // section entière est un bouton, et sa dernière ligne dit déjà
                            // « voir le plan complet ».
                            if let days = profile.daysUntilRace {
                                Text(String(localized: "J-\(days)"))
                                    .font(RUFont.sans(.small, weight: .bold))
                                    .foregroundColor(RUColor.text3)
                            }
                        }
                        Text("\(weekEyebrow) · Bloc \(block.label)").displayStyle(17).foregroundColor(RUColor.textPrimary)
                    }
                }
                .accessibilityElement(children: .combine)

                // Les kilomètres de la semaine, à l'endroit où la semaine est décrite.
                //
                // Ils vivaient dans une bande à filets au-dessus, séparée de cette carte par la
                // séance et l'anneau : deux blocs pour une seule semaine, l'un donnant le chiffre
                // et l'autre les jours. La barre de phases part avec la bande — le bloc est déjà
                // nommé au-dessus (« Bloc Base »), la forme complète du programme est le sujet de
                // l'écran du plan, et deux barres de progression dans une même carte ne se lisent
                // plus ni l'une ni l'autre.
                if !isFreeRun {
                    WeekKmSummary(
                        doneKm: weeklyKm(weeksAgo: 0),
                        plannedKm: profile.plannedWeeklyKm,
                        lastWeekKm: weeklyKm(weeksAgo: 1),
                        footnote: nil
                    )
                }

                weekStrip
                if !isFreeRun {
                    if let total = shape.totalWeeks {
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
                // Plus de contour, et un fond pour ceux qui n'en avaient pas.
                //
                // Une case « à venir » était de la couleur de la carte : seul son filet la
                // rendait visible. Sept cases cerclées côte à côte, c'était une grille dans une
                // grille — le motif qu'on retire partout ailleurs. Elles prennent maintenant la
                // sous-surface prévue pour ça (`card2`), qui les montre par leur couleur, et le
                // filet disparaît.
                //
                // Le jour COURANT garde un anneau, mais lui n'est pas un contour de boîte : c'est
                // un repère, le seul de la rangée, et il ne se répète pas sept fois.
                //
                // ── Et plus de fond du tout pour les jours ordinaires ────────────────────────
                //
                // Sept rectangles remplis côte à côte pour porter une lettre et un nombre, c'est
                // sept objets dessinés là où il n'y a que deux états à signaler : ce qui est fait,
                // et où l'on est. Les cinq autres jours ne sont rien de particulier — ils n'ont
                // pas besoin d'une boîte pour le dire.
                //
                // C'est le même geste que partout ailleurs aujourd'hui : on cesse de dessiner un
                // contenant autour de ce qui n'est pas un objet. Il reste une frise de sept
                // colonnes, dont deux portent une marque.
                let (bg, color): (Color, Color) = {
                    switch day.state {
                    // Un jour FAIT était une case entièrement remplie de rose : sur une frise
                    // dont les autres cases n'ont plus de fond, ce pavé devenait l'objet le plus
                    // saturé de l'écran — plus fort que le bouton DÉMARRER. Pour dire « mardi ».
                    // La marque descend là où elle suffit : un disque rose autour de la coche.
                    case .done: return (RUColor.card2, RUColor.textPrimary)
                    // Le fond de la case du jour était un accent dilué dans la carte. Sur un
                    // thème sombre, un rose à 14 % sur du #16161F ne donne pas « rose pâle », il
                    // donne un bordeaux terne — la couleur la plus sale de l'écran, et elle
                    // désignait justement le jour où l'on est. La case prend donc la même
                    // sous-surface que ses voisines : c'est l'anneau et le texte roses qui la
                    // distinguent, et ils le font sans salir.
                    case .today: return (RUColor.card2, RUColor.rose2)
                    // `text3` et non `text4` : sans fond derrière lui, un chiffre à 20 %
                    // d'opacité ne se lit plus, il se devine. La boîte lui servait de contraste.
                    case .rest: return (.clear, RUColor.text3)
                    case .upcoming: return (.clear, RUColor.text2)
                    }
                }()
                VStack(spacing: 6) {
                    Text(day.displayLetter).displayStyle(12).foregroundColor(color)
                    ZStack {
                        if day.state == .today {
                            Circle().stroke(RUColor.rose2, lineWidth: 1.5).frame(width: 19, height: 19)
                        }
                        if day.state == .done {
                            Circle().fill(RUColor.rose).frame(width: 19, height: 19)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(RUColor.onRose)
                        } else {
                            Text("\(Calendar.current.component(.day, from: day.date))")
                                .font(RUFont.sans(.small, weight: day.state == .today ? .bold : .regular))
                                .foregroundColor(color)
                        }
                    }
                    .frame(width: 19, height: 19)
                }
                .frame(maxWidth: .infinity)
                // 11, et non plus 14. La rangée avait été montée à 68 points quand les sept
                // cases portaient un fond : il fallait de la hauteur pour que des boîtes de cette
                // largeur ne paraissent pas écrasées. Cinq d'entre elles n'ont plus de fond, et
                // la seule qui en garde un devient, à cette hauteur, un bloc rose isolé qui pèse
                // plus lourd que la séance du jour. Une frise se mesure à ce qu'elle porte, pas à
                // ce qu'elle portait.
                .padding(.vertical, 11)
                // Each cell (weekday letter + a date number or checkmark, colored by state) was
                // 2-3 separate disconnected VoiceOver stops with no indication of which day is
                // today, done, or a rest day — that information lived only in color/border, never
                // announced.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(dayAccessibilityLabel(day))
                // `radiusInner` et non `radiusCompact` : ce dernier vient de passer de 18 à 22,
                // et 22 sur une case de 43 points de large en ferait une gélule. Le rayon d'une
                // forme doit rester proportionné à sa taille, pas suivre la carte qui la contient.
                .background(bg, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
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
    /// La pastille dégradée `.session-card .tag` de la maquette, à la place de l'eyebrow rose
    /// discret : c'est le seul endroit de l'écran où la maquette remplit vraiment avec l'accent,
    /// et ça fait de la carte séance l'ancre visuelle de la page. Un jour de repos garde une
    /// pastille neutre — il n'y a rien à mettre en avant.
    ///
    /// Elle vivait au milieu des aides de la bande de chiffres ; en supprimant la bande, j'ai
    /// emporté cette fonction avec elle et cassé la compilation. Elle est désormais posée juste
    /// au-dessus de son unique appelante.
    /// La pastille « aujourd'hui ».
    ///
    /// Son symbole était `bolt.fill` pour toute séance — or l'éclair désigne le FRACTIONNÉ dans le
    /// plan depuis que les familles ont une forme. Le même signe pour deux choses différentes sur
    /// deux écrans voisins : la pastille prend maintenant le symbole de la famille du jour.
    ///
    /// Sa couleur, elle, ne bouge pas. Sur l'accueil il n'y a qu'une séance : une couleur de
    /// famille n'y apprendrait rien et disputerait l'accent, alors que dans le plan, où sept
    /// lignes se côtoient, c'est précisément ce qui donne la forme de la semaine.
    private func sessionTag(_ isRestDay: Bool, family: SessionFamily) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isRestDay ? "moon.zzz.fill" : family.symbol).font(.system(size: 9, weight: .bold))
            Text(LocalizedStringKey(isRestDay ? "Aujourd'hui" : "Séance du jour"))
                .font(RUFont.sans(.micro, weight: .bold)).tracking(0.2)
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

    /// DÉMARRER, et un « + » à côté.
    ///
    /// Les deux actions ne sont pas de même nature : l'une lance une course, l'autre en
    /// enregistre une déjà faite. Deux boutons de même taille et de même forme les annonçaient
    /// comme deux choix équivalents, ce qui donnait à la carte la silhouette d'une boîte de
    /// dialogue « Annuler / OK ». Un carré compact à côté du bouton pleine largeur dit la
    /// hiérarchie par la géométrie, sans avoir besoin d'un mot.
    ///
    /// Et le « + » ouvre une saisie plutôt que de valider tout seul : une séance faite hors de
    /// l'app a une distance et une durée réelles, que l'app ne peut pas deviner. Les demander
    /// vaut mieux que de les inventer ou de les laisser à zéro.
    ///
    /// Partagée entre la carte de séance et la carte de course libre : ce sont les deux mêmes
    /// gestes, et deux copies auraient divergé au premier changement.
    private var runActionsRow: some View {
        HStack(spacing: 10) {
            Button(action: { appState.startRun() }) {
                HStack { Image(systemName: "play.fill"); Text("DÉMARRER") }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: { Haptics.selection(); appState.openLogSession() }) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(RUColor.text2)
                    .frame(width: 52, height: 52)
                    .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Ajouter une séance déjà faite")
        }
    }

    private var planUnlocked: Bool { subscriptions.unlocks(.adaptivePlan) }

    /// L'accueil de qui ne suit pas de programme. Pas un écran dégradé : l'écran d'une app de
    /// course qui fait très bien ce qu'on attend d'elle — partir courir, et garder la trace.
    private var freeRunCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: String(localized: "Aujourd'hui"), color: RUColor.rose)
            Text("Cours quand tu veux")
                .displayStyle(23)
                .foregroundColor(RUColor.textPrimary)
                .padding(.top, 8)
            // Énumérait les cinq mesures enregistrées. C'est vrai, et c'est de l'argumentaire :
            // sur un écran qu'on ouvre pour partir courir, la liste se lit une fois et encombre
            // les cent fois suivantes. Ce qui compte tient en une ligne.
            Text("Tout est enregistré, et part dans Apple Santé.")
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            runActionsRow
                .padding(.top, 15)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ruCard()
    }

    private var sessionCard: some View {
        let session = profile.todaySession
        let isRestDay = session.durationMinutes == 0
        return VStack(alignment: .leading, spacing: 0) {
            sessionTag(isRestDay, family: session.family)
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

            // L'ajustement était une PASTILLE, en haut à droite, à côté du tag de séance.
            //
            // Ce n'est pas une pastille : c'est une PHRASE — « Semaine chargée — séances
            // raccourcies ». Enfermée dans une capsule teintée, elle passait sur deux lignes,
            // occupait la moitié de la largeur et pesait plus lourd que le titre qu'elle
            // accompagne. Une pastille est faite pour un mot ou un nombre.
            //
            // Elle devient une ligne, sous le titre, à sa place chronologique : voici la séance,
            // voici pourquoi elle est ce qu'elle est.
            if let adjustment = session.adjustment {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                    Text(adjustment)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(RUFont.sans(.small, weight: .medium))
                .foregroundColor(RUColor.rose2)
                .padding(.top, 6)
            }

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
                // Une carte qui n'a plus d'action garde la place d'une carte qui en a une.
                //
                // Séance faite, il restait un titre, deux lignes, une coche — puis quatre-vingts
                // points de vide, au SOMMET de l'écran. La carte occupait la meilleure place de la
                // page pour ne rien proposer, et c'est ce vide qui creusait ensuite tout le bas de
                // l'écran.
                //
                // Elle regarde donc devant : demain. C'est la seule chose qu'on vient encore
                // chercher ici une fois la séance cochée, et c'est déjà dans le programme — il
                // suffisait d'aller la lire. Un jour de repos demain, la ligne ne s'affiche pas et
                // la carte reste courte : c'est correct aussi, il n'y a rien à annoncer.
                if let next = tomorrowSession { tomorrowRow(next) }
            } else {
                Text(session.displaySubtitle).font(RUFont.sans(.small)).foregroundColor(RUColor.text2).padding(.top, 4)
                // UNE mesure domine, deux l'accompagnent.
                //
                // Les trois colonnes avaient la même taille — 20 points chacune — donc l'écran
                // n'avait pas de sommet : rien n'attirait l'œil en premier, et une page sans
                // sommet se lit comme une liste de champs. C'est ce qui faisait « plat », bien
                // plus que les couleurs.
                //
                // La durée gagne : c'est la seule des trois qui décrit ce qu'on est sur le point
                // de FAIRE. L'allure et la zone décrivent comment le faire, elles n'ont pas
                // besoin d'être lues à un mètre.
                //
                // Le prime « ′ » posé à 24 points à côté d'un 56 se lisait comme une virgule
                // tronquée : « 40, ». Un grand chiffre porte son unité SOUS lui, en petites
                // capitales, comme les deux mesures qui l'accompagnent — sinon ce n'est pas une
                // unité, c'est un caractère perdu.
                //
                // Et les trois mesures sont groupées à GAUCHE, l'espace rejeté au bout. Avec un
                // `Spacer` au milieu, le 40 et le couple allure/zone se retrouvaient collés aux
                // deux bords avec un trou au centre : deux blocs qui s'ignorent au lieu d'une
                // rangée qui se lit.
                HStack(alignment: .lastTextBaseline, spacing: 18) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(session.durationMinutes)")
                            .font(RUFont.display(56))
                            .foregroundColor(RUColor.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("minutes")
                            .font(RUFont.sans(.micro, weight: .medium))
                            .tracking(0.9)
                            .textCase(.uppercase)
                            .foregroundColor(RUColor.text3)
                    }
                    MetricColumn(value: session.pace, label: "Allure", valueSize: 17)
                    MetricColumn(value: session.zone, label: "Zone", valueColor: RUColor.rose2, valueSize: 17)
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)

                // DÉMARRER, et un « + » à côté.
                //
                // Les deux actions ne sont pas de même nature : l'une lance une course, l'autre en
                // enregistre une déjà faite. Deux boutons de même taille et de même forme les
                // annonçaient comme deux choix équivalents, ce qui donnait à la carte la silhouette
                // d'une boîte de dialogue « Annuler / OK ». Un carré compact à côté du bouton
                // pleine largeur dit la hiérarchie par la géométrie, sans avoir besoin d'un mot.
                //
                // Et le « + » ouvre une saisie plutôt que de valider tout seul : une séance faite
                // hors de l'app a une distance et une durée réelles, que l'app ne peut pas
                // deviner. Les demander vaut mieux que de les inventer ou de les laisser à zéro.
                runActionsRow
                    .padding(.top, 15)
            }
        }
        // La carte prend TOUTE la largeur, quel que soit son contenu.
        //
        // Sans ça, elle se réduisait à son texte le plus long dans les états qui n'ont ni rangée
        // de mesures ni boutons — « séance faite », jour de repos. Le défaut existait depuis
        // toujours mais restait invisible tant que trois cartes se suivaient : elles étaient
        // toutes étroites ensemble. Depuis que les sections en dessous vont d'un bord à l'autre,
        // la carte se retrouve seule à s'arrêter au milieu, et l'écran a l'air cassé — parce
        // qu'il l'est.
        .frame(maxWidth: .infinity, alignment: .leading)
        // 20 au lieu de 16 : c'est la carte qui porte le sommet de l'écran, et une marge plus
        // large est ce qui distingue une carte principale d'une carte de liste — sans avoir à
        // lui ajouter un contour, une teinte ou un badge.
        .padding(20)
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
    /// La séance de demain, si demain en porte une.
    ///
    /// Lue dans `weekSessions`, la même source que la bande de la semaine — pas une prévision, pas
    /// un calcul : ce qui est déjà planifié. `nil` un jour de repos, et le dernier jour d'une
    /// semaine dont la suivante n'est pas encore générée.
    private var tomorrowSession: (title: String, minutes: Int)? {
        guard let date = Calendar.current.date(byAdding: .day, value: 1, to: .now) else { return nil }
        let index = AdaptivePlanEngine.weekdayIndex(for: date)
        guard let planned = profile.weekSessions.first(where: { $0.weekday == index }),
              let session = planned.session, session.durationMinutes > 0 else { return nil }
        return (session.displayTitle, session.durationMinutes)
    }

    /// « DEMAIN · Sortie longue · 60 min », sous un filet.
    ///
    /// Volontairement discrète : elle informe, elle n'appelle pas à agir. Un second bouton dans
    /// cette carte lui donnerait deux sommets, et on ne démarre pas la séance de demain.
    private func tomorrowRow(_ next: (title: String, minutes: Int)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Demain")
                    .font(RUFont.sans(.micro, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(RUColor.text3)
                Text(next.title)
                    .font(RUFont.sans(.label, weight: .semibold))
                    .foregroundColor(RUColor.text2)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                Text("\(next.minutes) min")
                    .font(RUFont.sans(.small, weight: .bold))
                    .foregroundColor(RUColor.text3)
            }
        }
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    private func weeklyKm(weeksAgo: Int) -> Double {
        let cal = Calendar.current
        let thisWeekStart = AdaptivePlanEngine.currentWeekRange().lowerBound
        guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeekStart) else { return 0 }
        let range = AdaptivePlanEngine.currentWeekRange(from: weekStart)
        return runs.filter { range.contains($0.date) }.reduce(0) { $0 + $1.distanceKm }
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
                // 84, et non plus 96. La taille avait été montée à 96 pour que l'anneau pèse comme
                // l'élément principal de SA CARTE. Il n'y a plus de carte : posé à même la page, à
                // dix-huit points du bord, il n'a plus rien à dominer, et à 96 il se met à
                // écraser la ligne de la séance juste au-dessus.
DailyGoalsBarsView(goals: p.dailyGoalSlotsToday.map { .init(slot: $0.slot, progress: $0.progress) }, size: 96)
                VStack(alignment: .leading, spacing: 9) {
                    // Avec son icône, comme la carte du programme. L'écran portait trois
                    // grammaires d'en-tête pour trois cartes — une pastille remplie, un titre nu,
                    // une icône suivie d'un titre — et rien ne les reliait. Il en reste deux : le
                    // titre à icône, commun aux cartes qui décrivent un ÉTAT, et la pastille de la
                    // carte du jour, qui est la seule à porter une action.
                    RUCardHeader(icon: "target", tint: RUColor.rose,
                                 title: String(localized: "Objectifs · \(p.dailyGoalsDone)/\(p.dailyGoalsTotal)"))
                    // « Objectifs · 0/3 », et non « Tes objectifs · 0/3 bouclés ».
                    //
                    // « Tes » ne distingue rien — tout l'écran est déjà à toi, et il est le seul
                    // possessif de la page. « Bouclés » redit ce que la fraction dit mieux : 0/3
                    // ne peut vouloir dire qu'une chose. Sept mots deviennent trois, la ligne
                    // cesse de passer sur deux lignes à côté de l'anneau, et rien de l'information
                    // n'est perdu.
                    // La ligne « Séance du jour » disparaît les jours de repos, en même temps que
                    // l'arc qui lui correspondait. Elle disait alors « Repos » — exactement ce que
                    // la carte séance, désormais juste au-dessus, annonce en grand. Deux blocs
                    // pour la même phrase, c'est la première raison pour laquelle cet écran
                    // paraissait chargé un jour de repos.
                    // Sans programme, il n'y a pas de jour de repos : chaque jour est un jour
                    // où l'on peut courir, donc la ligne reste.
                    if !planUnlocked || !p.isRestDayToday {
                        // « Séance », pas « Séance du jour » : la carte juste au-dessus annonce
                        // déjà la séance du jour en grand, et l'écran de détail nomme cette même
                        // ligne « Séance ». Deux libellés pour la même chose, dont le plus long
                        // était sur le plus petit espace.
                        // « Séance » nomme la séance du programme, qui n'existe pas sans Plus.
                        // Sans programme, l'objectif du jour est simplement d'aller courir — et
                        // c'est le même booléen qui le mesure.
                        ringLegendRow(
                            // Les DEUX sont des clés, pas des chaînes traduites :
                            // `ringLegendRow` fait lui-même la recherche au catalogue. Passer un
                            // `String(localized:)` ici traduirait une première fois, puis
                            // rechercherait le résultat français comme s'il était une clé — ça
                            // marche en français par identité, et ça casse partout ailleurs.
                            name: planUnlocked ? "Séance" : "Course",
                            value: p.seanceDoneToday ? String(localized: "Faite") : String(localized: "À faire"),
                            color: goalColors[0]
                        )
                    }
                    // Le chiffre atteint seul, sans son objectif — l'arc à gauche le dessine déjà.
                    //
                    // « 254/15000 » était la chaîne la plus lourde de l'écran pour ce qu'elle
                    // apprend : le second nombre ne bouge jamais, et la seule chose qu'on en tire
                    // — suis-je loin du compte — se lit d'un coup d'œil sur la longueur de l'arc,
                    // sans arithmétique. L'objectif reste écrit en toutes lettres sur « Ta
                    // journée », qui est l'écran où on va justement le regarder.
                    //
                    // Groupé par milliers, et selon la locale : `8432` demande un effort de
                    // lecture que `8 432` ne demande pas, et l'anglais veut sa virgule là où le
                    // français veut son espace.
                    ringLegendRow(name: "Calories", value: Int(p.activeCaloriesToday).formatted(), color: goalColors[1])
                    ringLegendRow(name: "Pas", value: Int(p.stepsToday).formatted(), color: goalColors[2])
                }
            }
            .padding(16)
        }
        .buttonStyle(PressableStyle())
        .ruCard()
    }

    /// Sans pastille de couleur devant le nom.
    ///
    /// Elle servait à relier la ligne à son arc dans l'anneau. Cette correspondance ne tient plus
    /// depuis que la PISTE est grise : à 0/3, l'anneau ne contient presque aucune couleur, et
    /// trois pastilles pointaient vers des arcs qui n'existent pas encore. Elles ne reliaient plus
    /// rien, elles ajoutaient trois taches roses de plus sur un écran qui en comptait seize.
    ///
    /// Le `color` reste dans la signature : c'est la ligne qui décide, pas l'appelant, et le jour
    /// où la correspondance redevient utile elle se rebranche ici seule.
    private func ringLegendRow(name: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
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
        // Sinon VoiceOver lit le nom et la valeur comme deux arrêts distincts, alors qu'ils
        // décrivent un seul objectif.
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
