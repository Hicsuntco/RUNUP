import Foundation

/// CE QUE L'ÉCRAN A LE DROIT DE DIRE, SELON CE QUI A VRAIMENT ÉCHOUÉ.
///
/// # LE DÉFAUT QUE CE FICHIER EXISTE POUR FERMER
///
/// Trois services — le Club, l'authentification, le coach — portent chacun leur propre énumération
/// d'erreurs, avec les mêmes formes : `network`, `badResponse(code, corps)`, et une panne de
/// session. Onze écrans attrapaient tout ça par un `catch` nu ou un `try?`, puis affichaient la
/// même phrase : « vérifie ta connexion ».
///
/// Or ces pannes n'ont pas le même remède, et ils sont même opposés :
///
/// — une **session expirée** se règle en se reconnectant ;
/// — un **serveur qui refuse** se règle en attendant ;
/// — une **absence de réseau** se règle en changeant d'endroit.
///
/// « Vérifie ta connexion » est la pire des trois à deviner, parce que c'est la seule que la
/// personne peut vérifier d'un coup d'œil. Affichée sur un téléphone au wifi plein, elle n'apprend
/// rien sur la panne et beaucoup sur l'app — et elle envoie chercher là où il n'y a rien.
///
/// # POURQUOI ICI, ET PAS DANS CHAQUE VUE
///
/// L'erreur SAIT ce qu'elle est ; l'écran ne peut que le supposer. Et un écran nouveau n'a aucune
/// raison de penser à la distinction : `ci_scripts/check_reseau.py` interdit donc à une vue
/// d'affirmer une panne de réseau de son propre chef — la phrase doit venir d'ici.
enum PanneReseau {

    /// Les trois pannes, et elles n'ont pas le même remède.
    enum Cause: String {
        case sessionExpiree
        case serveur
        case reseau
    }

    /// 401 et 403 sont les deux seuls codes qui parlent de la SESSION et non du serveur. Les
    /// confondre avec le reste ferait attendre quelqu'un qui n'a qu'à se reconnecter.
    private static func sessionRefusee(_ code: Int) -> Bool { code == 401 || code == 403 }

    static func cause(de erreur: Error) -> Cause {
        if let club = erreur as? ClubServiceError {
            switch club {
            case .notSignedIn: return .sessionExpiree
            case .badResponse(let code, _): return sessionRefusee(code) ? .sessionExpiree : .serveur
            case .network: return .reseau
            }
        }
        if let auth = erreur as? AuthServiceError {
            switch auth {
            case .notSignedIn: return .sessionExpiree
            case .badResponse(let code, _): return sessionRefusee(code) ? .sessionExpiree : .serveur
            case .network: return .reseau
            }
        }
        if let coach = erreur as? CoachServiceError {
            switch coach {
            case .network: return .reseau
            case .badResponse(let code, _): return sessionRefusee(code) ? .sessionExpiree : .serveur
            // Une réponse vide, ou un refus du modèle : le serveur a répondu, et il a répondu 200.
            // Ce n'est ni le réseau ni la session. Un refus demande en plus une phrase à lui, que
            // les deux écrans du coach écrivent eux-mêmes — voir `CoachServiceError.refused`.
            case .emptyReply, .refused: return .serveur
            }
        }
        // Une `URLError` nue : tous les appels de l'app ne passent pas par ces trois services.
        if erreur is URLError { return .reseau }
        // Un échec de décodage, ou n'importe quoi d'autre : le serveur a répondu quelque chose que
        // cette version de l'app ne sait pas lire. Ni le réseau, ni la session — et nommer l'un
        // des deux enverrait chercher très loin d'où ça se passe.
        return .serveur
    }

    /// La phrase complète, pour un bandeau ou un message seul.
    static func phrase(pour erreur: Error) -> String {
        switch cause(de: erreur) {
        case .sessionExpiree:
            return String(localized: "Ta session a expiré — reconnecte-toi.")
        case .serveur:
            return String(localized: "RUNUP ne répond pas pour l'instant — réessaie dans un moment.")
        case .reseau:
            return String(localized: "Pas de connexion — réessaie quand tu auras du réseau.")
        }
    }

    /// Le motif court, pour une phrase déjà commencée : « Photo enregistrée, mais pas encore
    /// visible du club — <motif>. »
    ///
    /// Minuscule initiale et pas de point final : c'est une subordonnée, pas une phrase. Sans ce
    /// second rendu, les écrans qui ont déjà quelque chose à annoncer avant la panne devaient
    /// recoller deux phrases complètes, et c'est précisément ce qu'ils faisaient en inventant
    /// « vérifie ta connexion » plutôt que d'appeler `phrase(pour:)`.
    static func motif(pour erreur: Error) -> String {
        switch cause(de: erreur) {
        case .sessionExpiree:
            return String(localized: "ta session a expiré")
        case .serveur:
            return String(localized: "RUNUP ne répond pas pour l'instant")
        case .reseau:
            return String(localized: "pas de connexion")
        }
    }
}
