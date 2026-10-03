import AVFoundation
import Combine

/// Playback route used before every spoken utterance so audio leaves the loud speaker
/// without ducking VoiceOver. `.mixWithOthers` is required; do not use `.duckOthers`.
enum SpeechAudioRouter {
    /// Called at launch and again before each utterance because recognition switches
    /// the session to `.playAndRecord`, which would otherwise route speech to the earpiece.
    static func activateSpeakerPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
    }

    /// Clamps to `AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate`.
    static func clampedRate(_ rate: Double) -> Float {
        let minRate = Double(AVSpeechUtteranceMinimumSpeechRate)
        let maxRate = Double(AVSpeechUtteranceMaximumSpeechRate)
        return Float(min(max(rate, minRate), maxRate))
    }
}

final class ButtonSpeaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, languageCode: String, enabled: Bool, rate: Double) {
        guard enabled else { return }
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        SpeechAudioRouter.activateSpeakerPlayback()
        let utterance = AVSpeechUtterance(string: spoken)
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }
        utterance.rate = SpeechAudioRouter.clampedRate(rate)
        synthesizer.speak(utterance)
    }
}
