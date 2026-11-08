import SwiftUI

/// CE QUE LE CLUB PRÉPARE, CE QU'IL A TENU, ET SES RECORDS.
///
/// Trois sections sorties de `ClubView`, et c'est UNE donnée qui les tient ensemble :
/// `ClubHighlights`, chargée une fois quand l'aperçu s'affiche. Aucune autre partie de l'écran
/// ne la lit — relevé avant de couper, comme pour le classement.
///
/// Elle est donc un `@State` d'ici, et son chargement avec elle. Rien n'entre, rien ne sort :
/// cette vue ne touche aucun état du parent, pas même en `@Binding`. C'est la région la plus
/// autonome du fichier, et c'est pour ça qu'elle part en deuxième.
///
/// POURQUOI CES TROIS SECTIONS ET PAS UNE DE PLUS. Un classement dit qui court le plus ; il ne
/// dit ni vers quoi le club court, ni ce qu'il a déjà réussi. Les trois ci-dessous ne demandent
/// aucune donnée nouvelle — elles étaient dans les courses suivies et dans les sorties
/// publiées, jamais regardées ensemble.
struct ClubHighlightsSections: View {
    @Environment(AppState.self) private var appState

    private var auth: AuthService { appState.auth }
    private var clubService: ClubService { ClubService(auth: auth) }

    /// Ce que le club prépare, et ce qu'il a fait de mieux. Chargé à part du tableau de bord :
    /// celui-ci part à chaque ouverture du Club, celui-là seulement quand l'aperçu s'affiche.
    @State private var highlights: ClubHighlights?

    /// Y A-T-IL QUELQUE CHOSE À MONTRER ? La question existe parce que ces trois sections
    /// étaient trois enfants DIRECTS de la pile de l'aperçu, espacés de 24.
    ///
    /// Les regrouper dans une vue en fait UN enfant. Quand les trois se taisent — un club tout
    /// neuf — chacune rendait auparavant une vue vide, et une pile n'espace pas autour du vide ;
    /// une pile vide, elle, est un enfant de hauteur nulle, et le parent l'espacerait de 24 de
    /// part et d'autre. Quarante-huit points de blanc apparaîtraient sur l'écran d'un club qui
    /// vient d'être créé, c'est-à-dire exactement là où l'aperçu a été retravaillé pour ne plus
    /// montrer trois sections vides.
    ///
    /// La condition reprend donc celle de chaque section. C'est une redite, et elle est tenue
    /// à UN endroit, en vis-à-vis des trois `if` qu'elle résume.
    private var aQuelqueChose: Bool {
        !(highlights?.races.isEmpty ?? true)
            || (highlights?.sessionHistory?.total ?? 0) > 0
            || !(highlights?.records.isEmpty ?? true)
            || highlights?.bestWeek != nil
    }

    /// Le même écart de 24 qu'entre les autres sections de l'aperçu — celui que la pile du
    /// parent appliquait quand ces trois-là étaient ses enfants directs.
    var body: some View {
        Group {
            if aQuelqueChose {
                VStack(alignment: .leading, spacing: 24) {
                    coursesDuClub
                    seancesTenues
                    recordsDuClub
                }
            }
        }
        .task { await chargerLesPepites() }
    }

    // MARK: - Ce que le club prépare

    @ViewBuilder
    private var coursesDuClub: some View {
        if let courses = highlights?.races, !courses.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Ce que le club prépare")
                VStack(spacing: 0) {
                    ForEach(Array(courses.enumerated()), id: \.element.id) { rang, course in
                        if rang > 0 { RUFilet() }
                        ligneDeCourseDuClub(course)
                    }
                }
            }
            .padding(RUSpacing.cardPadding)
            .ruCard()
        }
    }

    private func ligneDeCourseDuClub(_ course: ClubRace) -> some View {
        Button(action: { appState.ouvrirLaCourse(course.race) }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let jours = course.race.joursRestants, jours >= 0 {
                        Text(jours == 0 ? String(localized: "C'est aujourd'hui")
                                        : String(localized: "J-\(jours)"))
                            .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6)
                            .foregroundColor(RUColor.rose2)
                    }
                    Text(course.race.name)
                        .font(RUFont.sans(.label, weight: .semibold))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1)
                    if !course.race.sousTitre.isEmpty {
                        Text(course.race.sousTitre)
                            .font(RUFont.sans(.small))
                            .foregroundColor(RUColor.text3)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                // Les visages, et le compte à côté. « 3 » seul ne dit pas QUI prépare la même
                // course que moi — et c'est exactement la question qu'on se pose en lisant cette
                // liste dans un club.
                HStack(spacing: -8) {
                    ForEach(course.runners) { coureur in
                        AvatarView(urlString: coureur.avatarUrl, base64DataURI: coureur.avatarBase64,
                                   initial: String(coureur.name.prefix(1)), size: 26, seed: coureur.id)
                            .overlay(Circle().stroke(RUColor.bg, lineWidth: 2))
                    }
                }
                if course.members > course.runners.count {
                    Text("+\(course.members - course.runners.count)")
                        .font(RUFont.sans(.small, weight: .bold))
                        .foregroundColor(RUColor.text2)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Pluriel.choisir(course.members,
            String(localized: "\(course.race.name), \(course.members) membre la prépare"),
            String(localized: "\(course.race.name), \(course.members) membres la préparent")))
    }

    // MARK: - Les séances tenues

    /// « ON ÉTAIT 28 MARDI DERNIER. »
    ///
    /// La phrase dont un crew est fier, et la seule preuve qu'un club VIT : un classement dit
    /// qui court, pas si on se retrouve. Elle n'existait nulle part — une séance hebdomadaire
    /// s'avance d'une semaine et vide ses présences, donc ce qui s'était passé disparaissait
    /// chaque semaine au profit de la suivante.
    ///
    /// La MOYENNE d'abord, le total ensuite : vingt séances à trois personnes et vingt séances à
    /// trente ne sont pas le même club, et c'est la moyenne qui le dit.
    @ViewBuilder
    private var seancesTenues: some View {
        if let histo = highlights?.sessionHistory, histo.total > 0 {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Les séances tenues")
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    // Pas de `Pluriel` ici : « au départ en moyenne » ne s'accorde pas, et
                    // appeler le choix de pluriel avec deux fois la même phrase donnerait deux
                    // clés identiques au catalogue et un faux air de règle.
                    RUChiffre(valeur: "\(histo.averageAttendees)", unite: "au départ en moyenne")
                    Spacer(minLength: 8)
                    Text(Pluriel.choisir(histo.total,
                                         String(localized: "\(histo.total) séance"),
                                         String(localized: "\(histo.total) séances")))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                }
                VStack(spacing: 0) {
                    ForEach(Array(histo.recent.enumerated()), id: \.element.id) { rang, seance in
                        if rang > 0 { RUFilet() }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.semaineFormatter.string(from: seance.heldAt))
                                    .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6)
                                    .foregroundColor(RUColor.text3)
                                Text(seance.title)
                                    .font(RUFont.sans(.body, weight: .semibold))
                                    .foregroundColor(RUColor.textPrimary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("\(seance.attendees) au départ")
                                .font(RUFont.sans(.body, weight: .semibold))
                                .foregroundColor(RUColor.text2)
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(RUSpacing.cardPadding)
            .ruCard()
        }
    }

    // MARK: - Les records du club

    @ViewBuilder
    private var recordsDuClub: some View {
        let records = highlights?.records ?? []
        if !records.isEmpty || highlights?.bestWeek != nil {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Les records du club")
                VStack(spacing: 0) {
                    // LE RECORD COLLECTIF EN TÊTE, et c'est l'ordre juste : les trois suivants
                    // nomment quelqu'un, celui-ci dit ce que le club a fait ENSEMBLE. Sur la page
                    // d'un club, c'est la phrase la plus à sa place.
                    if let semaine = highlights?.bestWeek {
                        ligneDeLaMeilleureSemaine(semaine)
                        if !records.isEmpty { RUFilet() }
                    }
                    ForEach(Array(records.enumerated()), id: \.element.id) { rang, record in
                        if rang > 0 { RUFilet() }
                        ligneDeRecord(record)
                    }
                }
            }
            .padding(RUSpacing.cardPadding)
            .ruCard()
        }
    }

    /// Pas d'avatar, et c'est le propos : personne ne possède cette ligne.
    ///
    /// Mais sa PLACE est gardée. Sans ce vide de 32 points, son intitulé commençait au bord de
    /// l'écran pendant que les trois records nominatifs démarraient derrière leur photo : quatre
    /// lignes d'une même liste avec deux marges gauches différentes. L'absence de visage se lit
    /// alors comme un défaut d'alignement, là où elle doit se lire comme ce qu'elle est —
    /// personne ne possède ce record.
    private func ligneDeLaMeilleureSemaine(_ semaine: ClubBestWeek) -> some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 32, height: 1)
            VStack(alignment: .leading, spacing: 4) {
                // GRISE COMME LES TROIS AUTRES, et sa prééminence reste entière.
                //
                // Elle était la seule étiquette rose de la page. Or ce qui fait de cette ligne
                // la première n'est pas sa couleur, c'est sa TAILLE : son chiffre est à 38
                // points quand les trois autres sont à 24. L'argument est écrit juste en
                // dessous — « l'écart entre les deux est ce qui fait de l'un un titre et des
                // autres une liste ». Le rose doublait ce travail déjà fait, et le dépensait
                // sur une étiquette de treize points.
                Text("La plus grosse semaine")
                    .font(RUFont.sans(.small, weight: .medium))
                    .foregroundColor(RUColor.text3)
                // LE CHIFFRE DE LA PAGE, ET IL N'Y EN A QU'UN.
                //
                // Une page sans point de fixation se lit comme une liste, quelle que soit la
                // qualité de ses alignements : l'œil n'a nulle part où se poser d'abord, donc
                // il balaie. C'est ce qui donne à cet écran son air « lisse » — rien n'y est
                // deux fois plus grand que son voisin.
                //
                // Le record COLLECTIF est le bon candidat, et pas par défaut : c'est le seul
                // chiffre de la page qui appartienne au club entier plutôt qu'à quelqu'un, et
                // le seul dont la valeur grandit quand le club grandit. Les trois records
                // nominatifs qui suivent restent au cran `.title` — 38 points contre 24 est
                // précisément ce qui fait de l'un un titre et des autres une liste.
                RUChiffre(valeur: Distances.valeur(semaine.km), unite: "km", cran: .hero)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Pluriel.choisir(semaine.runners,
                                     String(localized: "\(semaine.runners) coureuse"),
                                     String(localized: "\(semaine.runners) coureuses")))
                    .font(RUFont.sans(.body, weight: .semibold))
                    .foregroundColor(RUColor.text2)
                Text(Self.semaineFormatter.string(from: semaine.startsAt))
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// « semaine du 6 oct. » — le lundi, puisque c'est là que la semaine du club commence.
    private static let semaineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()

    /// Chaque record OUVRE la sortie qui le porte. Un record qu'on ne peut pas aller voir est une
    /// ligne de statistique ; un record qui mène au tracé, aux splits et au profil de celle qui
    /// l'a couru est une histoire du club.
    private func ligneDeRecord(_ record: ClubRecord) -> some View {
        Button(action: { appState.ouvrirLaSortie(record.activityId) }) {
            HStack(spacing: 12) {
                AvatarView(urlString: record.avatarUrl, base64DataURI: record.avatarBase64,
                           initial: String(record.name.prefix(1)), size: 32, seed: record.userId)
                VStack(alignment: .leading, spacing: 2) {
                    // CAPITALES ESPACÉES → LA MICRO-ÉTIQUETTE DU SYSTÈME.
                    //
                    // « LA PLUS LONGUE » en capitales suivies, à côté d'un écran dont toutes les
                    // autres étiquettes sont en minuscules grises depuis le bilan hebdomadaire.
                    // Des capitales espacées donnent à une étiquette le poids d'un titre — c'est
                    // une convention de tableau de bord, et elle fabrique du bruit sur une page
                    // qui en compte déjà quatre.
                    Text(libelleDuRecord(record.genre))
                        .font(RUFont.sans(.small, weight: .medium))
                        .foregroundColor(RUColor.text3)
                    let part = recordEnDeuxParts(record)
                    RUChiffre(valeur: part.valeur, unite: part.unite, cran: .title)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.nomComplet)
                        .font(RUFont.sans(.body, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                        .lineLimit(1)
                    Text(record.createdAt.relativeDescription)
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    private func libelleDuRecord(_ genre: String) -> String {
        switch genre {
        case "distance": return String(localized: "La plus longue")
        case "allure": return String(localized: "La plus rapide")
        default: return String(localized: "Le plus de dénivelé")
        }
    }

    /// LE CHIFFRE ET SON UNITÉ, SÉPARÉS — comme partout ailleurs depuis `RUChiffre`.
    ///
    /// `valeurDuRecord` rendait « 8,1 km » d'un bloc, donc le « km » prenait la taille du
    /// chiffre. C'est exactement le défaut que `RUChiffre` a corrigé sur neuf autres écrans ;
    /// celui-ci, qui est la page d'accueil d'un club, y avait échappé.
    private func recordEnDeuxParts(_ record: ClubRecord) -> (valeur: String, unite: String?) {
        switch record.genre {
        case "distance":
            guard let km = record.distanceKm else { return ("—", nil) }
            return (Distances.valeur(km), "km")
        case "allure":
            // « /km » reste collé au sens : sans unité, « 4:12 » se lit comme un temps.
            guard let sec = record.secPerKm else { return ("—", nil) }
            return (TimeFormat.allure(secondesParKm: sec), "/km")
        default:
            guard let m = record.elevationGainM else { return ("—", nil) }
            return ("\(m)", "m")
        }
    }

    private func chargerLesPepites() async {
        if Demonstration.enCours {
            highlights = appState.cachedClubHighlights
            return
        }
        guard highlights == nil, auth.isSignedIn else { return }
        // Silencieux en cas d'échec, et c'est voulu : ce sont deux sections EN PLUS. Une
        // bannière d'erreur pour elles ferait croire que tout l'aperçu est en panne alors que
        // le niveau, la semaine, le défi et les sorties sont là.
        highlights = try? await clubService.fetchClubHighlights()
    }
}
