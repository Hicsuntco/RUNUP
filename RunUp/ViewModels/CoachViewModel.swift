import Foundation
import Observation
import SwiftData

/// Drives the coach chat — real Anthropic API calls via `CoachService`. Mirrors `sendCoach` in
/// app.jsx: builds a fresh system prompt from live profile state on every message, surfaces a
/// visible error bubble (with manual retry) on failure rather than retrying silently.
///
/// `@MainActor` : ce modèle possède un `ModelContext` et un `UserProfile` — des objets SwiftData
/// liés au fil principal — et insère/supprime des `ChatMessage`. Rien de tout cela ne peut être
/// touché ailleurs.
@MainActor
@Observable
final class CoachViewModel {
    private let modelContext: ModelContext
    private let profile: UserProfile

    var isTyping = false
    var draft = ""

    init(modelContext: ModelContext, profile: UserProfile) {
        self.modelContext = modelContext
        self.profile = profile
    }

    func send(_ text: String, history: [ChatMessage]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping else { return }
        let userMessage = ChatMessage(role: .user, text: trimmed)
        modelContext.insert(userMessage)
        draft = ""
        request(history: history + [userMessage])
    }

    /// Re-sends the last user message WITHOUT inserting it again — the old retry path went back
    /// through `send`, so every tap duplicated her bubble in the thread.
    func retry(history: [ChatMessage]) {
        guard !isTyping, history.contains(where: { $0.role == .user }) else { return }
        request(history: history)
    }

    private func request(history: [ChatMessage]) {
        isTyping = true
        // La `Task` hérite de l'isolation `@MainActor`, d'où la disparition des deux
        // `await MainActor.run` : le corps y est déjà. Seul l'appel réseau, `nonisolated` dans
        // `CoachService`, quitte le fil principal.
        Task {
            do {
                let reply = try await CoachService.send(history: history, profile: profile)
                // A successful reply makes the old "Connexion coupée" bubbles (persisted, so
                // they'd otherwise litter the thread forever) obsolete — clear them.
                for stale in history.filter({ $0.role == .error }) {
                    modelContext.delete(stale)
                }
                modelContext.insert(ChatMessage(role: .coach, text: reply))
                isTyping = false
                // The reply often lands while she's mid-warmup, phone in hand but eyes
                // elsewhere — a light tap says "réponse arrivée" without needing to look.
                Haptics.impact(.light)
            } catch {
                // At most one live error bubble — replace, don't stack.
                for stale in history.filter({ $0.role == .error }) {
                    modelContext.delete(stale)
                }
                modelContext.insert(ChatMessage(role: .error, text: String(localized: "Connexion coupée — le coach n'a pas pu répondre. Réessaie dans un instant.")))
                isTyping = false
            }
        }
    }
}
