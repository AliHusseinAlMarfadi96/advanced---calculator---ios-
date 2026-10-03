import AVFoundation
import Combine
import Foundation
import Speech

final class VoiceAssistantViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var statusText = ""
    @Published var showingExactError = false
    @Published var transcript = ""
    @Published var expressionText = ""
    @Published var resultText = ""
    @Published var isPaused = false
    @Published var canSave = false

    private var settings: AppSettings?
    private var history: HistoryStore?
    private let synthesizer = AVSpeechSynthesizer()
    private let beep = BeepPlayer()
    private let capture = SpeechCaptureSession()
    private var generation = 0
    private var callbackID = 0
    private var suppressSpeechCancel = false
    private var started = false
    private var exited = false
    private var acceptingResults = false
    private var pendingEntry: HistoryEntry?
    private var retryItem: DispatchWorkItem?
    private var speechCompletion: (() -> Void)?
    private var speechKind: SpeechKind = .none

    private enum SpeechKind {
        case none
        case exactError
        case other
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start(settings: AppSettings, history: HistoryStore) {
        self.settings = settings
        self.history = history
        guard !started else { return }
        started = true
        statusText = L10n.text("voice.listening", language: settings.language)
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                guard status == .authorized else {
                    self.statusText = L10n.text("voice.speechDenied", language: settings.language)
                    self.isPaused = true
                    return
                }
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self, !self.exited else { return }
                        guard granted else {
                            self.statusText = L10n.text("voice.micDenied", language: settings.language)
                            self.isPaused = true
                            return
                        }
                        self.beginListening()
                    }
                }
            }
        }
    }

    func cancelTapped() {
        generation += 1
        callbackID += 1
        retryItem?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
        stopEngine()
        transcript = ""
        expressionText = ""
        resultText = ""
        pendingEntry = nil
        canSave = false
        showingExactError = false
        isPaused = true
        if let settings {
            statusText = L10n.text("voice.cancelled", language: settings.language)
        }
    }

    func pauseTapped() {
        guard let settings else { return }
        if isPaused {
            isPaused = false
            showingExactError = false
            statusText = L10n.text("voice.listening", language: settings.language)
            beginListening()
            return
        }
        generation += 1
        callbackID += 1
        retryItem?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
        stopEngine()
        isPaused = true
        showingExactError = false
        statusText = L10n.text("voice.paused", language: settings.language)
    }

    func saveTapped() {
        guard let settings else { return }
        guard let pendingEntry else {
            showingExactError = false
            statusText = L10n.text("voice.nothingToSave", language: settings.language)
            return
        }
        history?.add(expression: pendingEntry.expression, result: pendingEntry.result)
        showingExactError = false
        statusText = L10n.text("voice.saved", language: settings.language)
    }

    func shutdown() {
        exited = true
        generation += 1
        callbackID += 1
        retryItem?.cancel()
        speechCompletion = nil
        synthesizer.stopSpeaking(at: .immediate)
        stopEngine()
        beep.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.completeSpeech(cancelled: false)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.completeSpeech(cancelled: true)
        }
    }

    private func beginListening() {
        guard let settings, !exited, !isPaused else { return }
        let generation = self.generation
        let fire = { [weak self] in
            guard let self, self.generation == generation, !self.exited, !self.isPaused else { return }
            self.startRecognition()
        }
        if settings.startBeep {
            beep.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: fire)
        } else {
            fire()
        }
    }

    private func startRecognition() {
        guard let settings, !exited, !isPaused else { return }
        beep.stop()
        callbackID += 1
        let callbackID = self.callbackID
        stopEngine()
        let locale = Locale(identifier: settings.language.speechLocale)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            statusText = L10n.text("voice.unavailable", language: settings.language)
            isPaused = true
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        capture.request = request
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            let input = capture.engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                statusText = L10n.text("voice.unavailable", language: settings.language)
                isPaused = true
                return
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak capture] buffer, _ in
                capture?.request?.append(buffer)
            }
            capture.tapInstalled = true
            capture.engine.prepare()
            try capture.engine.start()
        } catch {
            statusText = L10n.text("voice.unavailable", language: settings.language)
            isPaused = true
            stopEngine()
            return
        }
        acceptingResults = true
        showingExactError = false
        transcript = ""
        statusText = L10n.text("voice.listening", language: settings.language)
        capture.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.callbackID == callbackID else { return }
                self.handleRecognition(result: result, error: error)
            }
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        guard acceptingResults else { return }
        if let result {
            transcript = result.bestTranscription.formattedString
            if result.isFinal {
                acceptingResults = false
                stopEngine()
                interpretFinalTranscript()
                return
            }
        }
        if error != nil {
            acceptingResults = false
            stopEngine()
            scheduleListenAgain(after: 0.6)
        }
    }

    private func interpretFinalTranscript() {
        guard let settings else { return }
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if spoken.isEmpty {
            scheduleListenAgain(after: 0.4)
            return
        }
        switch SpeechMathParser.interpret(spoken) {
        case let .success(expression, value):
            let formatted = ExpressionEvaluator.format(value)
            expressionText = expression
            resultText = formatted
            canSave = true
            pendingEntry = HistoryEntry(id: UUID(), expression: expression, result: formatted, createdAt: Date())
            showingExactError = false
            let sentence = L10n.text("voice.resultSpoken", language: settings.language)
                .replacingOccurrences(of: "%@", with: formatted)
            statusText = sentence
            if settings.assistantSpeech {
                speak(sentence, languageCode: settings.language.speechLocale, kind: .other) { [weak self] in
                    self?.scheduleListenAgain(after: 0.4)
                }
            } else {
                scheduleListenAgain(after: 0.8)
            }
        case .notUnderstood:
            presentNotUnderstood()
        case let .mathError(failure):
            let message = L10n.failure(failure, language: settings.language)
            showingExactError = false
            statusText = message
            if settings.assistantSpeech {
                speak(message, languageCode: settings.language.speechLocale, kind: .other) { [weak self] in
                    self?.scheduleListenAgain(after: 0.4)
                }
            } else {
                scheduleListenAgain(after: 1.2)
            }
        }
    }

    private func presentNotUnderstood() {
        stopEngine()
        showingExactError = true
        guard let settings else { return }
        if settings.assistantSpeech {
            speak(AppPhrases.notUnderstood, languageCode: "ar-SA", kind: .exactError) { [weak self] in
                self?.scheduleListenAgain(after: 3)
            }
        } else {
            scheduleListenAgain(after: 3)
        }
    }

    private func scheduleListenAgain(after delay: TimeInterval) {
        guard !exited, !isPaused else { return }
        retryItem?.cancel()
        let generation = self.generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == generation, !self.exited, !self.isPaused else { return }
            if let settings = self.settings {
                self.showingExactError = false
                self.statusText = L10n.text("voice.listening", language: settings.language)
            }
            self.beginListening()
        }
        retryItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func speak(_ text: String, languageCode: String, kind: SpeechKind, then: @escaping () -> Void) {
        let generation = self.generation
        speechKind = kind
        speechCompletion = { [weak self] in
            guard let self, self.generation == generation, !self.exited, !self.isPaused else { return }
            then()
        }
        if synthesizer.isSpeaking {
            suppressSpeechCancel = true
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        if kind == .exactError {
            utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA") ?? AVSpeechSynthesisVoice(language: "ar")
        } else if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }
        utterance.rate = kind == .exactError ? 0.46 : AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        let fallback = kind == .exactError ? 9.0 : 6.0
        DispatchQueue.main.asyncAfter(deadline: .now() + fallback) { [weak self] in
            guard let self, self.generation == generation else { return }
            self.completeSpeech(cancelled: false)
        }
    }

    private func completeSpeech(cancelled: Bool) {
        if cancelled && suppressSpeechCancel {
            suppressSpeechCancel = false
            return
        }
        guard let completion = speechCompletion else { return }
        speechCompletion = nil
        speechKind = .none
        if cancelled { return }
        completion()
    }

    private func stopEngine() {
        acceptingResults = false
        if capture.tapInstalled {
            capture.engine.inputNode.removeTap(onBus: 0)
            capture.tapInstalled = false
        }
        if capture.engine.isRunning {
            capture.engine.stop()
        }
        capture.request?.endAudio()
        capture.task?.cancel()
        capture.request = nil
        capture.task = nil
    }
}

private final class SpeechCaptureSession {
    let engine = AVAudioEngine()
    var request: SFSpeechAudioBufferRecognitionRequest?
    var task: SFSpeechRecognitionTask?
    var tapInstalled = false
}
