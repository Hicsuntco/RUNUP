import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        UserProfile.self,
        RunRecord.self,
        ChatMessage.self,
        AppNotification.self
    ])

    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible de créer le ModelContainer SwiftData: \(error)")
        }
    }
}
