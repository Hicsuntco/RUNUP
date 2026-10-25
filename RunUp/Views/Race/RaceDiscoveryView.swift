import SwiftUI

/// « Qui d'autre court le marathon de Paris ? »
///
/// La porte d'entrée des pages de course : celles qu'on prépare, celles qui approchent, et un
/// champ pour trouver les autres. Rien ici n'est un catalogue mondial — l'app sème une dizaine de
/// grandes courses et tout le reste est créé par les coureurs eux-mêmes, au moment où ils en ont
/// besoin. Une page de course n'a pas à exister avant que quelqu'un la prépare.
struct RaceDiscoveryView: View {
    @Environment(AppState.self) private var appState

    @State private var mine: [RaceEvent] = []
    @State private var upcoming: [RaceEvent] = []
    @State private var query = ""
    @State private var results: [RaceEvent] = []
    @State private var searchEnCours = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoading = true
    /// Le MOTIF de l'échec, pas un drapeau : « vérifie ta connexion » était affiché pour une
    /// session expirée comme pour un serveur en panne. Voir `PanneReseau`.
    @State private var loadError: String?
    @State private var ouverte: RaceEvent?
    @State private var creationPresentee = false

    private var clubService: ClubService { ClubService(auth: appState.auth) }

    private var recherche: String { query.trimmingCharacters(in: .whitespaces) }
    private var enRecherche: Bool { recherche.count >= 2 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                champDeRecherche

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if let loadError {
                    message(String(localized: "Impossible de charger les courses — \(loadError)."))
                } else if enRecherche {
                    resultats
                } else {
                    if !mine.isEmpty { section(titre: "Je prépare", icone: "flag.checkered", courses: mine) }
                    if !upcoming.isEmpty {
                        section(titre: "Ça approche", icone: "calendar", courses: upcoming)
                    }
                    if mine.isEmpty && upcoming.isEmpty { videHonnete }
                    boutonCreer
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, RUSpacing.tabBarBottomInset + RUSpacing.tabBarHeight + 20)
        }
        .background(RUColor.pageBackground)
        .onChange(of: query) { _, nouveau in chercher(nouveau) }
        // PLEIN ÉCRAN, ET PAS UNE FEUILLE À MI-HAUTEUR.
        //
        // Une feuille est une PARENTHÈSE : on y fait une chose, on la referme. La page d'une
        // course est une DESTINATION — on y lit qui la prépare, on fait défiler le mur, on écrit.
        // Ouverte à mi-hauteur au-dessus de la liste, elle avait l'air d'une carte posée sur
        // l'écran plutôt que d'un endroit où l'on se trouve, et il fallait la tirer vers le haut
        // avant de pouvoir y faire quoi que ce soit.
        .fullScreenCover(item: $ouverte) { course in
            RacePageView(race: course) { Task { await charger() } }
        }
        // Celle-ci RESTE une feuille, et c'est le bon choix : créer une course est une
        // parenthèse, elle a une fin. Mais en pleine hauteur — le formulaire fait huit champs,
        // et s'ouvrir à mi-écran sur un formulaire oblige à le tirer avant de le lire.
        .sheet(isPresented: $creationPresentee) {
            CreateRaceSheet(nomPropose: recherche) { creee in
                creationPresentee = false
                query = ""
                // Le délai n'est pas de la superstition : SwiftUI laisse tomber en silence une
                // feuille présentée pendant que la précédente se referme, et on atterrirait sur
                // la liste au lieu de la page qu'on vient de créer.
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    ouverte = creee
                    await charger()
                }
            }
            .runUpSheetStyle(detents: [.large])
        }
        .task {
            if isLoading { await charger() }
            #if DEBUG
            // La page de course n'est pas un écran de l'app : elle se présente par-dessus celui-ci.
            // Pour la photographier, il faut donc la demander d'ici, une fois la liste en place.
            if CaptureSeed.courseDemandee { ouverte = appState.cachedRacePage?.race }
            #endif
        }
        .refreshable { await charger() }
    }

    // MARK: - Chercher

    private var champDeRecherche: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundColor(RUColor.text3)
                TextField("Nom de la course, ou sa ville", text: $query)
                    .textFieldStyle(.plain)
                    .font(RUFont.sans(.emphasis))
                    .foregroundColor(RUColor.textPrimary)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundColor(RUColor.text3)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Effacer la recherche")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .frame(minHeight: 48)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        }
    }

    @ViewBuilder
    private var resultats: some View {
        if searchEnCours {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
        } else if results.isEmpty {
            VStack(spacing: 12) {
                message(String(localized: "Aucune course à venir ne porte ce nom."))
                // Le vide le plus utile de l'app : quelqu'un vient de taper le nom exact de la
                // course qu'il prépare. Lui proposer de la créer là, avec ce nom déjà rempli, est
                // la seule suite qui a du sens.
                boutonCreer
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { rang, course in
                    if rang > 0 {
                        Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                    }
                    ligne(course)
                }
                boutonCreer.padding(.top, 14)
            }
        }
    }

    private func chercher(_ texte: String) {
        searchTask?.cancel()
        let propre = texte.trimmingCharacters(in: .whitespaces)
        guard propre.count >= 2 else {
            results = []
            searchEnCours = false
            return
        }
        searchEnCours = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let trouvees = (try? await clubService.searchRaces(query: propre)) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run {
                results = trouvees
                searchEnCours = false
            }
        }
    }

    // MARK: - Listes

    /// `titre` arrive en français : `RUCardHeader` le passe lui-même par le catalogue
    /// (`LocalizedStringKey`), donc le traduire ici le traduirait deux fois.
    private func section(titre: String, icone: String, courses: [RaceEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RUCardHeader(icon: icone, tint: RUColor.rose2, title: titre)
            // Des lignes séparées par un filet, pas une pile de cartes : une liste de courses se
            // parcourt du pouce, et dix rectangles arrondis empilés fabriquent dix objets là où
            // il n'y a qu'une liste.
            VStack(spacing: 0) {
                ForEach(Array(courses.enumerated()), id: \.element.id) { rang, course in
                    if rang > 0 {
                        Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                    }
                    ligne(course)
                }
            }
        }
    }

    private func ligne(_ course: RaceEvent) -> some View {
        Button(action: { ouverte = course }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(RUColor.rose.opacity(0.16))
                    Image(systemName: course.disciplineSymbole)
                        .font(.system(size: 15)).foregroundColor(RUColor.rose)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(RUFont.sans(.emphasis, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(2)
                    Text(course.dateLisible)
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text2)
                    if !course.sousTitre.isEmpty {
                        Text(course.sousTitre)
                            .font(RUFont.sans(.small))
                            .foregroundColor(RUColor.text3)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    if let jours = course.joursRestants, jours >= 0 {
                        // « J-42 » et non « dans 42 jours » : c'est la forme qu'un dossard
                        // porte, et elle tient sur une ligne à côté du nom de la course.
                        Text(jours == 0 ? String(localized: "aujourd'hui") : String(localized: "J-\(jours)"))
                            .font(RUFont.mono(11))
                            .foregroundColor(RUColor.rose2)
                    }
                    if let suiveurs = course.followerCount, suiveurs > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill").font(.system(size: 9))
                            Text("\(suiveurs)").font(RUFont.mono(10.5))
                        }
                        .foregroundColor(RUColor.text3)
                        .accessibilityLabel(Pluriel.choisir(suiveurs,
                            String(localized: "\(suiveurs) personne prépare cette course"),
                            String(localized: "\(suiveurs) personnes préparent cette course")))
                    }
                }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var videHonnete: some View {
        VStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 26)).foregroundColor(RUColor.text3)
            Text("Aucune course en vue")
                .font(RUFont.sans(.emphasis, weight: .bold))
                .foregroundColor(RUColor.textPrimary)
            Text("Cherche celle que tu prépares. Sur sa page tu verras qui la court aussi, à quelle allure, et où ils en sont de leur préparation.")
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }

    private var boutonCreer: some View {
        Button(action: { creationPresentee = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("AJOUTER UNE COURSE")
            }
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func message(_ texte: String) -> some View {
        Text(texte)
            .font(RUFont.sans(.body))
            .foregroundColor(RUColor.text3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
    }

    // MARK: - Chargement

    private func charger() async {
        loadError = nil
        if Demonstration.enCours {
            mine = [appState.cachedRacePage?.race].compactMap { $0 }
            upcoming = []
            isLoading = false
            return
        }
        do {
            // Les deux listes ensemble : elles s'affichent ensemble, et les charger l'une après
            // l'autre ferait apparaître la page en deux temps.
            async let miennes = clubService.myRaces()
            async let aVenir = clubService.upcomingRaces()
            mine = try await miennes
            upcoming = try await aVenir
        } catch {
            loadError = PanneReseau.motif(pour: error)
        }
        isLoading = false
    }
}
