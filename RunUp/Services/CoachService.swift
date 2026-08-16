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
    ///
    /// Read from the app's Info.plist key `RUNUPAppSecret`, which Xcode fills at build time from
    /// the `RUNUP_APP_SECRET` build setting (see `project.yml` → `configFiles`, `Config.xcconfig`
    /// at the repo root, and `Secrets.xcconfig`, which is gitignored and holds the real value on
    /// her machine — IOS_SETUP.md § "Coach backend"). It used to be a string literal right here,
    /// which meant the live production secret sat in the repo — and in its history — readable by
    /// anyone who ever gets a copy of the source. A build without `Secrets.xcconfig` gets an empty
    /// string here and the coach endpoint answers 401, which is the intended loud failure.
    ///
    /// This is NOT a real security boundary, and moving it out of source doesn't make it one: any
    /// static secret shipped inside the app is extractable from the IPA (`strings` on the binary,
    /// or just reading Info.plist out of the bundle) by anyone who downloads it from the App
    /// Store. What this buys is narrower — the secret is no longer committed, and rotating it is a
    /// config change, not a code change. The only real fix is proving the caller is a genuine,
    /// unmodified copy of this app rather than knowing a shared string: App Attest / DeviceCheck,
    /// where the app produces a per-request assertion Apple's servers vouch for and `api/coach.js`
    /// verifies. Deliberately not done here (it needs a server-side attestation flow, key
    /// generation + challenge round trip, and a fallback for the Simulator, which has no App
    /// Attest support).
    /// TODO(security): replace the `x-runup-secret` header with a DCAppAttestService assertion
    /// verified server-side in `api/coach.js`, and drop this shared secret entirely once shipped.
    private static let appSecret = Bundle.main.infoDictionary?["RUNUPAppSecret"] as? String ?? ""
    private static let raceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "d MMMM"
        return f
    }()

    static func send(history: [ChatMessage], profile: UserProfile) async throws -> String {
        try await performRequest(
            system: systemPrompt(for: profile),
            messages: history
                .filter { $0.role != .error }
                .map { RequestMessage(role: $0.role == .coach ? "assistant" : "user", content: $0.text) }
        )
    }

    /// A question asked out loud mid-run (see `VoiceCoachController`) — same coach, same backend,
    /// but a deliberately different system prompt: she's mid-effort and the reply gets read aloud
    /// via text-to-speech, so it needs to be one short spoken sentence, not chat-length copy.
    static func sendLiveVoiceQuery(question: String, liveContext: String, profile: UserProfile) async throws -> String {
        let system = """
        Tu es le coach running personnel de \(profile.name). Elle est EN TRAIN DE COURIR là, maintenant, et vient de te poser une question à voix haute pendant sa séance.
        \(liveContext)
        \(CoachLanguage.current.liveVoiceDirective) Ne dis jamais que tu es une IA.
        """
        return try await performRequest(system: system, messages: [RequestMessage(role: "user", content: question)])
    }

    private static func performRequest(system: String, messages: [RequestMessage]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(appSecret, forHTTPHeaderField: "x-runup-secret")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(MessagesRequest(system: system, messages: messages))

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
            extra.append("Attention, zone sensible signalée : \(AdaptivePlanEngine.injuryLabel(injury)).")
        }
        if let phase = s.cyclePhase {
            extra.append("Phase du cycle estimée : \(phase.rawValue) — adapte le ton (sois indulgent(e) sur l'intensité en phase menstruelle) sans jamais lui dire quoi faire de son corps à sa place.")
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
        Aujourd'hui : \(s.hasReadinessData ? "forme \(s.readiness)/100" : "pas encore assez de données pour estimer sa forme du jour"). Séance du jour : \(s.todaySession.title) (\(s.todaySession.durationMinutes) min, allure \(s.todaySession.pace), \(s.todaySession.zone)). Série de \(s.streak) jours.
        \(CoachLanguage.current.styleDirective) Au plus un emoji occasionnel. Ne dis jamais que tu es une IA ou un modèle. Tu peux ajuster ses séances, donner des conseils d'allure, de récup, de nutrition, d'objectif. Tu ne donnes JAMAIS d'avis médical : en cas de douleur persistante, blessure ou symptôme inquiétant, conseille-lui de consulter un médecin.
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
