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

    private let profile: UserProfile
    /// Supplies live run stats (pace/distance/elapsed) at the moment a question is sent — a
    /// closure rather than stored values, since those change every second and this controller
    /// shouldn't need to be told about every tick.
    private let liveContextProvider: () -> String

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
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
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }
        guard let recognitionRequest = try? configureAudioSession() else { return }

        state = .listening
        partialTranscript = ""
        self.recognitionRequest = recognitionRequest

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
            guard let self, let result else { return }
            self.partialTranscript = result.bestTranscription.formattedString
        }
    }

    private func configureAudioSession() throws -> SFSpeechAudioBufferRecognitionRequest {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
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
                await MainActor.run { self.speak(reply) }
            } catch {
                await MainActor.run { self.state = .idle }
            }
        }
    }

    private func speak(_ text: String) {
        lastReply = text
        state = .speaking
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
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

extension VoiceCoachController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.state = .idle }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.state = .idle }
    }
}
