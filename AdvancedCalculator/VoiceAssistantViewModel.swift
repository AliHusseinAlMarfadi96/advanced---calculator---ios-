import AVFoundation
import Combine
import Foundation
import Speech
import UIKit

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
    private var settleItem: DispatchWorkItem?
    private var speechCompletion: (() -> Void)?
    private var speechKind: SpeechKind = .none
    /// False until this listening session receives new text, so Pause/Resume does not re-evaluate the kept transcript.
    private var transcriptReadyForEval = false
    /// Last successful assistant result. Prefixed onto a leading-operator phrase.
    private var runningTotal: Double = 0
    /// Value of `runningTotal` when the current listening turn started, so Save does not apply the phrase twice.
    private var continuationBase: Double = 0
    /// Transcript already turned into `pendingEntry`, compared so Save does not continue from the updated total.
    private var evaluatedTranscript: String?
    private var didRequestClose = false
    var onRequestClose: (() -> Void)?
    private static let runningTotalKey = "advancedCalculator.voiceRunningTotal"

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
        loadRunningTotal()
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
        settleItem?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
        stopEngine()
        transcriptReadyForEval = false
        evaluatedTranscript = nil
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
        settleItem?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
        stopEngine()
        isPaused = true
        showingExactError = false
        statusText = L10n.text("voice.paused", language: settings.language)
    }

    func saveTapped() {
        guard let settings else { return }
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if handleCommandIfPresent(spoken) {
            return
        }
        let visibleExpression = expressionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = !spoken.isEmpty ? spoken : visibleExpression
        let alreadyEvaluated = pendingEntry != nil && !spoken.isEmpty && spoken == evaluatedTranscript
        if !text.isEmpty && !alreadyEvaluated {
            switch SpeechMathParser.interpret(text, continuingFrom: continuationBase) {
            case let .success(expression, value):
                commitSuccess(expression: expression, value: value, spoken: spoken)
            case .notUnderstood:
                canSave = false
                pendingEntry = nil
                presentNotUnderstood(resumeListening: !isPaused)
                return
            case let .mathError(failure):
                canSave = false
                pendingEntry = nil
                showingExactError = false
                let message = L10n.failure(failure, language: settings.language)
                statusText = message
                if settings.assistantSpeech {
                    speak(message, languageCode: settings.language.speechLocale, kind: .other) { }
                }
                return
            }
        }
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
        settleItem?.cancel()
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
        let cue = settings.startCue
        if cue.playsVibration {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if cue.playsBeep {
            beep.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: fire)
        } else {
            fire()
        }
    }

    private func startRecognition() {
        guard let settings, !exited, !isPaused else { return }
        beep.stop()
        continuationBase = runningTotal
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
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
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
        // Keep transcript across Pause/Resume and across the next listen.
        // New partials replace it; only Cancel clears it.
        transcriptReadyForEval = false
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
            let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                transcript = result.bestTranscription.formattedString
                if handleCommandIfPresent(transcript) {
                    return
                }
                transcriptReadyForEval = true
                scheduleSettle()
            }
            if result.isFinal {
                finishUtterance(endOfTask: true)
                return
            }
        }
        if error != nil {
            finishUtterance(endOfTask: true)
        }
    }

    /// Partial results often never become `isFinal` (for example "2x5"), so a short pause commits them.
    private func scheduleSettle(force: Bool = false) {
        settleItem?.cancel()
        let generation = self.generation
        let callbackID = self.callbackID
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == generation, self.callbackID == callbackID, !self.exited, !self.isPaused else { return }
            self.finishUtterance(endOfTask: force)
        }
        settleItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func finishUtterance(endOfTask: Bool) {
        guard acceptingResults else { return }
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only a transcript produced by this listening turn. The previous command is kept on screen
        // and must not be cleared or spoken again when the next session errors before any new words.
        if transcriptReadyForEval, handleCommandIfPresent(spoken) {
            return
        }
        let shouldInterpret = transcriptReadyForEval && !spoken.isEmpty
        if shouldInterpret && !endOfTask {
            if case .notUnderstood = SpeechMathParser.interpret(spoken, continuingFrom: continuationBase) {
                // Still listening; an incomplete phrase like "2x" gets one more second before the error phrase.
                scheduleSettle(force: true)
                return
            }
        }
        acceptingResults = false
        settleItem?.cancel()
        stopEngine()
        if shouldInterpret {
            interpretFinalTranscript()
        } else {
            scheduleListenAgain(after: 0.5)
        }
    }

    private func interpretFinalTranscript() {
        guard let settings else { return }
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if spoken.isEmpty {
            scheduleListenAgain(after: 0.4)
            return
        }
        if handleCommandIfPresent(spoken) {
            return
        }
        switch SpeechMathParser.interpret(spoken, continuingFrom: continuationBase) {
        case let .success(expression, value):
            commitSuccess(expression: expression, value: value, spoken: spoken)
            let formatted = ExpressionEvaluator.format(value)
            let sentence: String
            let languageCode: String
            if settings.verboseMemorySpeech {
                sentence = ArabicEquationSpeech.sentence(expression: expression, result: value)
                languageCode = "ar-SA"
            } else {
                sentence = L10n.text("voice.resultSpoken", language: settings.language)
                    .replacingOccurrences(of: "%@", with: formatted)
                languageCode = settings.language.speechLocale
            }
            statusText = sentence
            if settings.assistantSpeech {
                speak(sentence, languageCode: languageCode, kind: .other) { [weak self] in
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

    private func presentNotUnderstood(resumeListening: Bool = true) {
        stopEngine()
        showingExactError = true
        canSave = false
        pendingEntry = nil
        guard let settings else { return }
        let resume = { [weak self] in
            guard let self, resumeListening else { return }
            self.scheduleListenAgain(after: 3)
        }
        if settings.assistantSpeech {
            speak(AppPhrases.notUnderstood, languageCode: "ar-SA", kind: .exactError, then: resume)
        } else {
            resume()
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
        SpeechAudioRouter.activateSpeakerPlayback()
        let utterance = AVSpeechUtterance(string: text)
        if kind == .exactError {
            utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA") ?? AVSpeechSynthesisVoice(language: "ar")
        } else if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }
        let rate = settings?.speechRate ?? AppSettings.defaultSpeechRate
        utterance.rate = SpeechAudioRouter.clampedRate(rate)
        synthesizer.speak(utterance)
        let safeRate = max(Double(utterance.rate), 0.05)
        let estimated = Double(text.count) / (safeRate * 12.0) + 1.5
        let fallback = max(kind == .exactError ? 9.0 : 6.0, estimated)
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

    private func loadRunningTotal() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.runningTotalKey) != nil {
            runningTotal = defaults.double(forKey: Self.runningTotalKey)
        } else {
            runningTotal = 0
        }
        continuationBase = runningTotal
        let formatted = ExpressionEvaluator.format(runningTotal)
        if formatted != "0" {
            resultText = formatted
        }
    }

    private func commitSuccess(expression: String, value: Double, spoken: String) {
        let formatted = ExpressionEvaluator.format(value)
        expressionText = expression
        resultText = formatted
        canSave = true
        pendingEntry = HistoryEntry(id: UUID(), expression: expression, result: formatted, createdAt: Date())
        if !spoken.isEmpty {
            evaluatedTranscript = spoken
        }
        runningTotal = value
        UserDefaults.standard.set(value, forKey: Self.runningTotalKey)
        showingExactError = false
    }

    /// حذف / تصفير clear the running total. إيقاف / خروج close the assistant the same way as Exit.
    private func handleCommandIfPresent(_ spoken: String) -> Bool {
        guard let command = AssistantVoiceCommand.recognize(spoken) else { return false }
        callbackID += 1
        acceptingResults = false
        settleItem?.cancel()
        retryItem?.cancel()
        stopEngine()
        switch command {
        case .clearMemory:
            clearRunningTotalAndSpeak()
        case .close:
            guard !didRequestClose else { return true }
            didRequestClose = true
            shutdown()
            onRequestClose?()
        }
        return true
    }

    private func clearRunningTotalAndSpeak() {
        runningTotal = 0
        continuationBase = 0
        UserDefaults.standard.set(0.0, forKey: Self.runningTotalKey)
        expressionText = ""
        resultText = "0"
        canSave = false
        pendingEntry = nil
        evaluatedTranscript = nil
        showingExactError = false
        guard let settings else { return }
        statusText = AppPhrases.memoryCleared
        if settings.assistantSpeech {
            speak(AppPhrases.memoryCleared, languageCode: "ar-SA", kind: .other) { [weak self] in
                self?.scheduleListenAgain(after: 0.4)
            }
        } else {
            scheduleListenAgain(after: 0.8)
        }
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

private enum AssistantVoiceCommand {
    case clearMemory
    case close

    static func recognize(_ spoken: String) -> AssistantVoiceCommand? {
        switch SpeechMathParser.commandKey(spoken) {
        case "حذف", "تصفير":
            return .clearMemory
        case "ايقاف", "خروج":
            return .close
        default:
            return nil
        }
    }
}

private final class SpeechCaptureSession {
    let engine = AVAudioEngine()
    var request: SFSpeechAudioBufferRecognitionRequest?
    var task: SFSpeechRecognitionTask?
    var tapInstalled = false
}
