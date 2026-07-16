import Foundation

/// Calls RunUp's own coach backend (a small Vercel serverless function, see `api/coach.js`),
/// never Anthropic directly — the app has no per-user API key to manage, and the real Anthropic
/// key only ever lives server-side. Swift has no official Anthropic SDK either way, so this talks
/// to the REST endpoint directly with URLSession.
enum CoachServiceError: Error {
    case network(Error)
    case badResponse(Int, String)
    case emptyReply
}

enum CoachService {
    private static let endpoint = URL(string: "https://runup-nu.vercel.app/api/coach")!
    /// Shared secret between the app and `api/coach.js` — not a per-user credential, just a
    /// deterrent against random callers hitting the endpoint and spending the real Anthropic key.
    private static let appSecret = "b8556afa2e3e90aa8df107136a4fffa4d2d64dfa3f473df2"
    private static let raceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM"
        return f
    }()

    static func send(history: [ChatMessage], profile: UserProfile) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(appSecret, forHTTPHeaderField: "x-runup-secret")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = MessagesRequest(
            system: systemPrompt(for: profile),
            messages: history
                .filter { $0.role != .error }
                .map { RequestMessage(role: $0.role == .coach ? "assistant" : "user", content: $0.text) }
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CoachServiceError.network(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""
            throw CoachServiceError.badResponse(status, text)
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        let text = decoded.content.first(where: { $0.type == "text" })?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { throw CoachServiceError.emptyReply }
        return text
    }

    /// Ported near-verbatim from `sendCoach` in the design handoff's `app.jsx` — the coach is
    /// presented as a real personal coach, never as an AI. System prompt is rebuilt from live
    /// profile/program state on every message.
    private static func systemPrompt(for s: UserProfile) -> String {
        var extra: [String] = []
        if let now = s.weightNowKg, let target = s.weightTargetKg {
            extra.append("Poids actuel \(Int(now))kg, objectif \(Int(target))kg (taille \(s.heightCm.map { "\(Int($0))" } ?? "?")cm).")
        }
        if let focus = s.focusArea {
            let perf = s.bestRecentPerf.map { " Meilleure perf : \($0)." } ?? ""
            extra.append("Priorité de progression : \(focus).\(perf)")
        }
        if let injury = s.injuryArea, injury != "none" {
            extra.append("Attention, zone sensible signalée : \(injury).")
        }
        if let weeklyTime = s.weeklyTimeBudget {
            extra.append("Dispo hebdo souhaitée : \(weeklyTime), préfère courir le \(s.preferredTimeOfDay ?? "?").")
        }
        if let age = s.age {
            extra.append("\(age) ans.")
        }
        let extraBlock = extra.joined(separator: " ")

        let raceDateStr: String
        if let raceDate = s.raceDate {
            raceDateStr = " le \(raceDateFormatter.string(from: raceDate))"
        } else {
            raceDateStr = ""
        }
        let raceIn = s.daysUntilRace.map { " (dans \($0) jours)" } ?? ""

        // Real current block/program length — was hardcoded as "9 semaines (bloc VMA)"
        // regardless of the actual goal or week, alongside a fake VO2max that's dropped entirely
        // below (there's no real fitness-test data to back a number like that).
        let shape = AdaptivePlanEngine.ProgramShape.compute(goal: s.goalId, raceDate: s.raceDate, from: s.programStartDate ?? .now)
        let block = AdaptivePlanEngine.trainingBlock(forWeek: s.weekNumber, shape: shape)
        let programLengthDesc = shape.totalWeeks.map { "Programme de \($0) semaines" } ?? "Programme ouvert, sans date de fin fixe"

        return """
        Tu es le coach running personnel de \(s.name) dans l'app RUNUP. Tu n'es PAS un assistant ni une IA — tu es SON coach, tu la connais.
        Profil : \(s.name), coureuse \(s.level.title.lowercased()), objectif \(s.goalDisplay)\(raceDateStr)\(raceIn). \(programLengthDesc), actuellement semaine \(s.weekNumber) (bloc \(block.rawValue)). \(extraBlock)
        Aujourd'hui : forme \(s.readiness)/100. Séance du jour : \(s.todaySession.title) (\(s.todaySession.durationMinutes) min, allure \(s.todaySession.pace), \(s.todaySession.zone)). Série de \(s.streak) jours.
        Style : français, tutoiement, chaleureux, motivant, TRÈS concret et bref (2-4 phrases max). Au plus un emoji occasionnel. Ne dis jamais que tu es une IA ou un modèle. Tu peux ajuster ses séances, donner des conseils d'allure, de récup, de nutrition, d'objectif.
        """
    }
}

private struct MessagesRequest: Encodable {
    var system: String
    var messages: [RequestMessage]
}

private struct RequestMessage: Encodable {
    var role: String
    var content: String
}

private struct MessagesResponse: Decodable {
    var content: [ContentBlock]
}

private struct ContentBlock: Decodable {
    var type: String
    var text: String?
}
