import Foundation
import UIKit

/// One property value on an event. A plain `[String: Any]` would have been simpler to write and
/// impossible to `Codable`-encode (which is what lets a batch survive an app kill in
/// `UserDefaults`), and `[String: String]` would have stringified every number on the way out —
/// turning "average distance of a first run" into a parsing job on the analysis side. Four cases
/// cover everything the funnel actually records, and each one lands in Postgres `jsonb` as its
/// real JSON type.
enum AnalyticsValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool first: `JSONDecoder` will happily decode `true` as `Int` 1 on some platforms, and a
        // silently-numeric flag is worse than a decode failure.
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Int.self) { self = .int(value); return }
        if let value = try? container.decode(Double.self) { self = .double(value); return }
        self = .string(try container.decode(String.self))
    }
}

/// One buffered event, exactly as `api/events.js` expects it. `createdAt` is stamped at `track()`
/// time and sent up rather than left to the server's `now()`: a batch that was buffered offline
/// (or through an app kill) can legitimately arrive hours or days later, and letting the server
/// timestamp it would quietly attribute yesterday's onboarding to today — corrupting the exact
/// cohort/retention numbers this whole pipeline exists to produce. The server still clamps
/// implausible values, so a device with a wrong clock can't poison anything either way.
private struct QueuedEvent: Codable {
    var name: String
    var props: [String: AnalyticsValue]?
    var createdAt: Date
}

private struct AnalyticsBatch: Encodable {
    var anonymousId: String
    var events: [QueuedEvent]
}

/// RunUp's own analytics client — no third-party SDK anywhere in this app (see `db/schema.sql`'s
/// `events` table for that decision), just a small batching writer against our own backend.
///
/// Three hard rules, in the same spirit as `ClubActivityOutbox`:
///   * It never blocks the caller. `track()` returns immediately; everything real happens on a
///     private serial queue and then on `URLSession`.
///   * It never crashes the UI. There is no `try!`, no force unwrap, and no path where a failed
///     encode/request surfaces anywhere — the worst case is a lost event, which is strictly
///     better than a lost user.
///   * It never silently drops the buffer. Events are persisted to `UserDefaults` on every
///     append, so a kill (or a background flush the system cuts short) leaves the batch on disk to
///     be sent on the next launch, exactly like the club activity outbox.
///
/// It deliberately holds no reference to `AppState` or `AuthService`: the earliest and most
/// important events (the onboarding funnel) fire before either exists in a signed-in form, so the
/// session token is read straight from the Keychain at flush time instead — which also means an
/// event queued while signed out and flushed after signing in is correctly attributed.
final class Analytics: @unchecked Sendable {
    static let shared = Analytics()

    /// The complete vocabulary — every name here must also be in `KNOWN_EVENTS` in api/events.js,
    /// which rejects anything else. Kept deliberately short: instrumenting every tap produces a
    /// table nobody reads, so this covers only the decisions that would actually change what gets
    /// built next — where onboarding leaks, whether a first run ever happens, and whether the
    /// three things the app is *for* (running, the coach, the club) are used at all.
    enum EventName: String {
        /// Only real signal for DAU/WAU/MAU across the (majority) unsigned-in base — the whole app
        /// works without an account, so `users.last_seen_at` alone would measure Club members only.
        case appOpened = "app_opened"
        case onboardingStarted = "onboarding_started"
        case onboardingStepViewed = "onboarding_step_viewed"
        case onboardingStepCompleted = "onboarding_step_completed"
        case onboardingFinished = "onboarding_finished"
        case runStarted = "run_started"
        /// Fired once per install (see `trackOnce`) — activation, the single number that separates
        /// "installed the app" from "became a runner with it".
        case firstRunStarted = "first_run_started"
        case runCompleted = "run_completed"
        case firstRunCompleted = "first_run_completed"
        case coachMessageSent = "coach_message_sent"
        case clubCreated = "club_created"
        case clubJoined = "club_joined"
        /// Quel écran est ouvert, avec `screen` = le `rawValue` d'`AppScreen`. Ajouté quand le
        /// Profil a remplacé Club en 5e onglet : ce déplacement descend la couche sociale d'un
        /// niveau, et sans cet événement on ne pouvait ni confirmer ni infirmer que ça lui coûte
        /// de l'usage — les 12 événements existants disent ce qu'on FAIT dans l'app, aucun ne dit
        /// où l'on va. Un changement de navigation qu'on ne sait pas mesurer se défend à
        /// l'opinion, et c'est exactement ce qui s'est passé ici.
        ///
        /// Ne transporte QUE le nom de l'écran : pas d'identifiant de contenu, pas de durée, rien
        /// qui reconstitue un parcours nominatif. Un compteur de fréquentation, pas un journal de
        /// navigation.
        case screenViewed = "screen_viewed"
    }

    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!
    private static let bufferKey = "analytics.buffer.v1"
    private static let anonymousIDKey = "analytics.anonymousID.v1"
    private static let firedOnceKey = "analytics.firedOnce.v1"
    private static let lastAppOpenKey = "analytics.lastAppOpen.v1"

    /// Flush after this many buffered events, on top of the background/foreground triggers — so a
    /// long session that never backgrounds still delivers, without paying a request per tap.
    private static let flushThreshold = 10
    /// Must not exceed `MAX_EVENTS_PER_BATCH` in api/events.js, which 400s a larger batch.
    private static let maxEventsPerBatch = 50
    /// Hard ceiling on what an offline device accumulates. Past this the OLDEST events are dropped:
    /// if something has to be lost, losing the far end of a stale buffer beats losing what just
    /// happened.
    private static let maxBufferedEvents = 500
    /// Two foregrounds inside this window are the same session (checking a notification and coming
    /// straight back is not a second visit) — without it `app_opened` counts app-switching, not use.
    private static let newSessionGap: TimeInterval = 30 * 60

    private let queue = DispatchQueue(label: "com.hicsuntco.runup.analytics")
    private let defaults = UserDefaults.standard
    /// Only ever touched on `queue` — that serialization is what makes `@unchecked Sendable` above
    /// an accurate claim rather than a silencing of the compiler.
    private var buffer: [QueuedEvent]
    private var isFlushing = false

    private init() {
        // `UserDefaults.standard` rather than `self.defaults`: nothing may touch `self` until
        // every stored property is initialized.
        buffer = Self.loadBuffer(from: UserDefaults.standard)
        // Background is the one moment the batch is most likely to be complete and the app most
        // likely to be killed before the next one; foreground catches whatever a previous session
        // left behind (including a background flush the system cut short — the buffer is on disk,
        // so nothing is lost either way).
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.flush()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.flush()
        }
    }

    /// A stable, device-scoped id generated on first launch — never an IDFA/IDFV and never tied to
    /// anything identifying. It exists for one reason: without it the pre-account funnel is a pile
    /// of unrelated events with no way to tell one person's nine onboarding steps from nine
    /// people's first step. Reinstalling produces a new one, which is the honest behaviour.
    var anonymousID: String {
        if let existing = defaults.string(forKey: Self.anonymousIDKey) { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Self.anonymousIDKey)
        return fresh
    }

    /// Records one event. Safe to call from anywhere, including inside a SwiftUI view body's
    /// action closures and off the main actor — it does no work on the calling thread beyond
    /// building the value.
    func track(_ name: EventName, _ props: [String: AnalyticsValue]? = nil) {
        let event = QueuedEvent(name: name.rawValue, props: props, createdAt: Date())
        queue.async { [self] in enqueue(event) }
    }

    /// Records an event at most once per install — for the milestones whose whole meaning is
    /// "the first time" (`first_run_started`, `first_run_completed`). Doing this with a persisted
    /// marker here, rather than a new `UserProfile` field, keeps a purely analytical concern out of
    /// the SwiftData model the plan engine reads.
    func trackOnce(_ name: EventName, _ props: [String: AnalyticsValue]? = nil) {
        let event = QueuedEvent(name: name.rawValue, props: props, createdAt: Date())
        queue.async { [self] in
            var fired = Set(defaults.stringArray(forKey: Self.firedOnceKey) ?? [])
            guard !fired.contains(name.rawValue) else { return }
            fired.insert(name.rawValue)
            defaults.set(Array(fired), forKey: Self.firedOnceKey)
            enqueue(event)
        }
    }

    /// `app_opened`, debounced to one per real session (see `newSessionGap`). Call on launch and on
    /// every return to the foreground; it decides for itself whether that counts as a new visit.
    func trackAppOpenedIfNewSession() {
        queue.async { [self] in
            let last = defaults.double(forKey: Self.lastAppOpenKey)
            let now = Date().timeIntervalSince1970
            let elapsed = now - last
            // `elapsed < 0` means the device clock moved backwards since the last open — treat it
            // as a new session rather than letting one clock change suppress `app_opened` forever.
            guard last == 0 || elapsed >= Self.newSessionGap || elapsed < 0 else { return }
            defaults.set(now, forKey: Self.lastAppOpenKey)
            enqueue(QueuedEvent(name: EventName.appOpened.rawValue, props: nil, createdAt: Date()))
        }
    }

    /// Sends whatever is buffered. Called automatically on background/foreground and once the
    /// buffer passes `flushThreshold`; safe to call at any time, including with an empty buffer.
    func flush() {
        queue.async { [self] in sendNextBatch() }
    }

    // MARK: - Everything below runs on `queue`

    private func enqueue(_ event: QueuedEvent) {
        buffer.append(event)
        if buffer.count > Self.maxBufferedEvents {
            buffer.removeFirst(buffer.count - Self.maxBufferedEvents)
        }
        persistBuffer()
        if buffer.count >= Self.flushThreshold { sendNextBatch() }
    }

    private func persistBuffer() {
        guard let data = try? Self.encoder.encode(buffer) else { return }
        defaults.set(data, forKey: Self.bufferKey)
    }

    private func sendNextBatch() {
        guard !isFlushing, !buffer.isEmpty else { return }
        let batch = Array(buffer.prefix(Self.maxEventsPerBatch))
        guard let body = try? Self.encoder.encode(AnalyticsBatch(anonymousId: anonymousID, events: batch)) else {
            // A payload that can't be encoded will never encode on a later attempt either — keeping
            // it would wedge the buffer permanently behind an event that can never leave it.
            buffer.removeFirst(min(batch.count, buffer.count))
            persistBuffer()
            return
        }

        var request = URLRequest(url: Self.baseURL.appending(path: "api/events"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        // Optional by design, on both ends: the endpoint accepts anonymous batches (the onboarding
        // funnel has no account yet), and sends the token when there is one so the row can be
        // attributed and `users.last_seen_at` refreshed.
        if let token = KeychainService.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        isFlushing = true
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            // `self` is already strong here (unwrapped just above), so this inner hop needs no
            // capture list — but it is still an escaping closure, so Swift requires every member
            // access below to be spelled `self.`.
            self.queue.async {
                self.isFlushing = false
                // Delivered, or refused in a way that retrying can't fix (a malformed batch, an
                // event name this deploy doesn't know) — either way it must leave the buffer, or
                // the client would retry the same rejected batch forever and block everything
                // behind it. 429 is the exception: that one really is temporary, so it stays and
                // goes out on the next trigger.
                let delivered = (200..<300).contains(status)
                let permanentlyRefused = (400..<500).contains(status) && status != 429
                guard delivered || permanentlyRefused else { return }
                // `min` guards the one race the serial queue doesn't cover: events appended during
                // the request can push the buffer past `maxBufferedEvents` and trim it from the
                // front, so the count in flight may no longer all be there.
                self.buffer.removeFirst(min(batch.count, self.buffer.count))
                self.persistBuffer()
                // A buffer that was over `maxEventsPerBatch` still has more to send.
                self.sendNextBatch()
            }
        }.resume()
    }

    // MARK: -

    private static func loadBuffer(from defaults: UserDefaults) -> [QueuedEvent] {
        guard let data = defaults.data(forKey: bufferKey),
              let items = try? decoder.decode([QueuedEvent].self, from: data) else { return [] }
        return items
    }

    /// `.iso8601` on both sides — the same format `api/events.js` parses out of `createdAt`.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
