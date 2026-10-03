import AVFoundation
import Combine

final class ButtonSpeaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, languageCode: String, enabled: Bool) {
        guard enabled else { return }
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: spoken)
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}
