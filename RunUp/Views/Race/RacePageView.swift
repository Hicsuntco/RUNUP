import SwiftUI
import UIKit

/// LA PAGE D'UNE COURSE.
///
/// Quatre choses, dans cet ordre, parce que c'est l'ordre dans lequel on s'en sert :
///
///   1. la course — quand, où, combien ;
///   2. ce que MOI j'y vise, et ce que j'accepte de montrer ;
///   3. qui la prépare aussi, celles et ceux qui cherchent quelqu'un d'abord, puis les plus
///      proches de mon allure ;
///   4. le mur : questions, recherches de partenaire, dossards à céder ou à trouver.
///
/// # LE PARTAGE DE L'ENTRAÎNEMENT EST UN CHOIX, PAS UN RÉGLAGE PAR DÉFAUT
///
/// Montrer à des inconnus où quelqu'un en est de sa préparation n'est pas la même chose que lui
/// montrer qu'il court la même course. Le volume ne sort du serveur que pour qui a coché la case —
/// et quand elle n'est pas cochée, il n'est même pas CALCULÉ (voir api/races/[action].js). Ici,
/// `nil` s'affiche « n'a pas partagé », jamais « 0 km » : confondre les deux serait accuser
/// quelqu'un de ne pas s'entraîner parce qu'il tient à sa vie privée.
///
/// # LE MUR DE DOSSARDS N'ENCAISSE RIEN
///
/// Il met deux personnes en contact et s'arrête là : aucun paiement, aucune garantie, aucune
/// vérification. La plupart des organisateurs INTERDISENT le transfert de dossard — courir sous le
/// nom d'un autre, c'est la disqualification, et surtout des secours qui liraient le mauvais
/// dossier médical. L'avertissement est écrit sur chaque annonce et au moment d'en écrire une,
/// plutôt que de faire comme si la question ne se posait pas.
struct RacePageView: View {
    var race: RaceEvent
    /// Appelé quand je me mets à suivre la course, ou que j'arrête : la liste d'où l'on vient
    /// porte « Je prépare », et elle serait fausse au retour.
    var onParticipationChanged: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var page: RacePage?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var enCours = false

    // Ma participation
    @State private var chrono = ""
    @State private var cherchePartenaire = false
    @State private var partageEntrainement = false
    @State private var formulairePresente = false

    // Le mur
    @State private var genreDuMessage = "message"
    @State private var brouillon = ""
    @State private var reponseA: RacePost?
    @State private var filtrePartenaires = false

    // Modération
    @State private var signalementPresente = false
    @State private var motifDuSignalement = ""
    @State private var cibleDuSignalement: CibleSignalee?

    private struct CibleSignalee: Identifiable {
        var id: String { targetId }
        var targetType: String
        var targetId: String
    }

    private var clubService: ClubService { ClubService(auth: appState.auth) }
    private var courante: RaceEvent { page?.race ?? race }
    private var jeLaPrepare: Bool { page?.me != nil }

    var body: some View {
        VStack(spacing: 0) {
            retour
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    entete

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else if let loadError {
                        Text("Impossible de charger cette page — \(loadError).")
                            .font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        maParticipation
                        quiLaPrepare
                        leMur
                        boutonSignalerLaCourse
                    }
                }
                .padding(RUSpacing.pagePadding)
                .padding(.bottom, 24)
            }
        }
        .background(RUColor.pageBackground)
        .task { if page == nil { await charger() } }
        .alert("Signaler", isPresented: $signalementPresente) {
            TextField("Pourquoi ?", text: $motifDuSignalement)
            Button("Envoyer") { envoyerLeSignalement() }
            Button("Annuler", role: .cancel) { cibleDuSignalement = nil }
        } message: {
            Text("Ce signalement sera examiné. Merci de préciser ce qui pose problème.")
        }
    }

    /// Le chemin de retour. Une feuille se referme d'un glissement vers le bas ; un écran plein
    /// n'a rien de tel, et sans ce bouton on serait enfermé dedans.
    private var retour: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                Text("Courses").font(RUFont.sans(.label, weight: .semibold))
            }
            .foregroundColor(RUColor.text2)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Retour aux courses")
    }

    // MARK: - 1. La course

    private var entete: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Un disque de dégradé rose de 46 points en haut de CHAQUE page de course :
                // la première chose que l'œil rencontrait était une couleur, pas le nom de la
                // course. L'anneau garde la forme et rend la couleur au seul endroit de la page
                // qui en a besoin — le compte à rebours.
                ZStack {
                    Circle().fill(RUColor.card2)
                    Circle().strokeBorder(RUColor.line, lineWidth: RUSpacing.hairline)
                    Image(systemName: courante.disciplineSymbole)
                        .font(.system(size: 17)).foregroundColor(RUColor.text2)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(courante.name)
                        .font(RUFont.display(21))
                        .foregroundColor(RUColor.textPrimary)
                    Text(courante.dateLisible)
                        .font(RUFont.sans(.label, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                }
                Spacer(minLength: 0)
            }

            if !courante.sousTitre.isEmpty {
                Text(courante.sousTitre)
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text3)
            }

            HStack(spacing: 10) {
                if let jours = courante.joursRestants, jours >= 0 {
                    pastille(jours == 0
                             ? String(localized: "C'est aujourd'hui")
                             : Pluriel.choisir(jours,
                                String(localized: "Dans \(jours) jour"),
                                String(localized: "Dans \(jours) jours")),
                             teinte: RUColor.rose)
                }
                if let coureurs = page?.runners.count, coureurs > 0 {
                    pastille(Pluriel.choisir(coureurs,
                        String(localized: "\(coureurs) coureur"),
                        String(localized: "\(coureurs) coureurs")), teinte: RUColor.text2)
                }
            }

            if let site = courante.website, let url = URL(string: site) {
                // Le seul lien sortant de la page, et il est écrit par un coureur. Le serveur
                // n'accepte que http(s) — ni `javascript:`, ni `data:`, voir lib/courses.js.
                Button(action: { openURL(url) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 11))
                        Text("Site officiel").font(RUFont.sans(.body, weight: .semibold))
                    }
                    .foregroundColor(RUColor.rose2)
                    .frame(minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func pastille(_ texte: String, teinte: Color) -> some View {
        Text(texte)
            .font(RUFont.sans(.small, weight: .bold))
            .foregroundColor(teinte)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(teinte.opacity(0.14), in: Capsule())
    }

    // MARK: - 2. Ma participation

    @ViewBuilder
    private var maParticipation: some View {
        VStack(alignment: .leading, spacing: 12) {
            if jeLaPrepare {
                RUCardHeader(icon: "checkmark.circle.fill", tint: RUColor.lime, title: "Je prépare cette course")

                if let objectif = page?.me?.targetChrono, !objectif.isEmpty {
                    ligneDInfo(titre: String(localized: "Objectif"), valeur: objectif)
                }
                if let allure = page?.me?.targetPaceSecPerKm {
                    ligneDInfo(titre: String(localized: "Allure visée"),
                               valeur: String(localized: "\(TimeFormat.allure(secondesParKm: Double(allure))) /km"))
                }

                HStack(spacing: 10) {
                    Button(action: { ouvrirLeFormulaire() }) {
                        Text("MODIFIER")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: { Task { await nePlusPreparer() } }) {
                        Text("RETIRER")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(enCours)
                }
            } else {
                RUCardHeader(icon: "flag.checkered", tint: RUColor.rose2, title: "Tu la prépares ?")
                Text("Dis-le et tu apparaîtras sur cette page. Tu pourras y trouver quelqu'un à ton allure, et suivre où en sont les autres.")
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text3)
                Button(action: { ouvrirLeFormulaire() }) {
                    Text("JE PRÉPARE CETTE COURSE")
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: enCours))
                .disabled(enCours)
            }
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
        .sheet(isPresented: $formulairePresente) { formulaireDeParticipation.runUpSheetStyle() }
    }

    private func ligneDInfo(titre: String, valeur: String) -> some View {
        HStack {
            Text(titre).font(RUFont.sans(.body)).foregroundColor(RUColor.text3)
            Spacer(minLength: 8)
            Text(valeur).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
        }
    }

    private func ouvrirLeFormulaire() {
        chrono = page?.me?.targetChrono ?? ""
        cherchePartenaire = page?.me?.lookingForPartner ?? false
        partageEntrainement = page?.me?.sharesTraining ?? false
        formulairePresente = true
    }

    private var formulaireDeParticipation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ce que tu vises")
                    .font(RUFont.display(21))
                    .foregroundColor(RUColor.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Chrono visé · facultatif")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.text3)
                    TextField("3:30, sub-4, finir…", text: $chrono)
                        .textFieldStyle(.plain)
                        .font(RUFont.sans(.emphasis))
                        .foregroundColor(RUColor.textPrimary)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    // Le chrono est libre, mais s'il se lit comme un temps l'app en tire une
                    // allure — et c'est elle qui range la page par proximité. « Finir » reste un
                    // objectif valable ; il ne donne simplement personne à comparer.
                    if let allure = allureVisee {
                        Text("Soit \(TimeFormat.allure(secondesParKm: allure)) /km")
                            .font(RUFont.sans(.small))
                            .foregroundColor(RUColor.text3)
                    }
                }

                // DEUX INTERRUPTEURS DANS UNE CARTE, PAS DEUX CARTES.
                //
                // Chacun avait la sienne, et deux rectangles posés l'un sur l'autre pour deux
                // cases à cocher font une liste de boîtes. Ils appartiennent à la même question —
                // « qu'est-ce que j'accepte de montrer ? » — donc à la même carte, séparés par un
                // filet.
                VStack(spacing: 0) {
                    interrupteur(
                        titre: String(localized: "Je cherche quelqu'un pour courir avec moi"),
                        detail: String(localized: "Tu apparais en haut de la liste, pour celles et ceux qui visent la même allure."),
                        actif: $cherchePartenaire
                    )
                    Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                    interrupteur(
                        titre: String(localized: "Montrer où j'en suis de ma préparation"),
                        detail: String(localized: "Les autres coureurs de cette course verront ton volume des 4 dernières semaines. Rien d'autre : ni tes parcours, ni tes allures réelles, ni tes dates de sortie."),
                        actif: $partageEntrainement
                    )
                }
                .ruCard()

                Button(action: { Task { await enregistrerMaParticipation() } }) {
                    Text(enCours ? String(localized: "Enregistrement…") : String(localized: "ENREGISTRER"))
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: enCours))
                .disabled(enCours)
            }
            .padding(RUSpacing.pagePadding)
        }
        .background(RUColor.pageBackground)
    }

    /// L'allure que l'app tire du chrono tapé, quand la course a une distance et que le chrono se
    /// lit comme un temps. Sinon nil — et la page ne perd rien, elle range par nom.
    private var allureVisee: Double? {
        guard let km = courante.distanceKm, km > 0 else { return nil }
        let propre = chrono.trimmingCharacters(in: .whitespaces)
        guard !propre.isEmpty, let secondes = PaceModel.parseChronoSeconds(propre, distance: nil) else { return nil }
        let allure = secondes / km
        // Bornes du serveur : 2 min/km est plus rapide qu'un record du monde, 20 min/km est de la
        // marche. Au-delà, c'est une lecture ratée, pas un objectif.
        guard allure >= 120, allure <= 1200 else { return nil }
        return allure
    }

    private func interrupteur(titre: String, detail: String, actif: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: actif) {
                Text(titre)
                    .font(RUFont.sans(.label, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
            }
            .tint(RUColor.rose)
            Text(detail)
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text3)
        }
        .padding(RUSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 3. Qui la prépare

    private var coureursAffiches: [RaceRunner] {
        let tous = page?.runners ?? []
        return filtrePartenaires ? tous.filter(\.lookingForPartner) : tous
    }

    @ViewBuilder
    private var quiLaPrepare: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(title: "Qui la prépare")

            if (page?.runners ?? []).contains(where: \.lookingForPartner) {
                Toggle(isOn: $filtrePartenaires) {
                    Text("Seulement ceux qui cherchent quelqu'un")
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text2)
                }
                .tint(RUColor.rose)
            }

            if coureursAffiches.isEmpty {
                // Tournure sans accord : « sois le premier » obligerait à passer par `Accord`, et
                // « la première / le premier » pour une phrase de vide n'en vaut pas les deux clés.
                Text("Personne encore. Dis-le et les suivants te trouveront.")
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text3)
                    .padding(.vertical, 8)
            } else {
                // DES LIGNES, PAS DES BOÎTES. Chaque coureur était dans un rectangle rempli posé
                // dans une section qui n'en est pas un : huit boîtes empilées pour huit lignes de
                // liste. Un filet entre deux lignes sépare aussi bien et ne fabrique rien.
                VStack(spacing: 0) {
                    ForEach(Array(coureursAffiches.enumerated()), id: \.element.id) { rang, coureur in
                        if rang > 0 {
                            Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                        }
                        ligneDeCoureur(coureur)
                    }
                }
            }
        }
    }

    private func ligneDeCoureur(_ coureur: RaceRunner) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Button(action: { appState.ouvrirLeProfil(coureur.id) }) {
                AvatarView(urlString: coureur.avatarUrl, base64DataURI: coureur.avatarBase64,
                           initial: String(coureur.nomComplet.prefix(1)), size: 36, seed: coureur.id)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(String(localized: "Voir le profil de \(coureur.nomComplet)"))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    // Un nom est une porte. Avant, c'était du texte mort : on voyait que quelqu'un
                    // préparait la même course sans pouvoir regarder qui c'était.
                    Button(action: { appState.ouvrirLeProfil(coureur.id) }) {
                        Text(coureur.nomComplet)
                            .font(RUFont.sans(.label, weight: .semibold))
                            .foregroundColor(RUColor.textPrimary)
                            .lineLimit(1)
                            // « Margaux Hubert » prenait toute la largeur et la pastille à sa
                            // droite se faisait couper par le bord de l'écran — la capture le
                            // montrait, un contour ouvert. Un nom se tronque proprement avec ses
                            // points de suspension ; une capsule tronquée est un défaut.
                            .truncationMode(.tail)
                    }
                    .buttonStyle(PressableStyle())
                    .layoutPriority(0)
                    if coureur.lookingForPartner {
                        // Un contour, pas un fond. Sur une liste où la plupart cherchent
                        // quelqu'un, la pastille pleine se répétait à chaque ligne et finissait
                        // par peindre la colonne ; le trait dit la même chose sans la masse.
                        Text("cherche quelqu'un")
                            .font(RUFont.sans(.small, weight: .semibold))
                            .foregroundColor(RUColor.rose2)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(RUColor.rose2.opacity(0.4),
                                                            lineWidth: RUSpacing.hairline))
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                    }
                }

                if let objectif = coureur.targetChrono, !objectif.isEmpty {
                    Text(ligneDObjectif(coureur, objectif: objectif))
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text2)
                }

                // La ligne qui demande le plus de soin de la page. Voir le commentaire en tête :
                // « n'a pas partagé » et « 0 km » ne sont pas la même phrase.
                if let km = coureur.km4Weeks {
                    Text(String(localized: "\(Distances.km(km)) sur 4 semaines · \(sortiesLisibles(coureur.runs4Weeks ?? 0))"))
                        // Était en chasse fixe : une deuxième typographie pour une ligne qui
                        // n'aligne rien en colonne, donc un corps étranger au milieu de la liste.
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                } else {
                    Text("préparation non partagée")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                }
            }
            Spacer(minLength: 0)

            Menu {
                Button("Signaler ce coureur") {
                    demanderUnSignalement(type: "user", id: coureur.id)
                }
                Button("Bloquer", role: .destructive) {
                    Task { await bloquer(coureur) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(RUColor.text3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Plus d'options")
        }
        .padding(.vertical, 11)
    }

    /// « 14 sorties ». À part, et non imbriqué dans l'interpolation de la ligne au-dessus : une
    /// clé de catalogue qui contient elle-même un appel ne se relit pas, et ne se traduit pas.
    private func sortiesLisibles(_ sorties: Int) -> String {
        Pluriel.choisir(sorties,
                        String(localized: "\(sorties) sortie"),
                        String(localized: "\(sorties) sorties"))
    }

    /// « 3:30 · 4:59 /km » et, quand c'est le cas, « à ton allure ». Le rapprochement d'allure est
    /// le seul service que cette liste rende vraiment : courir avec quelqu'un de deux minutes plus
    /// rapide au kilomètre n'est pas courir ensemble.
    private func ligneDObjectif(_ coureur: RaceRunner, objectif: String) -> String {
        var morceaux = [objectif]
        if let allure = coureur.targetPaceSecPerKm {
            morceaux.append(String(localized: "\(TimeFormat.allure(secondesParKm: Double(allure))) /km"))
            if let mienne = page?.me?.targetPaceSecPerKm, abs(allure - mienne) <= 15 {
                morceaux.append(String(localized: "à ton allure"))
            }
        }
        return morceaux.joined(separator: " · ")
    }

    // MARK: - 4. Le mur

    private static let genres = ["message", "partner", "bib_offer", "bib_wanted"]

    private static func libelleDuGenre(_ genre: String) -> String {
        switch genre {
        case "partner": return String(localized: "Partenaire")
        case "bib_offer": return String(localized: "Je cède")
        case "bib_wanted": return String(localized: "Je cherche")
        default: return String(localized: "Message")
        }
    }

    /// Le plus récent en haut. `sorted` et non `reversed` : le serveur rend le fil dans l'ordre
    /// chronologique pour que les réponses suivent leur message, et trier explicitement dit ce
    /// qu'on veut au lieu de dépendre de cet ordre.
    private var messagesDeTete: [RacePost] {
        (page?.posts ?? []).filter { $0.parentId == nil }.sorted { $0.createdAt > $1.createdAt }
    }

    private func reponses(a message: RacePost) -> [RacePost] {
        (page?.posts ?? []).filter { $0.parentId == message.id }
    }

    private var leMur: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(title: "Le mur")

            redaction

            if messagesDeTete.isEmpty {
                Text("Rien d'écrit encore. Une question sur le parcours, le ravitaillement, l'hébergement — c'est ici.")
                    .font(RUFont.sans(.body))
                    .foregroundColor(RUColor.text3)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(messagesDeTete.enumerated()), id: \.element.id) { rang, message in
                        bloc(message, rang: rang)
                    }
                }
            }
        }
    }

    private var redaction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $genreDuMessage) {
                ForEach(Self.genres, id: \.self) { genre in
                    Text(Self.libelleDuGenre(genre)).tag(genre)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(reponseA != nil)

            if let reponseA {
                HStack(spacing: 6) {
                    Text("Réponse à \(reponseA.author.name)")
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                    Button(action: { self.reponseA = nil }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(RUColor.text3)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Annuler la réponse")
                }
            }

            // L'avertissement est écrit AU MOMENT D'ÉCRIRE, et pas seulement sous les annonces
            // publiées : c'est là qu'il peut encore changer quelque chose.
            if genreDuMessage == "bib_offer" || genreDuMessage == "bib_wanted", reponseA == nil {
                avertissementDossard
            }

            TextField(reponseA == nil ? placeholderDuGenre : String(localized: "Ta réponse…"),
                      text: $brouillon, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.textPrimary)
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

            Button(action: { Task { await publier() } }) {
                Text("PUBLIER")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(brouillon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || enCours)
        }
    }

    private var placeholderDuGenre: String {
        switch genreDuMessage {
        case "partner": return String(localized: "Ton allure, ton objectif, et à partir de quand tu veux courir accompagné")
        case "bib_offer": return String(localized: "Ta distance, et pourquoi tu cèdes ton dossard")
        case "bib_wanted": return String(localized: "La distance que tu cherches")
        default: return String(localized: "Une question, un conseil, un repère sur le parcours…")
        }
    }

    /// UN FILET VERTICAL, PAS UNE BOÎTE.
    ///
    /// C'était un pavé ambre rempli, posé À L'INTÉRIEUR de la carte d'un message : une boîte dans
    /// une boîte, et la chose la plus colorée du mur alors qu'elle ne demande rien — elle avertit.
    /// Un filet ambre à gauche du texte dit « attention » aussi bien, sans fabriquer un second
    /// rectangle ni repeindre un dixième de l'écran.
    private var avertissementDossard: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(RUColor.amber.opacity(0.65))
                .frame(width: 2)
            Text("RUNUP ne vend rien et ne garantit rien : vous vous arrangez entre vous. La plupart des organisateurs interdisent le transfert de dossard — vérifie leur règlement. Courir sous le nom d'un autre, c'est la disqualification, et des secours qui liraient le mauvais dossier médical.")
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.amberText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// LE MÊME TRAITEMENT QUE LE FIL : un filet entre deux messages, et rien autour.
    ///
    /// Chaque message portait sa carte, et la carte portait la boîte de l'avertissement dossard.
    /// Trois rectangles emboîtés pour une phrase. Un mur de conversation se descend ; une pile de
    /// cartes se parcourt.
    private func bloc(_ message: RacePost, rang: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if rang > 0 {
                Rectangle()
                    .fill(RUColor.line)
                    .frame(height: RUSpacing.hairline)
                    .padding(.bottom, 6)
            }
            messageEnTete(message)

            if message.kind == "bib_offer" || message.kind == "bib_wanted" {
                avertissementDossard
            }

            ForEach(reponses(a: message)) { reponse in
                HStack(alignment: .top, spacing: 8) {
                    Rectangle().fill(RUColor.line).frame(width: RUSpacing.hairline)
                    messageEnTete(reponse)
                }
                .padding(.leading, 10)
            }

            HStack(spacing: 18) {
                // Applaudir : la réponse la moins coûteuse qui dise « lu, et oui ». Sans elle, un
                // message sans réponse ne distingue pas « personne ne m'a lu » de « personne n'est
                // à mon rythme ».
                Button(action: { Task { await applaudir(message) } }) {
                    HStack(spacing: 7) {
                        Image(systemName: message.kudoedByMe ? "hands.clap.fill" : "hands.clap")
                            .font(.system(size: 15, weight: .regular))
                        if message.kudos > 0 {
                            Text("\(message.kudos)")
                                .font(RUFont.sans(.body, weight: .semibold))
                        }
                    }
                    .foregroundColor(message.kudoedByMe ? RUColor.rose : RUColor.text2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(message.kudoedByMe ? "Retirer ton applaudissement" : "Applaudir ce message")
                .accessibilityValue("\(message.kudos)")

                // LA MÊME BULLE QUE DANS LE FIL, AVEC LE MÊME COMPTE.
                //
                // C'était le mot « Répondre », en rose, à côté d'une main grise : deux formes et
                // deux poids pour deux actions jumelles, et un post qui ne se lisait pas comme
                // ceux du fil alors qu'il en est un. L'icône dit la même chose, le nombre dit en
                // plus s'il y a déjà une conversation — ce que le mot ne disait pas.
                Button(action: {
                    reponseA = message
                    brouillon = ""
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 15, weight: .regular))
                        let reponsesCount = reponses(a: message).count
                        if reponsesCount > 0 {
                            Text("\(reponsesCount)")
                                .font(RUFont.sans(.body, weight: .semibold))
                        }
                    }
                    .foregroundColor(RUColor.text2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(String(localized: "Répondre à \(message.author.name)"))

                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 10)
    }

    private func messageEnTete(_ message: RacePost) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                // Tout le bloc d'identité ouvre la page de la personne — la photo, le nom et
                // l'heure ensemble, comme partout ailleurs. Viser un mot de huit caractères
                // serait une cible de 30 points de large au milieu d'une ligne.
                Button(action: { appState.ouvrirLeProfil(message.author.id) }) {
                    HStack(spacing: 8) {
                        AvatarView(urlString: message.author.avatarUrl, base64DataURI: message.author.avatarBase64,
                                   initial: String(message.author.name.prefix(1)), size: 32, seed: message.author.id)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(message.author.name)
                                .font(RUFont.sans(.label, weight: .bold))
                                .foregroundColor(RUColor.textPrimary)
                            Text(message.createdAt.relativeDescription)
                                .font(RUFont.sans(.small))
                                .foregroundColor(RUColor.text3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(String(localized: "Voir le profil de \(message.author.name)"))
                Spacer(minLength: 0)
                if message.kind != "message" {
                    Text(Self.libelleDuGenre(message.kind))
                        .font(RUFont.sans(.small, weight: .bold))
                        .foregroundColor(RUColor.cyan)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(RUColor.cyan.opacity(0.14), in: Capsule())
                }
                Menu {
                    Button("Signaler ce message") {
                        demanderUnSignalement(type: "race_post", id: message.id)
                    }
                    // « Retiré » n'est proposé qu'à l'auteur : le serveur le revérifie de toute
                    // façon, mais montrer un bouton qui répondra « non » est une promesse fausse.
                    if !message.closed, message.isMine {
                        Button("Marquer comme réglé") { Task { await clore(message) } }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Plus d'options")
            }

            Text(message.text)
                .font(RUFont.sans(.body))
                .foregroundColor(message.closed ? RUColor.text3 : RUColor.text2)
                .strikethrough(message.closed, color: RUColor.text3)
                .fixedSize(horizontal: false, vertical: true)

            if message.closed {
                Text("réglé")
                    .font(RUFont.sans(.small, weight: .bold))
                    .foregroundColor(RUColor.lime)
            }
        }
    }

    // MARK: - Modération

    private var boutonSignalerLaCourse: some View {
        Button(action: { demanderUnSignalement(type: "race", id: courante.id) }) {
            Text("Signaler cette course")
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text3)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func demanderUnSignalement(type: String, id: String) {
        cibleDuSignalement = CibleSignalee(targetType: type, targetId: id)
        motifDuSignalement = ""
        signalementPresente = true
    }

    private func envoyerLeSignalement() {
        guard let cible = cibleDuSignalement else { return }
        let motif = motifDuSignalement.trimmingCharacters(in: .whitespacesAndNewlines)
        cibleDuSignalement = nil
        motifDuSignalement = ""
        guard !motif.isEmpty else { return }
        Task {
            try? await clubService.report(targetType: cible.targetType, targetId: cible.targetId, reason: motif)
            appState.toast(String(localized: "Signalement envoyé"))
        }
    }

    private func bloquer(_ coureur: RaceRunner) async {
        do {
            try await clubService.blockUser(userId: coureur.id)
            appState.toast(String(localized: "\(coureur.name) ne verra plus rien de toi."))
            await charger()
        } catch {
            appState.toast(String(localized: "Impossible de bloquer cette personne."))
        }
    }

    // MARK: - Actions

    private func charger() async {
        loadError = nil
        // En démonstration, le cache est tout — quatrième écran dans ce cas, même raison que les
        // trois autres : pas de serveur en face d'un simulateur.
        if Demonstration.enCours {
            page = appState.cachedRacePage
            isLoading = false
            return
        }
        do {
            page = try await clubService.racePage(raceId: race.id)
        } catch {
            loadError = PanneReseau.motif(pour: error)
        }
        isLoading = false
    }

    private func enregistrerMaParticipation() async {
        enCours = true
        let propre = chrono.trimmingCharacters(in: .whitespaces)
        do {
            try await clubService.followRace(
                raceId: race.id,
                targetChrono: propre.isEmpty ? nil : propre,
                targetPaceSecPerKm: allureVisee.map { Int($0.rounded()) },
                sharesTraining: partageEntrainement,
                lookingForPartner: cherchePartenaire
            )
            Haptics.impact(.light)
            formulairePresente = false
            await charger()
            onParticipationChanged()
        } catch {
            appState.toast(String(localized: "Impossible d'enregistrer — \(PanneReseau.motif(pour: error))."))
        }
        enCours = false
    }

    private func nePlusPreparer() async {
        enCours = true
        do {
            try await clubService.unfollowRace(raceId: race.id)
            await charger()
            onParticipationChanged()
        } catch {
            appState.toast(String(localized: "Impossible de te retirer — réessaie."))
        }
        enCours = false
    }

    private func publier() async {
        let texte = brouillon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texte.isEmpty else { return }
        enCours = true
        do {
            try await clubService.postToRace(raceId: race.id,
                                             kind: reponseA == nil ? genreDuMessage : "message",
                                             text: texte,
                                             parentId: reponseA?.id)
            brouillon = ""
            reponseA = nil
            genreDuMessage = "message"
            await charger()
        } catch ClubServiceError.badResponse(422, _) {
            appState.toast(String(localized: "Ce message ne passe pas."))
        } catch ClubServiceError.badResponse(429, _) {
            appState.toast(String(localized: "Trop de messages aujourd'hui. Réessaie demain."))
        } catch {
            appState.toast(String(localized: "Impossible de publier — \(PanneReseau.motif(pour: error))."))
        }
        enCours = false
    }

    /// Le compte vient du SERVEUR, pas d'un « +1 » posé ici : deux personnes qui applaudissent en
    /// même temps feraient sinon diverger les deux écrans jusqu'au rechargement.
    private func applaudir(_ message: RacePost) async {
        guard let index = page?.posts.firstIndex(where: { $0.id == message.id }) else { return }
        do {
            let reponse = try await clubService.toggleRacePostKudos(postId: message.id)
            page?.posts[index].kudoedByMe = reponse.kudoed
            page?.posts[index].kudos = reponse.kudos
            Haptics.impact(.light)
        } catch {
            appState.toast(String(localized: "Impossible d'applaudir — réessaie."))
        }
    }

    private func clore(_ message: RacePost) async {
        do {
            try await clubService.closeRacePost(postId: message.id)
            await charger()
        } catch {
            appState.toast(String(localized: "Impossible de marquer ce message — réessaie."))
        }
    }
}
