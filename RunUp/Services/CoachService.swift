import Foundation

/// Calls RunUp's own coach backend (a small Vercel serverless function, see `api/coach.js`),
/// never Anthropic directly — the app has no per-user API key to manage, and the real Anthropic
/// key only ever lives server-side. Swift has no official Anthropic SDK either way, so this talks
/// to the REST endpoint directly with URLSession.
enum CoachServiceError: Error {
    case network(Error)
    case badResponse(Int, String)
    case emptyReply
    /// Le modèle a décliné la demande. Ça arrive en HTTP 200, avec `stop_reason: "refusal"` et
    /// souvent rien d'exploitable dans le contenu — donc sans ce cas, un refus était indiscernable
    /// d'une panne réseau et s'affichait « Connexion coupée ». Ce n'est pas un détail sur un coach
    /// à qui on parle de douleurs, de blessures et de poids : lui dire de réessayer plus tard,
    /// c'est l'envoyer refaire trois fois quelque chose qui ne marchera pas.
    case refused
}

/// Ce que le coach renvoie : ce qu'il dit, et éventuellement ce qu'il change.
///
/// `text` est optionnel parce qu'un tour où le coach n'appelle que des outils est légitime — rare,
/// mais légitime. Dans ce cas c'est le résumé des actions qui tient lieu de message, plutôt qu'une
/// bulle vide au-dessus d'un bandeau qui, lui, dit déjà tout.
struct CoachReply: Sendable {
    var text: String?
    var actions: [CoachAction]
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
    /// Le format que les outils attendent pour les dates. `en_US_POSIX` pour la même raison que
    /// dans `CoachAction` : un formateur sur la locale de l'appareil n'écrit pas « 2026-09-17 »
    /// sur un calendrier non grégorien, et l'aller-retour ne retomberait pas sur ses pieds.
    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let raceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "d MMMM"
        return f
    }()

    /// `@MainActor` sur le PROLOGUE seulement, et c'est tout l'intérêt.
    ///
    /// `profile` et les `ChatMessage` de `history` sont des objets SwiftData `@Model` : ils
    /// appartiennent au `ModelContext` du fil principal et ne peuvent pas être lus ailleurs sans
    /// risquer une lecture déchirée ou un plantage. Or cette fonction était `nonisolated async`,
    /// donc `systemPrompt(for:)` et le `map` ci-dessous s'exécutaient sur l'exécuteur global —
    /// exactement le défaut d'isolation relevé par l'audit.
    ///
    /// L'isoler ne remet PAS le réseau sur le fil principal : `performRequest` reste `nonisolated`,
    /// et une fonction `async` non isolée appelée depuis l'acteur principal s'exécute sur
    /// l'exécuteur global. Le fil principal ne fait donc que ce qu'il est seul à pouvoir faire —
    /// lire les modèles et construire deux chaînes — puis rend la main.
    @MainActor
    static func send(history: [ChatMessage], profile: UserProfile) async throws -> CoachReply {
        try await performRequest(
            system: systemPrompt(for: profile),
            messages: history
                // Les bulles d'erreur ET les lignes d'action sont exclues : les premières ne sont
                // pas de la conversation, les secondes sont un compte rendu de ce que le coach
                // vient de faire. Les lui relire comme s'il les avait dites l'inviterait à les
                // refaire — l'état réel du programme, lui, est déjà dans le prompt système.
                .filter { $0.role == .user || $0.role == .coach }
                .map { RequestMessage(role: $0.role == .coach ? "assistant" : "user", content: $0.text) },
            allowActions: true
        )
    }

    /// A question asked out loud mid-run (see `VoiceCoachController`) — same coach, same backend,
    /// but a deliberately different system prompt: she's mid-effort and the reply gets read aloud
    /// via text-to-speech, so it needs to be one short spoken sentence, not chat-length copy.
    /// `@MainActor` pour la même raison que `send` ci-dessus : `profile.name` est lu ici.
    @MainActor
    static func sendLiveVoiceQuery(question: String, liveContext: String, profile: UserProfile) async throws -> String {
        let system = """
        Tu es le coach running personnel de \(profile.name). Elle est EN TRAIN DE COURIR là, maintenant, et vient de te poser une question à voix haute pendant sa séance.
        \(liveContext)
        \(CoachLanguage.current.liveVoiceDirective) Ne dis jamais que tu es une IA.
        """
        // `allowActions` reste faux : elle court, elle a le téléphone au bras et la réponse lui est
        // lue à voix haute. Restructurer son programme à cet instant-là, sans qu'elle puisse rien
        // voir ni annuler, n'est pas une chose qu'on fait à quelqu'un.
        let reply = try await performRequest(
            system: system,
            messages: [RequestMessage(role: "user", content: question)],
            allowActions: false
        )
        guard let text = reply.text, !text.isEmpty else { throw CoachServiceError.emptyReply }
        return text
    }

    private static func performRequest(
        system: String,
        messages: [RequestMessage],
        allowActions: Bool
    ) async throws -> CoachReply {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(appSecret, forHTTPHeaderField: "x-runup-secret")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            MessagesRequest(system: system, messages: messages, allowActions: allowActions)
        )

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
        // `first(where:)` et pas `first` : la réponse peut commencer par un bloc de réflexion ou
        // un appel d'outil. Chercher le bloc de texte plutôt que prendre le premier venu est ce
        // qui rend ce décodage indifférent à la réflexion du modèle.
        let text = decoded.content.first(where: { $0.type == "text" })?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let actions = decodeActions(from: data)
        guard (text?.isEmpty == false) || !actions.isEmpty else {
            throw decoded.stopReason == "refusal" ? CoachServiceError.refused : CoachServiceError.emptyReply
        }
        return CoachReply(text: text, actions: actions)
    }

    /// Extrait le premier appel d'outil exploitable de la réponse.
    ///
    /// `JSONSerialization` plutôt que `Codable` pour ce seul champ : `input` n'a pas de forme fixe
    /// — c'est un objet différent par outil — et lui écrire un décodeur générique coûterait une
    /// petite machinerie de valeurs JSON pour un gain nul, puisque c'est de toute façon en `Data`
    /// que `CoachAction.make` veut le recevoir.
    ///
    /// TOUS, et pas seulement le premier.
    ///
    /// Ce code n'en gardait qu'un, au motif qu'un seul changement à la fois se lit et se défait
    /// mieux. L'usage a tranché autrement : « deux fois par semaine, trente minutes maximum » est
    /// UNE demande qui se traduit en deux outils, et n'en appliquer qu'un a produit un programme
    /// raccourci mais toujours à trois séances — donc quelqu'un qui croit avoir été entendu et
    /// découvre le contraire dans l'onglet. À moitié appliqué est pire que pas appliqué : au moins
    /// « je n'ai pas pu » se voit.
    ///
    /// L'annulation, elle, ne souffre pas du pluriel : l'instantané est pris avant le tour entier,
    /// donc « Annuler » défait exactement ce que ce message a changé, qu'il y ait eu un outil ou
    /// quatre.
    private static let maxActionsPerTurn = 4

    private static func decodeActions(from data: Data) -> [CoachAction] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]] else { return [] }
        var actions: [CoachAction] = []
        for block in content where block["type"] as? String == "tool_use" {
            guard actions.count < maxActionsPerTurn else { break }
            guard let name = block["name"] as? String,
                  let input = block["input"],
                  let inputData = try? JSONSerialization.data(withJSONObject: input) else { continue }
            if let action = CoachAction.make(name: name, input: inputData) { actions.append(action) }
        }
        return actions
    }

    /// Ported near-verbatim from `sendCoach` in the design handoff's `app.jsx` — the coach is
    /// presented as a real personal coach, never as an AI. System prompt is rebuilt from live
    /// profile/program state on every message.
    @MainActor
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
        // Ce que le coach a DÉJÀ posé. Sans cette ligne il repose la même contrainte à chaque
        // message — il n'a aucun autre moyen de savoir que le tour précédent a abouti — et la
        // coureuse voit le même bandeau se répéter sans que rien ne change.
        if let ease = s.trainingEase, ease.isActive() {
            let cap = ease.maxMinutes.map { "\($0) min max" } ?? "pas de plafond de durée"
            let speed = ease.noSpeedWork ? ", sans fractionné" : ""
            let until = ease.until.formatted(.dateTime.day().month(.wide))
            extra.append("Allègement déjà en place (\(cap)\(speed)) jusqu'au \(until) — ne le repose pas, tu peux le remplacer ou le lever.")
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
        Tu peux modifier son programme pour de vrai, avec les outils fournis. Sers-t'en quand tu annonces un changement — dire « on allège cette semaine » sans appeler l'outil ne change rien à son programme, et elle le découvrira en ouvrant l'onglet. À l'inverse, n'appelle pas d'outil pour un simple conseil, ni pour confirmer quelque chose qui est déjà en place. Appelle AUTANT d'outils qu'il en faut pour couvrir toute sa demande, dans le même message : « deux fois par semaine, trente minutes maximum » en demande deux — la fréquence est `set_running_days`, la durée est `ease_training_load`. N'en appliquer qu'une partie est pire que rien : elle croit avoir été entendue et découvre un programme à moitié changé. Dis en toutes lettres tout ce que tu changes : c'est appliqué immédiatement.
        Aujourd'hui nous sommes le \(Self.isoDayFormatter.string(from: .now)) (format des dates attendu par les outils).
        """
    }
}

private struct MessagesRequest: Encodable {
    var system: String
    var messages: [RequestMessage]
    /// Demande au serveur de joindre les définitions d'outils (voir `api/coach.js`).
    ///
    /// C'est un drapeau qui ne peut que RESTREINDRE : le serveur ignore tout ce que l'app
    /// prétendrait sur les outils eux-mêmes et n'attache que sa propre liste, figée. Un client
    /// trafiqué peut donc se priver des actions, jamais s'en inventer — ce qui est exactement la
    /// même logique que le modèle et le plafond de jetons, imposés côté serveur depuis le début.
    var allowActions: Bool

    private enum CodingKeys: String, CodingKey {
        case system, messages
        case allowActions = "allow_actions"
    }
}

/// `Sendable` explicitement : cette valeur est la SEULE chose qui franchit la limite entre le
/// prologue isolé sur l'acteur principal (où les modèles SwiftData sont lus) et `performRequest`,
/// qui s'exécute sur l'exécuteur global. La conformité serait déduite ici, mais l'écrire noir sur
/// blanc rend l'invariant impossible à casser par inadvertance.
private struct RequestMessage: Encodable, Sendable {
    var role: String
    var content: String
}

private struct MessagesResponse: Decodable {
    var content: [ContentBlock]
    var stopReason: String?

    private enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}

private struct ContentBlock: Decodable {
    var type: String
    var text: String?
}
