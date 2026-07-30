import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        UserProfile.self,
        RunRecord.self,
        ChatMessage.self,
        AppNotification.self,
        Shoe.self
    ])

    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A store that can't open (a model change that isn't a valid lightweight migration
            // from what's on disk) used to fatalError — every launch crashed forever, with
            // reinstalling the app as the only way out. The model is still actively evolving, so
            // this is a real risk on updates: destroy the local store and start fresh instead.
            // Weighing what's actually lost: run history/chat/notifications are local-only and
            // gone (real, but recoverable — HealthKit still holds the workouts, Strava can
            // re-import), while the account/club live server-side and survive. A working app
            // with a reset local cache beats a permanently crashing one.
            let storeURL = configuration.url
            try? FileManager.default.removeItem(at: storeURL)
            // The SQLite WAL/SHM sidecars must go too — a stale WAL re-associated with the fresh
            // store can re-corrupt it on the retry, landing in the fatalError this exists to avoid.
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Impossible de créer le ModelContainer SwiftData même après reset: \(error)")
            }
        }
    }
}
