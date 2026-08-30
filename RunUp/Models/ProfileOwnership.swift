import Foundation

/// À qui appartiennent les données de cet appareil ?
///
/// Le nom, la photo, les objectifs, le programme et l'historique vivent SUR L'APPAREIL, pas dans
/// le compte. C'est un choix délibéré : l'app s'utilise entièrement sans compte, et quelqu'un qui
/// s'entraîne six semaines avant d'en créer un pour le Club ne doit rien perdre au moment de le
/// créer. Le compte se pose par-dessus, il ne remplace pas.
///
/// Ce choix a un angle mort, et c'est celui qu'on répare ici : rien ne reliait le profil local au
/// compte auquel il appartient. Se déconnecter puis se connecter avec un AUTRE compte laissait
/// donc le nom, la photo et le programme du précédent à l'écran — sur un téléphone prêté, revendu,
/// ou simplement partagé, quelqu'un voyait les données de quelqu'un d'autre sous son propre compte.
///
/// La décision est isolée ici, en logique pure : c'est une règle, elle se vérifie sans base de
/// données ni interface.
enum ProfileOwnership {

    enum Decision: Equatable {
        /// Le profil n'appartenait à personne — il devient celui de ce compte, sans rien perdre.
        ///
        /// C'est le cas de loin le plus fréquent, et le seul qui compte pour la promesse de
        /// l'app : on s'entraîne d'abord, on crée un compte ensuite. C'est aussi le cas des
        /// profils créés avant que ce champ n'existe, qui n'ont donc pas de propriétaire écrit :
        /// les adopter silencieusement est correct, puisque la personne devant l'écran est bien
        /// celle qui a toujours utilisé cet appareil.
        case adopt

        /// Le compte qui se connecte est déjà celui du profil. Rien à faire.
        case alreadyOwned

        /// Un autre compte. Il faut demander, et surtout ne rien décider tout seul.
        case conflict
    }

    static func decide(currentOwner: String?, signingIn accountID: String) -> Decision {
        guard let currentOwner, !currentOwner.isEmpty else { return .adopt }
        return currentOwner == accountID ? .alreadyOwned : .conflict
    }
}
