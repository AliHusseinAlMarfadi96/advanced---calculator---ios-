import AVFoundation
import Combine

/// Playback route used before every spoken utterance so audio leaves the loud speaker.
enum SpeechAudioRouter {
    /// Category `.playback` with `.defaultToSpeaker` (`.duckOthers` kept).
    /// Called at launch and again before each utterance because recognition switches
    /// the session to `.playAndRecord` / `.measurement`, which routes speech to the earpiece.
    static func activateSpeakerPlayback() {
        let session = AVAudioSession.sharedInstance()
        let attempts: [AVAudioSession.CategoryOptions] = [
            [.defaultToSpeaker, .duckOthers],
            [.defaultToSpeaker],
            [.duckOthers],
            []
        ]
        for options in attempts {
            do {
                try session.setCategory(.playback, mode: .default, options: options)
                try session.setActive(true)
                return
            } catch {
                continue
            }
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
