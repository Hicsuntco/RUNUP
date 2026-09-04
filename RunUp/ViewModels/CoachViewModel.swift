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

    /// Le dernier changement appliqué, et de quoi le défaire.
    ///
    /// Un seul niveau, et en mémoire seulement. « Annuler » sert à rattraper un changement qu'on
    /// voit arriver et dont on ne veut pas ; passé le message suivant, ou une relance de l'app,
    /// ce n'est plus une annulation mais une modification, et elle se fait là où le réglage
    /// vit — dans les réglages du programme, ou en le redemandant au coach.
    private struct PendingUndo {
        var snapshot: AdaptivePlanEngine.CoachActionSnapshot
        var line: ChatMessage
    }
    private var pendingUndo: PendingUndo?

    init(modelContext: ModelContext, profile: UserProfile) {
        self.modelContext = modelContext
        self.profile = profile
    }

    /// Cette ligne est-elle celle qu'on peut encore défaire ?
    func canUndo(_ message: ChatMessage) -> Bool {
        pendingUndo?.line === message
    }

    func undoLastAction() {
        guard let pending = pendingUndo else { return }
        AdaptivePlanEngine.restore(pending.snapshot, to: profile)
        // La ligne reste, son texte change. La supprimer laisserait le message du coach — « on
        // allège cette semaine » — seul au-dessus d'un programme inchangé, sans rien pour
        // expliquer l'écart. Là, la contradiction est datée et lisible.
        pending.line.text = String(localized: "Annulé — ton programme n'a pas changé.")
        pendingUndo = nil
        Haptics.impact(.light)
    }

    func send(_ text: String, history: [ChatMessage]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping else { return }
        // Le tour précédent n'est plus annulable : son instantané ne décrit plus l'état courant
        // dès qu'un nouveau changement peut s'empiler dessus.
        pendingUndo = nil
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
                if let text = reply.text, !text.isEmpty {
                    modelContext.insert(ChatMessage(role: .coach, text: text))
                }
                // L'instantané est pris AVANT le tour entier, et une seule fois : c'est ce qui rend
                // « Annuler » exact que le coach ait appelé un outil ou quatre.
                //
                // Et une seule ligne pour tout le tour, pas une par action. « deux fois par
                // semaine, trente minutes maximum » est UNE demande dans sa tête ; lui répondre par
                // deux bandeaux empilés lui ferait relire deux fois la même chose, et laisserait
                // croire que deux décisions distinctes ont été prises.
                if !reply.actions.isEmpty {
                    let snapshot = AdaptivePlanEngine.snapshot(profile)
                    let summaries = reply.actions.compactMap {
                        AdaptivePlanEngine.applyCoachAction($0, to: profile)
                    }
                    if !summaries.isEmpty {
                        let line = ChatMessage(role: .system, text: summaries.joined(separator: " · "))
                        modelContext.insert(line)
                        pendingUndo = PendingUndo(snapshot: snapshot, line: line)
                    }
                }
                isTyping = false
                // The reply often lands while she's mid-warmup, phone in hand but eyes
                // elsewhere — a light tap says "réponse arrivée" without needing to look.
                Haptics.impact(.light)
            } catch {
                // At most one live error bubble — replace, don't stack.
                for stale in history.filter({ $0.role == .error }) {
                    modelContext.delete(stale)
                }
                // Un refus et une panne réseau demandent deux choses différentes à la coureuse :
                // l'une se répare en réessayant, l'autre jamais. Les afficher pareil, c'est
                // l'envoyer retaper trois fois une question qui ne passera pas.
                let message: String
                if case CoachServiceError.refused = error {
                    message = String(localized: "Le coach n'a pas pu répondre à ça. Reformule autrement — et si c'est une douleur qui dure, parles-en à un médecin.")
                } else {
                    message = String(localized: "Connexion coupée — le coach n'a pas pu répondre. Réessaie dans un instant.")
                }
                modelContext.insert(ChatMessage(role: .error, text: message))
                isTyping = false
            }
        }
    }
}
