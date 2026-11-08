import SwiftUI

/// LES SORTIES DE GROUPE — la seule chose qui fasse d'un classement un club.
///
/// Sortie de `ClubView` en dernier, et après mesure : des trois régions qui restaient, c'est
/// celle dont l'interface est la plus étroite. 228 lignes pour QUATRE points de contact, soit
/// 57 lignes par port — contre 25 pour le mur et 15 pour l'entrée du club, dont les actions
/// sont présentées par le parent et ne se détachent donc pas. Un découpage ne gagne rien s'il
/// échange de la longueur contre de la surface d'interface.
///
/// Ce qui entre : le magasin, la liste des badges — elle vient de `@Query`, qui n'existe que
/// dans une vue, et `loadIfSignedIn` la redemande — et la liaison du drapeau qui ouvre la
/// feuille de création, parce que la carte « réveiller le club » la pose aussi.
///
/// Ce qui reste dedans : `eventEnModification`. Son bouton et sa feuille sont tous deux ici,
/// donc dans la même branche de l'arbre — la condition qui manquait aux deux feuilles mal
/// placées trouvées le 8 novembre.
struct ClubEventsSection: View {
    let magasin: ClubStore
    let badges: [ClubBadge]
    @Binding var showCreateEvent: Bool

    /// LA SORTIE QU'ON MODIFIE. Son bouton est dans `menuDeLaSortie`, juste en dessous : le
    /// déclencheur et la feuille sont dans la même vue, donc la feuille s'ouvre toujours.
    @State private var eventEnModification: ClubEvent?

    var body: some View {
        eventsCard
    }

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEE d MMM · HH:mm"
        return f
    }()

    private static let eventTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "HH:mm"
        return f
    }()

    /// « CE SOIR · 18:00 » plutôt que « MER 13 AOÛT · 18:00 » quand la sortie est aujourd'hui.
    ///
    /// La maquette insiste sur ce point et elle a raison : une sortie de groupe est une chose à
    /// laquelle on décide de se joindre MAINTENANT, et une date complète oblige à comparer
    /// mentalement avec le jour qu'on est. Purement du formatage — la donnée reste `startsAt`.
    private func eventDateLabel(_ date: Date) -> String {
        let time = Self.eventTimeFormatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return Calendar.current.component(.hour, from: date) >= 17
                ? String(localized: "CE SOIR · \(time)")
                : String(localized: "AUJOURD'HUI · \(time)")
        }
        if Calendar.current.isDateInTomorrow(date) { return String(localized: "DEMAIN · \(time)") }
        return Self.eventDateFormatter.string(from: date).uppercased()
    }

    /// Sorties de groupe — real proposed group runs with RSVP. The one feature that turns a
    /// leaderboard into an actual club: people running TOGETHER.
    /// Une SECTION, plus une carte par sortie — et c'est le seul endroit de l'onglet où
    /// l'intertitre reste sur le fond.
    ///
    /// Les sorties sont une LISTE d'objets qu'on prend un par un : chacune porte sa date, son
    /// lieu, son « J'y serai » et ses groupes d'allure. Les poser dans une carte commune
    /// donnerait une carte dans une carte, deux chromes emboîtés pour une seule hiérarchie.
    /// L'intertitre passe donc sur la page — le motif de « Mon équipement » sur le Profil — et
    /// chaque sortie devient sa propre petite carte.
    ///
    /// Ce raisonnement ne valait que pour une liste, et il avait été étendu à tout l'onglet : la
    /// semaine, le défi, les courses, les séances et les records l'avaient perdu aussi, et quatre
    /// sections flottaient sur le lavande. Elles sont redevenues des cartes ; celle-ci reste une
    /// section, parce qu'elle en contient déjà.
    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            RUCardHeader(title: "Sorties de groupe") {
                Button(action: { showCreateEvent = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(RUFont.icone(.small, weight: .bold))
                        Text("Proposer").font(RUFont.sans(.small, weight: .semibold))
                    }
                    .foregroundColor(RUColor.rose2)
                    .padding(8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
            if (magasin.board.events ?? []).isEmpty {
                Text("Aucune sortie prévue — propose un créneau, les autres n'ont qu'à dire « J'y serai ».")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    .padding(.horizontal, 2)
            }
            ForEach(magasin.board.events ?? []) { event in
                VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(eventDateLabel(event.startsAt))
                                .font(RUFont.sans(.micro, weight: .bold)).tracking(0.6).foregroundColor(RUColor.rose2)
                            // « CHAQUE SEMAINE », écrit. Sans ça, une séance qui revient se lit
                            // comme une sortie de plus, et c'est tout le contraire : c'est LE
                            // rendez-vous du club, celui autour duquel le reste s'organise.
                            if event.repeatsWeekly == true {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath").font(RUFont.icone(.micro, weight: .bold))
                                    Text("CHAQUE SEMAINE")
                                }
                                .font(RUFont.sans(.micro, weight: .bold)).tracking(0.4)
                                .foregroundColor(RUColor.text3)
                            }
                        }
                        Text(event.title).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin").font(RUFont.icone(.micro))
                                Text(location).font(RUFont.sans(.small))
                            }
                            .foregroundColor(RUColor.text2)
                        }
                    }
                    Spacer()
                    Button(action: { magasin.toggleRsvp(event) }) {
                        VStack(spacing: 2) {
                            Text(event.goingByMe ? "J'y serai ✓" : "J'y serai")
                                .font(RUFont.sans(.small, weight: .bold))
                                .foregroundColor(event.goingByMe ? .white : RUColor.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(event.goingByMe ? RUColor.rose : RUColor.card2, in: Capsule())
                                .overlay(Capsule().stroke(event.goingByMe ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                            Text("\(event.going) au départ")
                                .font(RUFont.sans(.micro)).foregroundColor(RUColor.text2)
                        }
                        // La capsule fait 25 pt de haut. C'est la seule action sociale de la carte
                        // des sorties, et elle est isolée : rien autour pour rattraper une frappe
                        // qui tombe à côté. La zone tapable monte à 44, la pastille ne bouge pas —
                        // le même traitement que les boutons-icônes de l'app.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
                groupesDAllure(event)
                }
                .padding(12)
                .ruCard(radius: RUSpacing.radiusCard)
                // L'APPUI LONG N'EST PAS UNE INTERFACE, C'EST UN RACCOURCI.
                //
                // Annuler sa propre sortie de groupe n'existait QUE sous un appui long, sans le
                // moindre indice à l'écran. Un geste que personne ne découvre n'est pas une
                // fonctionnalité : la séance du mardi restait affichée au club entier parce que
                // celle qui l'avait proposée ne savait pas comment la retirer.
                //
                // Les trois points sont posés sur la ligne, comme sur une sortie du fil et sur
                // un message du mur — un seul endroit à chercher pour reprendre ce qu'on a
                // publié, quel qu'il soit. L'appui long reste, pour qui connaît le geste.
                .contextMenu { menuDeLaSortie(event) }
            }
        }
        .sheet(item: $eventEnModification) { event in
            CreateEventSheet(onCreate: { title, location, date, chaqueSemaine, groupes in
                // Rechargé plutôt que recousu à la main : la séance modifiée peut avoir changé
                // de date, donc de PLACE dans la liste, et ses présences par groupe d'allure
                // dépendent de groupes qui viennent d'être réécrits. Reconstruire tout ça ici
                // serait refaire le travail du serveur, moins bien.
                try await magasin.modifierLaSortie(event, title: title, location: location,
                                                   startsAt: date, repeatsWeekly: chaqueSemaine,
                                                   paceGroups: groupes, badges: badges)
            }, existant: event)
            .runUpSheetStyle()
        }
    }

    /// Modifier ou annuler SA sortie de groupe. Vide pour celle de quelqu'un d'autre — un menu
    /// qui ne contient rien ne s'ouvre pas, donc rien à masquer en plus.
    @ViewBuilder
    private func menuDeLaSortie(_ event: ClubEvent) -> some View {
        if event.isMine {
            Button("Modifier cette sortie") { eventEnModification = event }
            Button("Annuler cette sortie", role: .destructive) { magasin.deleteEvent(event) }
        }
    }

    /// LES GROUPES D'ALLURE, SANS LESQUELS UNE SORTIE DE CREW NE FONCTIONNE PAS.
    ///
    /// Trente personnes au départ ne courent pas ensemble : elles partent par groupes — « 4:30 »,
    /// « 5:15 », « 6:00 et on discute ». Dire « j'y serai » sans dire à quelle allure laisse
    /// l'organisateur sans la seule information dont il ait besoin : combien de meneurs prévoir.
    ///
    /// Taper un autre groupe que le sien DÉPLACE, ça ne décommande pas : c'est le geste qu'on
    /// fait vraiment, et le contraire aurait fait disparaître sa présence d'un doigt mal posé.
    @ViewBuilder
    private func groupesDAllure(_ event: ClubEvent) -> some View {
        let groupes = event.paceGroups ?? []
        if !groupes.isEmpty {
            // Horizontal : un club peut en proposer huit, et huit pastilles sur une ligne fixe
            // se réduiraient jusqu'à l'illisible.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(groupes, id: \.self) { groupe in
                        let choisi = event.myPaceGroup == groupe
                        let compte = event.paceCounts?[groupe] ?? 0
                        Button(action: { magasin.toggleRsvp(event, groupe: groupe) }) {
                            HStack(spacing: 6) {
                                Text(groupe)
                                    .font(RUFont.sans(.small, weight: .bold))
                                if compte > 0 {
                                    Text("\(compte)")
                                        .font(RUFont.sans(.small))
                                        .foregroundColor(choisi ? RUColor.onRose.opacity(0.8) : RUColor.text3)
                                }
                            }
                            .foregroundColor(choisi ? RUColor.onRose : RUColor.text2)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                            .background(choisi ? RUColor.rose : RUColor.card2, in: Capsule())
                            .overlay(Capsule().stroke(choisi ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(String(localized: "Groupe \(groupe)"))
                        .accessibilityValue(Pluriel.choisir(compte,
                                                            String(localized: "\(compte) personne"),
                                                            String(localized: "\(compte) personnes")))
                        .accessibilityAddTraits(choisi ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}
