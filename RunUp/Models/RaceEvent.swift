import Foundation

/// Une course officielle, et ce que l'app en sait.
///
/// POURQUOI `raceDate` EST UNE CHAÎNE ET PAS UNE `Date`.
///
/// Côté serveur c'est une colonne `DATE` : un jour, sans heure. Une colonne DATE traverse le
/// pilote Postgres en objet `Date` JavaScript, donc en ISO complet — et le 4 avril devient le
/// 3 avril à 22 h pour qui la relit dans un autre fuseau. La route rend donc « 2027-04-04 » en
/// clair (`to_char`), et c'est cette chaîne qu'on garde : une date de course n'a pas d'heure, elle
/// n'a pas à en gagner une au passage, et le jour affiché ne doit pas dépendre d'où l'on est.
///
/// AUCUN INSTANT N'EST LE MÊME JOUR PARTOUT, et c'est pour ça que l'affichage est en UTC et non
/// dans le fuseau du téléphone. Les fuseaux habités vont de UTC−12 à UTC+14 : vingt-six heures
/// d'écart, donc à n'importe quelle heure du globe il y a deux dates au calendrier en même temps.
/// Choisir midi UTC au lieu de minuit déplace le problème sans le résoudre — à Kiritimati (+14),
/// midi UTC est déjà le lendemain à deux heures du matin. `dateLisible` formate donc le jour
/// explicitement en UTC : la LANGUE suit le téléphone, le JOUR ne suit personne. Le 4 avril est le
/// 4 avril, de Los Angeles à Tokyo.
///
/// `joursRestants`, lui, compare deux JOURS et non deux instants : le jour imprimé sur le dossard,
/// et le jour qu'il est chez la personne qui regarde. C'est le seul endroit où son fuseau compte,
/// parce que « J-42 » répond à « combien de jours me reste-t-il », pas « où est la course ».
struct RaceEvent: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var city: String?
    /// « AAAA-MM-JJ ». Voir le commentaire ci-dessus.
    var raceDate: String
    var distanceKm: Double?
    var elevationGainM: Int?
    /// « run » | « trail » | « hyrox » | « triathlon » | « duathlon ».
    var discipline: String
    /// Affichée en lien tapable. Le serveur ne laisse passer que http(s) — voir lib/courses.js.
    var website: String?
    /// Combien de personnes préparent cette course. Optionnel par prudence de version : la
    /// fenêtre entre un déploiement du serveur et celui de l'app n'est jamais nulle.
    var followerCount: Int?

    private static let jourISO: DateFormatter = {
        let f = DateFormatter()
        // `posix` et non `current` : « 2027-04-04 » est un format de machine. Avec un calendrier
        // non grégorien ou des chiffres non arabes, un formateur local ne le relirait pas.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let utc = TimeZone(identifier: "UTC") ?? .gmt

    private static var calendrierUTC: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = utc
        return calendrier
    }

    /// Minuit UTC le jour de la course. Un repère, pas une heure : rien n'affiche cet instant
    /// tel quel — voir `dateLisible`, qui le remet en mots dans le même fuseau qu'il a été lu.
    var jour: Date? { Self.jourISO.date(from: raceDate) }

    /// Le style d'affichage : la langue et l'ordre des mots viennent du téléphone, le fuseau non.
    private static let styleDuJour = Date.FormatStyle(date: .long, time: .omitted, timeZone: utc)

    var dateLisible: String {
        guard let jour else { return raceDate }
        return jour.formatted(Self.styleDuJour)
    }

    /// Combien de jours il reste, du jour qu'il est CHEZ MOI au jour de la course. Négatif
    /// n'arrive quasiment pas : le serveur ne rend aucune course passée, mais la veille est
    /// acceptée à la création (voir lib/courses.js), donc l'appel reste honnête s'il arrive.
    var joursRestants: Int? {
        guard let jour else { return nil }
        // `Calendar.current` pour lire le jour local — il suit les voyages, là où un
        // `DateFormatter` statique figerait le fuseau du lancement de l'app. Puis les deux jours
        // se comparent dans le MÊME calendrier, sinon on compterait un décalage de fuseau comme
        // un jour de préparation.
        let local = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let calendrier = Self.calendrierUTC
        guard let aujourdhui = calendrier.date(from: DateComponents(
            year: local.year, month: local.month, day: local.day)) else { return nil }
        return calendrier.dateComponents([.day], from: aujourdhui, to: jour).day
    }

    /// « Paris · 42,2 km · 1 200 m D+ » — ce qui distingue deux courses du même nom, dans cet
    /// ordre, et rien d'autre. La distance passe par `Distances` : « 42.2 » est faux en français.
    var sousTitre: String {
        var morceaux: [String] = []
        if let city, !city.isEmpty { morceaux.append(city) }
        if let distanceKm { morceaux.append(Distances.km(distanceKm)) }
        if let elevationGainM, elevationGainM > 0 { morceaux.append("\(elevationGainM) m D+") }
        return morceaux.joined(separator: " · ")
    }

    var disciplineSymbole: String {
        switch discipline {
        case "trail": return "mountain.2.fill"
        case "hyrox": return "dumbbell.fill"
        case "triathlon", "duathlon": return "bicycle"
        default: return "figure.run"
        }
    }
}

/// Ce que MOI j'ai déclaré sur cette course. `nil` quand je ne la suis pas encore.
struct RaceFollow: Decodable, Hashable {
    /// Le chrono visé, tel qu'il a été écrit — « 3h30 », « sub-4 ». Volontairement libre : un
    /// objectif se dit comme on le dit, et le serveur n'en fait rien d'autre que l'afficher.
    var targetChrono: String?
    var targetPaceSecPerKm: Int?
    /// Opt-in EXPLICITE. Faux par défaut, et quand il est faux le volume d'entraînement n'est
    /// même pas calculé par la requête — voir api/races/[action].js.
    var sharesTraining: Bool
    var lookingForPartner: Bool
}

/// Quelqu'un qui prépare la même course.
struct RaceRunner: Decodable, Identifiable, Hashable, Nomme {
    var id: String
    var name: String
    var lastName: String?
    var username: String?
    var avatarUrl: String?
    var avatarBase64: String?
    var isPrivate: Bool
    /// Ma relation à cette personne : nil, « pending » ou « accepted ».
    var followStatus: String?
    var targetChrono: String?
    var targetPaceSecPerKm: Int?
    var lookingForPartner: Bool
    /// `nil` veut dire « n'a pas autorisé le partage ». Différent de `0`, qui veut dire « n'a rien
    /// couru ». Les deux s'affichent autrement, et les confondre serait accuser quelqu'un de ne
    /// pas s'entraîner parce qu'il tient à sa vie privée.
    var km4Weeks: Double?
    var runs4Weeks: Int?

    var partageSonEntrainement: Bool { km4Weeks != nil }

    var nomDeFamille: String? { lastName }
}

/// Un message du fil de la course : une question, une recherche de partenaire, une annonce de
/// dossard. Le genre décide de l'apparence, pas du traitement.
struct RacePost: Decodable, Identifiable, Hashable {
    var id: String
    /// Non nil pour une réponse. Il n'y a que deux niveaux : une réponse de réponse n'existe pas.
    var parentId: String?
    /// « message » | « partner » | « bib_offer » | « bib_wanted ».
    var kind: String
    var text: String
    /// Retiré par son auteur : le dossard est parti, le partenaire est trouvé. On marque au lieu
    /// de supprimer, sinon les réponses en dessous deviennent des messages sans contexte.
    var closed: Bool
    /// Dit par le serveur : « marquer comme réglé » n'est proposé qu'à l'auteur, et l'app n'a
    /// aucune raison de porter son propre identifiant pour le savoir.
    var isMine: Bool
    /// Les applaudissements. Un mur où l'on ne peut pas réagir est froid : quelqu'un qui demande
    /// « 3h30, quelqu'un sur ce rythme ? » et ne reçoit rien ne saura jamais si personne ne l'a lu
    /// ou si personne n'est au même rythme.
    var kudos: Int
    var kudoedByMe: Bool
    var createdAt: Date
    var author: PublicUser
}

/// Tout ce qu'une page de course affiche, en un seul aller-retour. Cinq requêtes pour un écran
/// qu'on ouvre en marchant vers le métro, ce sont cinq occasions de ne rien voir.
struct RacePage: Decodable {
    var race: RaceEvent
    var me: RaceFollow?
    var runners: [RaceRunner]
    var posts: [RacePost]
}
