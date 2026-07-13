import Foundation
import SwiftData

enum ChatRole: String, Codable {
    case user, coach, error
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
