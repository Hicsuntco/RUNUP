import Foundation
import SwiftData

/// A bell-icon notification. Mirrors `notifs` in app.jsx.
@Model
final class AppNotification {
    /// SF Symbol name, or "mark" to render the AppMark glyph instead.
    var icon: String
    /// RGB color, stored as `Int` — SwiftData/Core Data has no unsigned-integer attribute type.
    var colorHex: Int
    var title: String
    var text: String
    var timestamp: Date
    var read: Bool

    init(icon: String, colorHex: Int, title: String, text: String, timestamp: Date = .now, read: Bool = false) {
        self.icon = icon
        self.colorHex = colorHex
        self.title = title
        self.text = text
        self.timestamp = timestamp
        self.read = read
    }
}
