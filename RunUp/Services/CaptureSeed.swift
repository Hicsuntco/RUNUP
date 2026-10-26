#if DEBUG
import Foundation
import SwiftData

/// L'état de démonstration des captures de l'App Store.
///
/// # POURQUOI CE FICHIER EXISTE
///
/// Une capture d'écran de la fiche App Store doit montrer une app PLEINE : un plan, un
/// historique, des records, une série en cours. Un simulateur fraîchement lancé montre
/// l'inscription, et un vrai téléphone montre la vie de quelqu'un — donc son prénom, ses
/// kilomètres, son club et ses amis. Les six captures publiées ne peuvent être ni l'un ni
/// l'autre.
///
/// Elles étaient donc prises à la main, sur un appareil, une par une, dans trois langues : dix-huit
/// captures à refaire à chaque changement d'accent, de police ou de mise en page. En pratique ça
/// veut dire qu'on ne les refait pas — les six en ligne dataient du 30 août, portaient l'ancien
/// rose, et seules quatre des six existaient, en français seulement.
///
/// # CE QU'IL GARANTIT
///
/// L'état est posé par le VRAI chemin d'inscription (`AdaptivePlanEngine.applyOnboarding`), pas
/// par quarante affectations à la main. C'est ce qui le rend honnête : une capture montre un état
/// dans lequel l'app peut réellement se trouver, et si le moteur change, la capture change avec
/// lui au lieu de continuer à montrer une mise en page qui n'existe plus.
///
/// Les dates sont ancrées sur `maintenant` et non figées : une capture prise dans six mois doit
/// montrer une course À VENIR, pas une course passée dont le plan serait terminé.
///
/// # IL N'EXISTE PAS EN PRODUCTION
///
/// Tout le fichier est sous `#if DEBUG`. Les tests d'interface tournent sur une construction de
/// débogage ; la construction envoyée à l'App Store ne contient pas une ligne de ce qui suit, donc
/// aucun drapeau de lancement ne peut y réveiller un faux profil.
enum CaptureSeed {

    /// Le drapeau qui déclenche tout. Lu une seule fois, au lancement.
    static let drapeau = "--captures"

    /// L'écran à montrer, passé en `--ecran=stats`. Sans lui, l'accueil.
    static let prefixeEcran = "--ecran="

    static var demande: Bool {
        ProcessInfo.processInfo.arguments.contains(drapeau)
    }

    /// Le profil à ouvrir par-dessus l'écran, passé en `--profil=2`.
    ///
    /// Séparé de `--ecran=` parce qu'une page de profil n'est PAS un `AppScreen` : elle se
    /// présente au-dessus de n'importe lequel (voir `ContentRouterView`). Les deux arguments se
    /// combinent donc au lieu de se concurrencer.
    /// `--courses` : ouvrir l'écran des courses dans l'onglet social.
    static var coursesDemandees: Bool {
        ProcessInfo.processInfo.arguments.contains("--courses")
    }

    /// `--course` : ouvrir la page d'une course par-dessus l'écran.
    static var courseDemandee: Bool {
        ProcessInfo.processInfo.arguments.contains("--course")
    }

    /// `--sortie` : ouvrir la page d'une sortie par-dessus l'écran. Comme `--profil=`, elle se
    /// présente au-dessus de n'importe lequel ; l'identifiant est celui de la graine.
    static var sortieDemandee: Bool {
        ProcessInfo.processInfo.arguments.contains("--sortie")
    }

    /// `--onglet=apercu|classement|activite` : l'onglet du Club à montrer.
    ///
    /// La démonstration ouvre le Club sur son fil, parce que c'est le seul des trois onglets
    /// qu'un club inventé remplit vraiment. Les deux autres ne se photographiaient donc jamais —
    /// et une page qu'on ne photographie pas est une page qu'on juge de mémoire.
    static var ongletDuClub: String? {
        ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--onglet=") })
            .map { String($0.dropFirst("--onglet=".count)) }
    }

    /// `--mur` : ouvrir le fil plutôt que l'écran par défaut de l'onglet social.
    static var murDemande: Bool {
        ProcessInfo.processInfo.arguments.contains("--mur")
    }

    static var profilDemande: String? {
        ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--profil=") })
            .map { String($0.dropFirst("--profil=".count)) }
    }

    static var ecranDemande: AppScreen? {
        guard let brut = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefixeEcran) })?
            .dropFirst(prefixeEcran.count) else { return nil }
        return AppScreen(rawValue: String(brut))
    }

    /// Pose l'état, dans un contexte neuf, et rend le profil.
    ///
    /// Le contexte est VIDÉ d'abord : un simulateur réutilisé d'une langue à l'autre garderait
    /// sinon les relevés du tour précédent, et la capture des statistiques montrerait le double
    /// du kilométrage à chaque passage.
    @MainActor
    @discardableResult
    static func poser(dans contexte: ModelContext, maintenant: Date = .now) -> UserProfile {
        // ON VIDE EN ALLANT CHERCHER, PAS EN LOT.
        //
        // `ModelContext.delete(model:)` supprime tout d'un type en une fois, et c'était la
        // première écriture. Elle fait un effacement par lot, dont le contexte en mémoire n'a
        // pas forcément connaissance tout de suite — et l'app plantait au lancement sous ce
        // drapeau, deux séries de suite, sans que rien d'autre n'ait changé.
        //
        // Récupérer puis supprimer un par un est l'API ordinaire, celle que le reste de l'app
        // emploie partout. Le coût est nul : il y a un profil, une poignée de messages et
        // seize relevés.
        //
        // Les messages aussi, et c'est nécessaire depuis que le simulateur n'est plus effacé
        // entre deux langues : sans ça, six lancements par langue empileraient dix-huit fois la
        // même conversation.
        vider(UserProfile.self, dans: contexte)
        vider(RunRecord.self, dans: contexte)
        vider(ChatMessage.self, dans: contexte)
        try? contexte.save()

        let profil = UserProfile(name: "Charlotte")
        contexte.insert(profil)
        AdaptivePlanEngine.applyOnboarding(resultat(maintenant: maintenant), to: profil)

        // Les chiffres du jour. Ils ne viennent pas d'Apple Santé ici — personne n'a marché dans
        // un simulateur — donc ils sont posés directement, aux valeurs d'une vraie journée
        // ordinaire : les anneaux de « Ta journée » doivent être bien remplis sans l'être tous.
        // LA DATE DE REMISE À ZÉRO, D'ABORD — sinon les trois lignes qui suivent ne valent rien.
        //
        // `refreshProgramForCurrentDate`, appelée dès que la scène devient active, passe par
        // `resetDailyGoalsIfNewDay` : si `lastDailyResetDay` n'est pas aujourd'hui, elle remet
        // `runValue`, `stepsToday` et `activeCaloriesToday` à zéro. C'est exactement ce qui est
        // arrivé — l'accroche « Trois objectifs par jour » surmontait trois zéros, et l'anneau
        // de l'accueil affichait 0/3 sur un profil qui venait de poser 9 240 pas.
        profil.lastDailyResetDay = Calendar.current.startOfDay(for: maintenant)
        profil.runValue = 8.4
        // Deux anneaux pleins et un presque : une journée qui respire, et qui laisse voir à quoi
        // sert l'écran. Trois anneaux pleins ne montrent plus l'écart entre fait et à faire.
        profil.stepsToday = 9_240
        profil.activeCaloriesToday = 612
        profil.streak = 23
        profil.xp = 4_180
        profil.completedDebriefsCount = 37

        for releve in historique(maintenant: maintenant) {
            contexte.insert(releve)
        }
        for message in conversation(maintenant: maintenant) {
            contexte.insert(message)
        }
        try? contexte.save()
        return profil
    }

    private static func vider<T: PersistentModel>(_ type: T.Type, dans contexte: ModelContext) {
        for objet in (try? contexte.fetch(FetchDescriptor<T>())) ?? [] {
            contexte.delete(objet)
        }
    }

    /// LE CLUB ET LE COACH NE PASSENT PAS PAR LE RÉSEAU, ET C'EST LE CŒUR DU PROBLÈME.
    ///
    /// Quatre des six écrans se peignent tout seuls dès que la base est remplie. Deux non : le
    /// coach est une conversation, le club est un fil. Sur un simulateur sans compte, ils
    /// montreraient un écran vide — ou pire, le message d'erreur réseau, ce qui ferait une jolie
    /// capture sur la fiche App Store.
    ///
    /// Le coach se règle par la base : ses messages sont des `ChatMessage` SwiftData.
    ///
    /// Le club, lui, vit dans un cache en mémoire sur `AppState`. On le remplit en DÉCODANT du
    /// JSON, pas en construisant les structures à la main. `ClubBoard` et `FeedItem` ne sont que
    /// `Decodable` : leur ajouter un initialiseur pour les besoins d'une capture ouvrirait une
    /// seconde façon de les fabriquer, qui pourrait diverger de ce que le serveur envoie
    /// vraiment. En passant par le décodeur, une capture ne peut montrer que ce que le contrat
    /// serveur permet — et si ce contrat change, ce JSON cesse de se décoder, ce qui est
    /// exactement le signal qu'on veut.
    @MainActor
    static func poserLeClub(dans etat: AppState, maintenant: Date = .now) {
        let decodeur = JSONDecoder()
        decodeur.dateDecodingStrategy = .iso8601
        let formateur = ISO8601DateFormatter()
        formateur.formatOptions = [.withInternetDateTime]

        func ilYA(_ heures: Int) -> String {
            formateur.string(from: maintenant.addingTimeInterval(-Double(heures) * 3600))
        }

        func ilYAJours(_ jours: Int) -> String { ilYA(jours * 24) }

        func dansDesHeures(_ heures: Int) -> String { ilYA(-heures) }
        func dansDesJours(_ jours: Int) -> String { ilYA(-jours * 24) }

        let tableau = """
        {
          "club": { "id": "demo", "name": "Les Foulées du Canal", "memberCount": 18, "isOpen": true, "isOwner": false },
          "leaderboard": [
            { "id": "1", "name": "Charlotte", "xp": 4180, "rank": 1, "isMe": true,
              "bio": "Je cours le matin, avant que la ville se réveille.", "joinedAt": "\(ilYAJours(214))",
              "activitiesCount": 16, "badgeKeys": ["firstRun", "tenRuns", "streak7", "distance50"] },
            { "id": "2", "name": "Inès", "xp": 3940, "rank": 2, "isMe": false,
              "joinedAt": "\(ilYAJours(301))", "activitiesCount": 14,
              "badgeKeys": ["firstRun", "tenRuns", "earlyRun"] },
            { "id": "3", "name": "Margaux", "xp": 3610, "rank": 3, "isMe": false,
              "joinedAt": "\(ilYAJours(168))", "activitiesCount": 12,
              "badgeKeys": ["firstRun", "tenRuns", "interval3"] },
            { "id": "4", "name": "Sarah", "xp": 3180, "rank": 4, "isMe": false,
              "joinedAt": "\(ilYAJours(96))", "activitiesCount": 9,
              "badgeKeys": ["firstRun", "weekendWarrior"] },
            { "id": "5", "name": "Lina", "xp": 2870, "rank": 5, "isMe": false,
              "joinedAt": "\(ilYAJours(41))", "activitiesCount": 6,
              "badgeKeys": ["firstRun"] }
          ],
          "weekly": [
            { "id": "3", "name": "Margaux", "weekKm": 48.6, "rank": 1, "isMe": false,
              "targetKm": 52.0, "pctOfTarget": 93 },
            { "id": "2", "name": "Inès", "weekKm": 41.2, "rank": 2, "isMe": false,
              "targetKm": 45.0, "pctOfTarget": 92 },
            { "id": "1", "name": "Charlotte", "weekKm": 33.8, "rank": 3, "isMe": true,
              "targetKm": 32.0, "pctOfTarget": 106 },
            { "id": "4", "name": "Sarah", "weekKm": 22.4, "rank": 4, "isMe": false,
              "targetKm": 30.0, "pctOfTarget": 75 },
            { "id": "5", "name": "Lina", "weekKm": 12.1, "rank": 5, "isMe": false }
          ],
          "weekStats": { "totalKm": 158.1, "activeMembers": 5 },
          "challenge": {
            "id": "d1", "title": "300 km ensemble en octobre",
            "targetKm": 300, "progressKm": 212.5, "endDate": "\(dansDesJours(6))"
          },
          "events": [
            { "id": "e1", "title": "Sortie longue au canal", "location": "Bassin de la Villette",
              "startsAt": "\(dansDesHeures(31))", "going": 4, "goingByMe": true, "isMine": false },
            { "id": "e2", "title": "Fractionné sur piste", "location": "Stade Jules-Ladoumègue",
              "startsAt": "\(dansDesJours(4))", "going": 2, "goingByMe": false, "isMine": false }
          ]
        }
        """
        // UNE SEULE DES TROIS SORTIES PORTE UN TRACÉ, ET C'EST VOLONTAIRE.
        //
        // L'accroche promet « ses sorties, ses routes » : il en faut au moins un, sinon le mot
        // « routes » ne correspond à rien de visible. Les trois en porter un serait faux dans
        // l'autre sens — une sortie sur tapis, une montre sans GPS, un tracé retiré après coup :
        // `ActivityFeedRow` sait afficher les deux formes de carte, et le fil d'un vrai club
        // mélange les deux.
        //
        // Le tracé est une boucle le long d'un canal, aller par une rive et retour par l'autre.
        // Sa boîte fait cinq kilomètres de côté, ce qui est la bonne échelle pour les 12,4 km
        // annoncés par la ligne au-dessus — un aller-retour, pas une ligne droite.
        //
        // IL VOYAGE EN PAIRES `[lat, lng]`, PAS EN OBJETS `{"lat":…, "lng":…}`.
        //
        // C'est la forme que la base stocke et que le serveur renvoie telle quelle, et
        // `FeedItem.init(from:)` décode un `[[Double]]`. Je l'avais écrit en objets : le
        // décodage du fil ENTIER tombait sur une erreur de type. Le `preconditionFailure`
        // ci-dessous l'a dit tout de suite, au lieu de livrer une sixième image fausse.
        let fil = """
        [
          { "id": "a", "userId": "2", "name": "Inès", "text": "a couru 12,4 km · Sortie longue",
            "createdAt": "\(ilYA(3))", "distanceKm": 12.4, "durationSeconds": 4190,
            "avgPace": "5:38", "elevationGainM": 86, "isPersonalRecord": false,
            "contentKey": "long_run", "kudos": 7, "kudoedByMe": true, "commentsCount": 2,
            "kudosNames": ["Charlotte", "Margaux", "Sarah"],
            "lastComment": { "name": "Charlotte", "text": "\(commentaire())" },
            "routePreview": [
              [48.88120, 2.36900], [48.88433, 2.37412], [48.88739, 2.37922],
              [48.89030, 2.38427], [48.89303, 2.38924], [48.89557, 2.39413],
              [48.89796, 2.39893], [48.90026, 2.40362], [48.90253, 2.40822],
              [48.90486, 2.41273], [48.90732, 2.41717], [48.90996, 2.42155],
              [48.91278, 2.42590], [48.91791, 2.42728], [48.92135, 2.43087],
              [48.92204, 2.43532], [48.92000, 2.43891], [48.91626, 2.44029],
              [48.91229, 2.43463], [48.90836, 2.42895], [48.90454, 2.42325],
              [48.90084, 2.41750], [48.89728, 2.41170], [48.89385, 2.40584],
              [48.89050, 2.39992], [48.88721, 2.39393], [48.88390, 2.38789],
              [48.88054, 2.38178], [48.87707, 2.37563]
            ] },
          { "id": "b", "userId": "3", "name": "Margaux", "text": "a couru 6,0 km · Fractionné",
            "createdAt": "\(ilYA(9))", "distanceKm": 6.0, "durationSeconds": 1764,
            "avgPace": "4:54", "isPersonalRecord": true,
            "contentKey": "vo2max_intervals", "kudos": 11, "kudoedByMe": false, "commentsCount": 4,
            "kudosNames": ["Inès", "Lina", "Charlotte"] },
          { "id": "c", "userId": "5", "name": "Lina", "text": "a couru 8,2 km · Tempo",
            "createdAt": "\(ilYA(22))", "distanceKm": 8.2, "durationSeconds": 2583,
            "avgPace": "5:15", "elevationGainM": 42, "isPersonalRecord": false,
            "contentKey": "tempo_run", "kudos": 5, "kudoedByMe": false, "commentsCount": 1,
            "kudosNames": ["Charlotte"] }
        ]
        """

        // UN ÉCHEC BRUYANT, ET C'EST VOULU.
        //
        // C'était `try?`. Le tableau ci-dessus ne portait ni `joinedAt`, ni `activitiesCount`,
        // ni `badgeKeys` — trois champs NON optionnels de `LeaderboardRow` — donc le décodage
        // échouait, le cache restait nil, et l'écran du Club montrait son formulaire « Créer un
        // club » sous une accroche qui parle du fil du club. Rien ne l'a dit : le `?` avait
        // avalé l'erreur, et il a fallu une exécution complète et une relecture de l'image pour
        // s'en apercevoir.
        //
        // Ce code n'existe qu'en débogage et ne tourne que dans le simulateur des captures.
        // Mieux vaut qu'il s'arrête net, avec la raison, que de livrer une image fausse.
        // CE QUE LE PROFIL MONTRE, ET QU'IL ALLAIT CHERCHER AU SERVEUR.
        //
        // La grille Communauté dit la chose la plus utile qu'elle sache de chaque destination :
        // les abonnements, le club, la course la plus proche. En démonstration elle n'avait rien
        // à dire — pire, elle le demandait au serveur avec un jeton qui n'en est pas un, prenait
        // un 401, et remplaçait toute la section par « Session expirée ».
        //
        // Une demande en attente, et c'est exprès : c'est le seul élément de la grille qu'on ne
        // doit pas pouvoir manquer, donc le seul qu'une capture doit montrer.
        let amis = """
        {
          "isPrivate": false,
          "following": [
            { "id": "2", "name": "Inès", "lastName": "Lambert", "username": "ines", "isPrivate": false },
            { "id": "3", "name": "Margaux", "username": "margaux", "isPrivate": false },
            { "id": "5", "name": "Lina", "isPrivate": false }
          ],
          "followers": [
            { "id": "2", "name": "Inès", "lastName": "Lambert", "username": "ines", "isPrivate": false },
            { "id": "4", "name": "Sarah", "isPrivate": false }
          ],
          "incomingRequests": [
            { "id": "6", "name": "Camille", "lastName": "Roux", "isPrivate": false }
          ]
        }
        """

        // LA PAGE DE QUELQU'UN. Inès est déjà au classement, au fil et dans les abonnements :
        // la même personne d'un écran à l'autre, ce qui est exactement ce qu'une capture doit
        // montrer. Compte PUBLIC et `canSeeRuns` à vrai — l'état privé a son propre écran, qui
        // se photographie en basculant ces deux valeurs.
        let profil = """
        {
          "profile": {
            "id": "2", "name": "Inès", "lastName": "Lambert", "username": "ines",
            "bio": "Marathon de Paris, et un chien qui court plus vite que moi.",
            "isPrivate": false, "isMe": false, "followStatus": "accepted", "followsMe": true,
            "followers": 48, "following": 61, "runs": 142, "totalKm": 1284.6,
            "badgeKeys": ["firstRun", "tenRuns", "earlyRun", "streak7", "distance50"],
            "joinedAt": "\(ilYAJours(301))", "canSeeRuns": true
          },
          "items": []
        }
        """

        // Une vraie course, à une vraie date : la tuile affiche un compte à rebours, et c'est
        // précisément la ligne dont il faut vérifier qu'elle tient sur deux lignes.
        let course = """
        {
          "id": "demo-course", "name": "Marathon de Paris", "city": "Paris",
          "raceDate": "\(formateur.string(from: maintenant.addingTimeInterval(86_400 * 162)).prefix(10))",
          "distanceKm": 42.195, "discipline": "run", "followerCount": 143
        }
        """

        do {
            etat.cachedClubBoard = try decodeur.decode(ClubBoard.self, from: Data(tableau.utf8))
            etat.cachedClubFeed = try decodeur.decode([FeedItem].self, from: Data(fil.utf8))
            etat.cachedFriendsList = try decodeur.decode(FriendsList.self, from: Data(amis.utf8))
            etat.cachedNextRace = try decodeur.decode(RaceEvent.self, from: Data(course.utf8))
            // Le mur, construit à partir du fil déjà semé : les mêmes sorties, chacune avec sa
            // provenance, plus une annonce de course. Les reconstruire à part en ferait deux jeux
            // de démonstration qui finiraient par ne plus raconter la même chose.
            let murBrut = """
            {
              "items": [],
              "racePosts": [
                {
                  "id": "p1", "raceId": "demo-course", "raceName": "Marathon de Paris",
                  "raceDate": "2027-04-04", "discipline": "run", "kind": "partner",
                  "text": "Je vise 3h30, sorties longues le dimanche matin au bois. Quelqu'un sur ce rythme ?",
                  "closed": false, "kudos": 4, "kudoedByMe": true, "createdAt": "\(ilYA(5))",
                  "author": { "id": "3", "name": "Margaux", "isPrivate": false }
                }
              ]
            }
            """
            var mur = try decodeur.decode(WallPage.self, from: Data(murBrut.utf8))
            mur.items = (etat.cachedClubFeed ?? []).map { sortie in
                var copie = sortie
                copie.source = sortie.userId == "1" ? "moi" : "club"
                return copie
            }
            etat.cachedWall = mur

            // LA PAGE D'UNE COURSE. Trois coureurs dont deux partagent leur entraînement et un
            // non — c'est la distinction qui demande le plus de soin à l'affichage — et trois
            // messages dont une cession de dossard, pour que l'avertissement se photographie.
            let pageDeCourse = """
            {
              "race": {
                "id": "demo-course", "name": "Marathon de Paris", "city": "Paris",
                "raceDate": "2027-04-04", "distanceKm": 42.195, "discipline": "run",
                "followerCount": 143
              },
              "me": {
                "targetChrono": "3:45", "targetPaceSecPerKm": 320,
                "sharesTraining": true, "lookingForPartner": false
              },
              "runners": [
                { "id": "3", "name": "Margaux", "lastName": "Hubert", "isPrivate": false,
                  "followStatus": "accepted", "targetChrono": "3:30", "targetPaceSecPerKm": 298,
                  "lookingForPartner": true, "km4Weeks": 182.4, "runs4Weeks": 16 },
                { "id": "2", "name": "Inès", "lastName": "Lambert", "username": "ines",
                  "isPrivate": false, "followStatus": "accepted", "targetChrono": "3:48",
                  "targetPaceSecPerKm": 324, "lookingForPartner": true,
                  "km4Weeks": 146.0, "runs4Weeks": 14 },
                { "id": "5", "name": "Lina", "isPrivate": false, "targetChrono": "sub-4",
                  "lookingForPartner": false }
              ],
              "posts": [
                { "id": "m1", "kind": "partner",
                  "text": "Je vise 3h30, sorties longues le dimanche matin au bois. Quelqu'un sur ce rythme ?",
                  "closed": false, "isMine": false, "kudos": 4, "kudoedByMe": true,
                  "createdAt": "\(ilYA(5))",
                  "author": { "id": "3", "name": "Margaux", "isPrivate": false } },
                { "id": "m2", "kind": "bib_offer",
                  "text": "Je cède mon dossard, blessure au genou. Distance marathon.",
                  "closed": false, "isMine": false, "kudos": 1, "kudoedByMe": false,
                  "createdAt": "\(ilYA(26))",
                  "author": { "id": "5", "name": "Lina", "isPrivate": false } },
                { "id": "m3", "kind": "message",
                  "text": "Le ravito du 30e est à droite, pas à gauche comme l'an dernier.",
                  "closed": false, "isMine": false, "kudos": 11, "kudoedByMe": false,
                  "createdAt": "\(ilYA(52))",
                  "author": { "id": "2", "name": "Inès", "isPrivate": false } }
              ]
            }
            """
            etat.cachedRacePage = try decodeur.decode(RacePage.self, from: Data(pageDeCourse.utf8))

            // LA SORTIE DÉROULÉE : la même que la première du fil — 12,4 km d'Inès — mais vue de
            // l'intérieur. C'est l'écran qui porte le plus de CHIFFRES de toute l'app : six
            // mesures, douze barres de splits et un profil de terrain. Autant d'occasions qu'un
            // détail soit faux sans que rien ne plante.
            //
            // Les altitudes sont d'accord avec le D+ annoncé : +67 m sur la montée, puis +19 m
            // sur la bosse du retour, soit les 86 m de la ligne « D+ ». Une capture où le profil
            // monte de trente mètres à côté d'un « 86 m » serait un bug invisible aux tests et
            // évident à l'œil — c'est exactement ce que ces images servent à attraper.
            //
            // Et les douze splits finissent par le plus rapide : la dernière barre est rose, et
            // c'est elle qui montre que l'échelle est relative aux splits de CETTE sortie.
            let sortie = """
            {
              "id": "a", "userId": "2", "name": "Inès", "lastName": "Lambert", "username": "ines",
              "text": "a couru 12,4 km · Sortie longue", "contentKey": "long_run",
              "createdAt": "\(ilYA(3))",
              "distanceKm": 12.4, "durationSeconds": 4190, "avgPace": "5:38",
              "elevationGainM": 86, "isPersonalRecord": false,
              "avgHeartRate": 154, "kcal": 812,
              "title": "Boucle du canal", "note": "Parfait au lever du jour, personne sur la berge.",
              "kudos": 7, "kudoedByMe": true, "commentsCount": 2, "isMine": false,
              "splits": ["5:52","5:44","5:39","5:35","5:31","5:28","5:33","5:41","5:47","5:36","5:29","5:20"],
              "routePreview": [
                [48.88120, 2.36900], [48.88433, 2.37412], [48.88739, 2.37922],
                [48.89030, 2.38427], [48.89303, 2.38924], [48.89557, 2.39413],
                [48.89796, 2.39893], [48.90026, 2.40362], [48.90253, 2.40822],
                [48.90486, 2.41273], [48.90732, 2.41717], [48.90996, 2.42155],
                [48.91278, 2.42590], [48.91791, 2.42728], [48.92135, 2.43087],
                [48.92204, 2.43532], [48.92000, 2.43891], [48.91626, 2.44029],
                [48.91229, 2.43463], [48.90836, 2.42895], [48.90454, 2.42325],
                [48.90084, 2.41750], [48.89728, 2.41170], [48.89385, 2.40584],
                [48.89050, 2.39992], [48.88721, 2.39393], [48.88390, 2.38789],
                [48.88054, 2.38178], [48.87707, 2.37563]
              ],
              "routeAltitudes": [
                30, 35, 41, 47, 53, 58, 63, 68, 73, 77,
                81, 85, 89, 93, 97, 92, 86, 80, 85, 91,
                96, 99, 92, 82, 72, 62, 52, 43, 35
              ]
            }
            """
            etat.cachedActivityDetail = try decodeur.decode(ActivityDetail.self, from: Data(sortie.utf8))

            // CE QUE LE CLUB PRÉPARE, ET CE QU'IL A FAIT DE MIEUX. Les deux sections qui
            // distinguent un club d'un classement — et les deux qui, vides, feraient passer
            // l'aperçu pour un écran inachevé sur une capture de l'App Store.
            //
            // Les records pointent vers de VRAIES sorties du fil de démonstration : chacun
            // s'ouvre, et atterrit sur la sortie déroulée. Un record qui mène à une page vide
            // serait pire que pas de record du tout.
            let pepites = """
            {
              "races": [
                {
                  "race": { "id": "demo-course", "name": "Marathon de Paris", "city": "Paris",
                            "raceDate": "2027-04-04", "distanceKm": 42.195, "discipline": "run" },
                  "members": 3,
                  "runners": [
                    { "id": "1", "name": "Charlotte" },
                    { "id": "2", "name": "Inès" },
                    { "id": "3", "name": "Margaux" }
                  ]
                },
                {
                  "race": { "id": "demo-20km", "name": "20 km de Paris", "city": "Paris",
                            "raceDate": "2026-10-11", "distanceKm": 20.0, "discipline": "run" },
                  "members": 2,
                  "runners": [
                    { "id": "4", "name": "Sarah" },
                    { "id": "5", "name": "Lina" }
                  ]
                }
              ],
              "records": [
                { "genre": "distance", "activityId": "a", "userId": "2", "name": "Inès",
                  "createdAt": "\(ilYA(3))", "distanceKm": 12.4, "durationSeconds": 4190,
                  "elevationGainM": 86, "secPerKm": 337.9 },
                { "genre": "allure", "activityId": "b", "userId": "3", "name": "Margaux",
                  "createdAt": "\(ilYA(9))", "distanceKm": 6.0, "durationSeconds": 1764,
                  "secPerKm": 294.0 },
                { "genre": "denivele", "activityId": "c", "userId": "5", "name": "Lina",
                  "createdAt": "\(ilYA(22))", "distanceKm": 8.2, "durationSeconds": 2583,
                  "elevationGainM": 42, "secPerKm": 315.0 }
              ]
            }
            """
            etat.cachedClubHighlights = try decodeur.decode(ClubHighlights.self, from: Data(pepites.utf8))

            var sienne = try decodeur.decode(PublicProfilePage.self, from: Data(profil.utf8))
            // Ses sorties sont celles du fil de démonstration qui lui appartiennent : une page de
            // profil avec des cartes vides ne dirait rien de ce qu'elle doit montrer.
            sienne.items = (etat.cachedClubFeed ?? []).filter { $0.userId == "2" }
            etat.cachedPublicProfile = sienne
        } catch {
            preconditionFailure("Le club de démonstration ne se décode pas : \(error)")
        }

        // Le cache ne suffit pas : `ClubView` affiche son écran de connexion AVANT de le
        // regarder. Une session de démonstration ouvre la porte ; elle ne vaut que pour ce
        // processus, n'est pas rangée dans le trousseau, et ne sert jamais à parler au serveur —
        // `loadIfSignedIn` ne l'appelle pas en démonstration.
        //
        // Le XP est celui du profil et celui du classement : trois nombres identiques, trois
        // endroits, et c'est la seule capture où l'incohérence se verrait d'un coup d'œil.
        etat.auth.poserUneSessionDeDemonstration(
            AuthenticatedUser(id: "1", name: "Charlotte", xpTotal: 4_180, lastName: "Perret",
                              username: "charlotte")
        )
    }

    /// Une conversation courte, et qui montre ce que le coach sait faire : il a LU les séances.
    ///
    /// Une capture d'écran de messagerie se juge en une seconde. « Bonjour, comment puis-je
    /// t'aider ? » prouverait seulement qu'un champ de texte existe ; une réponse qui cite le
    /// fractionné de mardi prouve ce que la fiche promet — « Il a lu tes dernières séances ».
    ///
    /// # POURQUOI CES TROIS TRADUCTIONS SONT ÉCRITES ICI, ET PAS DANS LE CATALOGUE
    ///
    /// C'est le seul des six écrans dont le contenu ne se retraduit pas tout seul. Le fil du club
    /// passe par `contentKey`, qui refabrique sa phrase dans la langue du lecteur ; l'historique
    /// et les statistiques passent par `SessionKind.titleKey` ; le plan aussi. Une conversation,
    /// elle, est du texte libre.
    ///
    /// Les mettre au catalogue y ferait entrer trois phrases de démonstration qui partiraient
    /// dans la construction envoyée à l'App Store — un catalogue est livré en entier, et celles-ci
    /// n'ont rien à y faire. Un `switch` sur la langue, dans un fichier qui n'existe qu'en
    /// débogage, garde la fausse conversation hors du binaire réel.
    private static func conversation(maintenant: Date) -> [ChatMessage] {
        let (question, reponse) = echange()
        return [
            ChatMessage(role: .user, text: question,
                        timestamp: maintenant.addingTimeInterval(-3600 * 5)),
            ChatMessage(role: .coach, text: reponse,
                        timestamp: maintenant.addingTimeInterval(-3600 * 5 + 40)),
        ]
    }

    private static func echange() -> (String, String) {
        switch Locale.current.language.languageCode?.identifier {
        case "en":
            return (
                "Tuesday's intervals felt brutal, I finished in bits. Should I worry about the 10K?",
                "You held all six reps at 4:38, faster than your target pace — finishing a session like that hard is a sign it was pitched right, not that it was too hard. Your last three long runs have gained twenty seconds per kilometre. Keep Thursday in Z2, and we'll find the speed again on Saturday."
            )
        case "es":
            return (
                "Las series del martes se me hicieron durísimas, acabé hecha polvo. ¿Me preocupo por el 10K?",
                "Aguantaste las seis repeticiones a 4:38, más rápido que tu ritmo objetivo — acabar así de dura una sesión como esa es señal de que estaba bien calibrada, no de que fuera excesiva. Tus tres últimas tiradas largas han ganado veinte segundos por kilómetro. Deja el jueves en Z2, y el sábado recuperamos velocidad."
            )
        default:
            return (
                "Le fractionné de mardi m'a paru très dur, j'ai fini à l'agonie. Je m'inquiète pour le 10 km ?",
                "Tu as tenu les six répétitions à 4:38, soit plus vite que l'allure cible — finir dur sur une séance comme celle-là est le signe qu'elle était bien calibrée, pas qu'elle était trop dure. Tes trois dernières sorties longues ont gagné vingt secondes au kilomètre. Garde la séance de jeudi en Z2, et on retrouve de la vitesse samedi."
            )
        }
    }

    /// Le commentaire du fil, dans la langue de la capture.
    ///
    /// Même raison que `echange()` juste au-dessus : c'est du texte libre, que rien dans l'app
    /// ne sait retraduire. Le reste du fil passe par `contentKey` et se refabrique tout seul —
    /// « a couru 6,0 km · Fractionné VMA » devient « ran 6.0 km · VO2max intervals » sans que
    /// la graine n'ait à le savoir. Une phrase écrite par quelqu'un, non.
    ///
    /// Et ça s'est vu : la série anglaise affichait « Belle allure sur la fin ! » sous une
    /// carte par ailleurs entièrement traduite.
    private static func commentaire() -> String {
        switch Locale.current.language.languageCode?.identifier {
        case "en": return "Great pace on the last stretch!"
        case "es": return "¡Qué ritmo en el tramo final!"
        default: return "Belle allure sur la fin !"
        }
    }

    /// Une préparation de 10 km en cours : une date devant soi, un chrono visé, quatre jours par
    /// semaine. C'est l'objectif le plus choisi, et celui dont toutes les accroches parlent.
    private static func resultat(maintenant: Date) -> AdaptivePlanEngine.OnboardingResult {
        let calendrier = Calendar.current
        return AdaptivePlanEngine.OnboardingResult(
            name: "Charlotte",
            lastName: "Perret",
            birthdate: calendrier.date(byAdding: .year, value: -31, to: maintenant),
            sex: "female",
            goal: .race,
            raceDistance: .k10,
            raceDistanceCustom: nil,
            raceElevationGainM: nil,
            raceChrono: "47:30",
            // Six semaines devant : assez pour que le plan soit en plein bloc spécifique, donc
            // que l'écran du plan montre autre chose que des footings de base.
            raceDate: calendrier.date(byAdding: .weekOfYear, value: 6, to: maintenant),
            hyroxDivision: nil,
            triathlonFormat: nil,
            nageNiveau: nil,
            duathlonFormat: nil,
            tempsSemaineMin: 60, tempsWeekEndMin: 120,
            volumeActuel: VolumeActuel.troisOuQuatre.rawValue,
            plusLongueSortie: PlusLongueSortie.de10a15.rawValue,
            allureFooting: nil,
            runningDays: [0, 2, 4, 6],
            preferredLongRunDay: 6,
            level: .intermediaire,
            connectedSources: [.apple],
            weightNowKg: nil,
            weightTargetKg: nil,
            heightCm: nil,
            focusArea: nil,
            bestRecentPerf: "10 km en 49:12",
            lastRanRecency: nil,
            injuryArea: nil,
            injuryWhen: nil, terrains: [], autresSports: [],
            weeklyTimeBudget: nil,
            preferredTimeOfDay: nil,
            cycleTrackingEnabled: false,
            lastPeriodStartDate: nil,
            averageCycleLengthDays: 28
        )
    }

    /// Huit semaines d'historique, qui PROGRESSENT.
    ///
    /// L'écran des statistiques trace une courbe d'allure : un historique où toutes les sorties
    /// se valent y dessine une ligne plate, c'est-à-dire la capture la moins convaincante qu'une
    /// app d'entraînement puisse publier. Les allures descendent donc de 5:50 à 5:06 au fil des
    /// semaines, avec du bruit — une courbe parfaitement lisse ne ressemble à personne.
    private static func historique(maintenant: Date) -> [RunRecord] {
        let calendrier = Calendar.current
        // (jours en arrière, km, secondes/km, type de séance)
        let sorties: [(Int, Double, Double, SessionKind)] = [
            (2, 8.1, 318, .enduranceFooting), (4, 6.0, 306, .tempoRun),
            (6, 14.2, 330, .longRun), (9, 7.5, 320, .easyFooting),
            (11, 9.0, 310, .vo2maxIntervals), (13, 13.0, 334, .longRun),
            (16, 7.2, 324, .enduranceFooting), (18, 8.6, 314, .tempoRun),
            (20, 12.4, 338, .longRun), (23, 6.8, 328, .easyFooting),
            (25, 8.0, 318, .vo2maxIntervals), (27, 11.8, 342, .longRun),
            (31, 6.5, 332, .enduranceFooting), (34, 10.5, 346, .longRun),
            (38, 6.0, 338, .easyFooting), (41, 9.6, 350, .longRun),
        ]
        return sorties.map { jours, km, secParKm, kind in
            let releve = AdaptivePlanEngine.buildRunRecord(
                title: "Sortie",
                elapsedSeconds: km * secParKm,
                distanceKm: km,
                kcal: Calories.estimate(.run, distanceKm: km, durationMinutes: Int(km * secParKm / 60)),
                avgHeartRate: 148,
                elevationGainM: Int(km * 6),
                sessionKind: kind
            )
            releve.date = calendrier.date(byAdding: .day, value: -jours, to: maintenant) ?? maintenant
            // Déjà débriefées : une course en attente de ressenti ouvre une feuille modale au
            // lancement, qui viendrait se poser au milieu de la capture.
            releve.debriefedAt = releve.date
            return releve
        }
    }
}
#endif
