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

    /// How the app ended up running against whatever store it's using.
    ///
    /// Written exactly once, by `makeContainer()`, before any view body has ever run — so a plain
    /// static is enough here and there is deliberately no `@Observable` wrapper around it: nothing
    /// can change this value after launch, so there is nothing for SwiftUI to observe.
    enum StoreState: Equatable {
        /// The on-disk store opened normally. The only case anyone should ever see.
        case healthy
        /// The on-disk store refused to open and the app is running on a THROWAWAY in-memory
        /// container instead. Everything already saved is invisible for this session, and anything
        /// written during it is lost on quit — but the file itself is still sitting on disk,
        /// untouched, so it stays recoverable. Carries the underlying error's description so the
        /// failure can be shown/logged instead of only guessed at.
        case inMemoryFallback(reason: String)
    }

    /// See `StoreState`. Read it to warn the user that this session is not being saved — Réglages
    /// or a banner are both reasonable places; `RunUpApp` currently surfaces it as a toast at
    /// launch, which is the minimum, not the ceiling.
    private(set) static var storeState: StoreState = .healthy

    /// Convenience for the common "should I warn her?" check at a call site that doesn't care why.
    static var isUsingFallbackStore: Bool {
        if case .inMemoryFallback = storeState { return true }
        return false
    }

    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A store that can't open (a model change that isn't a valid lightweight migration
            // from what's on disk) must not crash the app forever — every launch failing, with
            // reinstalling as the only way out, is not an acceptable outcome either. But the
            // previous answer to that was worse than the problem: it deleted the store file (plus
            // its -wal/-shm sidecars) and reopened an empty one. That is a SILENT, IRREVERSIBLE
            // wipe of every run she ever logged, her whole program, and the entire coach
            // conversation — triggered by a bug in OUR schema evolution, on an ordinary App Store
            // update, with no prompt, no warning, and no way back. "HealthKit still has the
            // workouts" was doing a lot of work in that argument: it doesn't hold the chat history,
            // the RPE debriefs, the shoes, the notifications or the program state at all, and it
            // only holds the runs for someone who actually connected Apple Santé.
            //
            // So: don't touch the file. Fall back to an in-memory container of the same schema —
            // which has no on-disk store to migrate and therefore essentially cannot fail for the
            // reason the disk one just did — and record WHY on `storeState` so the UI can say so
            // out loud. The tradeoff that buys:
            //   - The app still launches and is fully usable, same as the wipe gave us.
            //   - This session starts empty, so onboarding will run again (`AppState.init` finds no
            //     `UserProfile` and inserts a fresh one) and nothing written today survives quitting.
            //     That is a WORSE session than the wipe gave us — deliberately. It's loud instead
            //     of quiet, and, crucially, it's temporary: the real data is still on disk.
            //   - Because the file survives, a later build that fixes the schema (or adds a real
            //     migration plan) reopens it and everything comes back. Deleting it made that
            //     impossible forever.
            // This is explicitly not a migration framework and shouldn't grow into one here — it's
            // the failure path. Schema changes that need more than a lightweight migration belong
            // in a real `SchemaMigrationPlan` passed to `ModelContainer`, so this path stays the
            // thing that never happens.
            storeState = .inMemoryFallback(reason: String(describing: error))
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                // Nothing left to degrade to: the schema itself can't be materialised even with no
                // storage involved, which is a programming error in the model definitions rather
                // than anything about this user's data or device. Crashing here loses nothing —
                // there is no container to hand `RunUpApp` and no on-disk file at risk.
                fatalError("Impossible de créer le ModelContainer SwiftData, même en mémoire: \(error)")
            }
        }
    }
}
