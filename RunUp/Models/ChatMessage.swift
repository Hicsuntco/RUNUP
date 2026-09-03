import Foundation
import SwiftData

enum ChatRole: String, Codable {
    case user, coach, error
    /// Le compte rendu d'un changement que le coach vient d'appliquer au programme
    /// (voir `CoachAction`). Ce n'est pas quelqu'un qui parle : c'est l'app qui dit ce qu'elle a
    /// fait, et c'est pour ça que ces lignes ne repartent pas dans l'historique envoyé au modèle.
    ///
    /// Ajouter un cas à une énumération déjà enregistrée est sans risque ici : la valeur brute des
    /// cas existants ne bouge pas, donc les messages déjà sur disque se relisent à l'identique, et
    /// « system » n'apparaît que dans des lignes écrites par cette version ou une plus récente.
    case system
}

/// One message in the coach chat log. Mirrors `chat` in app.jsx.
@Model
final class ChatMessage {
    var role: ChatRole
    var text: String
    var timestamp: Date

    init(role: ChatRole, text: String, timestamp: Date = .now) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
