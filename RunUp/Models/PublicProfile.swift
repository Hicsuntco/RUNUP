import Foundation

/// La page de quelqu'un.
///
/// # POURQUOI ELLE N'EXISTAIT PAS, ET CE QUE ÇA COÛTAIT
///
/// On pouvait suivre une personne, applaudir sa sortie, la croiser au classement du club et sur
/// la page d'une course — sans jamais pouvoir la REGARDER. Aucun nom n'était tapable nulle part.
/// C'est ce qui faisait « liste de lignes » plutôt que « réseau » : dans Strava comme dans
/// Instagram, chaque nom est une porte.
///
/// # LA DIFFÉRENCE ENTRE UN COMPTE PRIVÉ ET UN COMPTE VIDE
///
/// `canSeeRuns` est dit par le serveur, et il ne se déduit pas d'une liste vide. « Ce compte est
/// privé » et « cette personne n'a encore rien couru » sont deux écrans différents : le premier
/// invite à demander à suivre, le second n'invite à rien. Quand il est faux, les sorties ne sont
/// pas masquées côté app — la requête n'est pas faite du tout.
struct PublicProfile: Decodable, Identifiable, Hashable, Nomme {
    var id: String
    var name: String
    var lastName: String?
    var username: String?
    var bio: String?
    var avatarUrl: String?
    var avatarBase64: String?
    var isPrivate: Bool
    var isMe: Bool
    /// Ma relation à cette personne : nil, « pending » (demande envoyée) ou « accepted ».
    var followStatus: String?
    /// Elle, me suit-elle ? Ce qui permet d'écrire « vous vous suivez » plutôt que deux boutons.
    var followsMe: Bool
    var followers: Int
    var following: Int
    var runs: Int
    var totalKm: Double
    var badgeKeys: [String]
    var joinedAt: Date
    var canSeeRuns: Bool

    var jeLaSuis: Bool { followStatus == "accepted" }
    var demandeEnvoyee: Bool { followStatus == "pending" }

    var nomDeFamille: String? { lastName }
}

/// Ce que rend `api/friends/profile` : la personne, et ses vingt dernières sorties — vides quand
/// `profile.canSeeRuns` est faux.
struct PublicProfilePage: Decodable {
    var profile: PublicProfile
    var items: [FeedItem]
}
