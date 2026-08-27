import Foundation
import Speech
import AVFoundation
import Observation

/// Real hands-free voice coaching during a live run — tap the mic, ask a question out loud
/// ("Comment je suis niveau allure ?"), get a real spoken reply from the actual AI coach, not a
/// pre-recorded clip. This is the one place competitor apps (Nike Run Club, Adidas Running) only
/// ever fake "voice coaching" with scripted audio — RunUp already has a real conversational coach
/// (`CoachService`) behind everything else, so this is a real extension of it, not new backend.
///
/// Deliberately tap-to-talk, not always-listening: a real wake-word pipeline needs a low-power
/// always-on audio path that's a much bigger, riskier build (battery, false triggers, background
/// audio review implications) — a single tap is reliable and still fully hands-free once tapped.
///
/// `@MainActor` : `state`, `partialTranscript`, `lastReply` et `lastError` sont lus par
/// `LiveRunView` à chaque image. Ils étaient écrits depuis trois files différentes — celle de
/// `SFSpeechRecognitionTask`, celle du délégué `AVSpeechSynthesizer`, et la `Task` de la requête
/// réseau. Le code sautait déjà sur le fil principal à chaque fois, mais par discipline : rien ne
/// l'imposait, et un seul oubli suffisait à créer une course de données invisible en débogage.
@MainActor
@Observable
final class VoiceCoachController: NSObject {
    enum VoiceState: Equatable {
        case idle
        case listening
        case thinking
        case speaking
    }

    private(set) var state: VoiceState = .idle
    private(set) var lastReply: String?
    /// Live partial transcript while listening — lets the UI show what it's hearing.
    private(set) var partialTranscript: String = ""
    /// Surfaced by `LiveRunView`'s top banner — every failure path here used to be a bare
    /// `return`, so tapping the mic with a denied permission (or losing the network mid-question)
    /// did literally nothing visible. Auto-clears after a few seconds (same idea as the scripted
    /// cues) so a one-off failure doesn't occupy the banner for the rest of the run.
    private(set) var lastError: String?
    private var errorClearTask: Task<Void, Never>?

    private func reportError(_ message: String) {
        errorClearTask?.cancel()
        lastError = message
        // La `Task` hérite de l'isolation `@MainActor` de la méthode, d'où la disparition du
        // `await MainActor.run` qui l'entourait.
        errorClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.lastError = nil
        }
    }

    /// Called by the mic button when the system permission request comes back denied — the
    /// controller can't know that itself (the view owns the request flow).
    func reportAuthorizationDenied() {
        reportError(String(localized: "Micro non autorisé — active-le dans Réglages > RunUp."))
    }

    private let profile: UserProfile
    /// Supplies live run stats (pace/distance/elapsed) at the moment a question is sent — a
    /// closure rather than stored values, since those change every second and this controller
    /// shouldn't need to be told about every tick.
    private let liveContextProvider: () -> String

    // Même langue que le coach : un moteur français transcrivant une question anglaise renvoie
    // du charabia, qui part ensuite tel quel dans le prompt.
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: CoachLanguage.current.speechIdentifier))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()

    init(profile: UserProfile, liveContextProvider: @escaping () -> String) {
        self.profile = profile
        self.liveContextProvider = liveContextProvider
        super.init()
        synthesizer.delegate = self
    }

    /// Call once before offering the mic button — both permissions only ever prompt once per
    /// install, later calls are harmless no-ops.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        return speechStatus == .authorized && micGranted
    }

    /// The mic button's single action — start listening on tap, stop-and-send on the next tap.
    /// Ignored while the coach is thinking or speaking (no barge-in in v1).
    func toggle() {
        switch state {
        case .idle: startListening()
        case .listening: stopListeningAndSend()
        case .thinking, .speaking: break
        }
    }

    private func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            reportError(String(localized: "Reconnaissance vocale indisponible sur cet appareil."))
            return
        }
        guard let recognitionRequest = try? configureAudioSession() else {
            reportError(String(localized: "Micro indisponible — vérifie l'autorisation dans Réglages > RunUp."))
            return
        }

        state = .listening
        partialTranscript = ""
        errorClearTask?.cancel()
        lastError = nil
        self.recognitionRequest = recognitionRequest

        // `@Sendable` explicite : le moteur de reconnaissance rappelle depuis sa propre file. Sans
        // l'annotation, cette fermeture — écrite dans une méthode `@MainActor` — serait implicitement
        // isolée sur l'acteur principal, alors qu'elle est en réalité invoquée ailleurs.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { @Sendable [weak self] result, _ in
            guard let self, let result else { return }
            // Le texte est extrait ICI (une `String` traverse sans risque), puis publié sur le fil
            // principal : c'est lui qui alimente la bulle de transcription en direct.
            let text = result.bestTranscription.formattedString
            Task { @MainActor in self.partialTranscript = text }
        }
    }

    private func configureAudioSession() throws -> SFSpeechAudioBufferRecognitionRequest {
        let session = AVAudioSession.sharedInstance()
        // `.allowBluetoothHFP` et non `.allowBluetooth` : un pur renommage côté Apple, la même
        // constante, disponible sur toutes les versions que l'app vise. HFP est le profil qui
        // ouvre le MICRO d'un casque Bluetooth — exactement ce qu'il faut ici, où l'on écoute une
        // question posée à voix haute pendant la course.
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        return request
    }

    private func stopListeningAndSend() {
        let question = partialTranscript
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        partialTranscript = ""

        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else {
            state = .idle
            return
        }

        state = .thinking
        Task {
            do {
                let reply = try await CoachService.sendLiveVoiceQuery(
                    question: question,
                    liveContext: liveContextProvider(),
                    profile: profile
                )
                self.speak(reply)
            } catch {
                self.state = .idle
                self.reportError(String(localized: "Le coach n'a pas pu répondre — vérifie ta connexion."))
            }
        }
    }

    private func speak(_ text: String) {
        lastReply = text
        state = .speaking
        // Standalone announcements (see `announce(_:)`) never went through `configureAudioSession`
        // (that only runs on mic tap), so without this the very first pace alert of a run could
        // speak into whatever ambient session category the OS defaulted to — silent, or not
        // ducking a podcast/music app. Safe to (re)apply here even after a real listen → reply
        // flow: recording has already stopped by the time a reply is ready to speak.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        // La voix suit la langue du coach : une réponse anglaise lue par une voix française est
        // inintelligible, et c'est le seul canal où elle n'a pas d'écran pour rattraper.
        utterance.voice = AVSpeechSynthesisVoice(language: CoachLanguage.current.speechIdentifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// An app-initiated spoken alert (a pace-zone nudge from `LiveRunViewModel`) — distinct from
    /// the tap-to-ask flow: only speaks when the mic is genuinely idle, so it can never interrupt
    /// or talk over a real question/answer exchange already in progress.
    func announce(_ text: String) {
        guard state == .idle else { return }
        speak(text)
    }

    /// Call when the run ends/pauses so the mic doesn't keep the audio session claimed.
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
    }
}

// `nonisolated` : `AVSpeechSynthesizer` appelle son délégué depuis sa propre file audio, pas
// depuis le fil principal — le saut est donc écrit là où il se produit.
extension VoiceCoachController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.state = .idle }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.state = .idle }
    }
}
