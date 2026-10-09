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
        try? contexte.delete(model: RunRecord.self)
        try? contexte.delete(model: UserProfile.self)

        let profil = UserProfile(name: "Charlotte")
        contexte.insert(profil)
        AdaptivePlanEngine.applyOnboarding(resultat(maintenant: maintenant), to: profil)

        // Les chiffres du jour. Ils ne viennent pas d'Apple Santé ici — personne n'a marché dans
        // un simulateur — donc ils sont posés directement, aux valeurs d'une vraie journée
        // ordinaire : les anneaux de « Ta journée » doivent être bien remplis sans l'être tous.
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

        let tableau = """
        {
          "club": { "id": "demo", "name": "Les Foulées du Canal", "inviteCode": "CANAL", "memberCount": 18 },
          "leaderboard": [
            { "id": "1", "name": "Charlotte", "xp": 4180, "rank": 1, "isMe": true, "bio": "Objectif 10 km sous 47:30" },
            { "id": "2", "name": "Inès", "xp": 3940, "rank": 2, "isMe": false },
            { "id": "3", "name": "Margaux", "xp": 3610, "rank": 3, "isMe": false },
            { "id": "4", "name": "Sarah", "xp": 3180, "rank": 4, "isMe": false },
            { "id": "5", "name": "Lina", "xp": 2870, "rank": 5, "isMe": false }
          ]
        }
        """
        let fil = """
        [
          { "id": "a", "userId": "2", "name": "Inès", "text": "a couru 12,4 km · Sortie longue",
            "createdAt": "\(ilYA(3))", "distanceKm": 12.4, "durationSeconds": 4190,
            "avgPace": "5:38", "elevationGainM": 86, "isPersonalRecord": false,
            "contentKey": "long_run", "kudos": 7, "kudoedByMe": true, "commentsCount": 2,
            "kudosNames": ["Charlotte", "Margaux", "Sarah"] },
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

        etat.cachedClubBoard = try? decodeur.decode(ClubBoard.self, from: Data(tableau.utf8))
        etat.cachedClubFeed = try? decodeur.decode([FeedItem].self, from: Data(fil.utf8))
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
}
#endif
