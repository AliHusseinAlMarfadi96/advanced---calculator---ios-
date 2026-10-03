import AVFoundation
import Combine
import Foundation

/// How the voice assistant signals that it has started listening.
enum AssistantStartCue: String, CaseIterable, Identifiable {
    case beep
    case vibration
    case both

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .beep: return "settings.startCue.beep"
        case .vibration: return "settings.startCue.vibration"
        case .both: return "settings.startCue.both"
        }
    }

    var playsBeep: Bool { self == .beep || self == .both }
    var playsVibration: Bool { self == .vibration || self == .both }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ar

    var id: String { rawValue }
    var localeIdentifier: String { self == .ar ? "ar" : "en" }
    var speechLocale: String { self == .ar ? "ar-SA" : "en-US" }
    var isRTL: Bool { self == .ar }
}

final class AppSettings: ObservableObject {
    /// Inclusive slider range. These are the AVSpeechUtterance rate bounds (0...1),
    /// not a separate fraction that is scaled later.
    static let minimumSpeechRate = Double(AVSpeechUtteranceMinimumSpeechRate)
    static let maximumSpeechRate = Double(AVSpeechUtteranceMaximumSpeechRate)
    static let defaultSpeechRate = Double(AVSpeechUtteranceDefaultSpeechRate)

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }
    @Published var keyboardSpeech: Bool {
        didSet { defaults.set(keyboardSpeech, forKey: Key.keyboardSpeech) }
    }
    @Published var assistantSpeech: Bool {
        didSet { defaults.set(assistantSpeech, forKey: Key.assistantSpeech) }
    }
    /// Beep, vibration, or both when the assistant starts listening.
    /// Replaces the old boolean `advancedCalculator.startBeep`.
    @Published var startCue: AssistantStartCue {
        didSet { defaults.set(startCue.rawValue, forKey: Key.startCue) }
    }
    /// When true, a successful assistant result is spoken as a full Arabic equation
    /// (memory, operator, result) instead of the result alone. Default true.
    @Published var verboseMemorySpeech: Bool {
        didSet { defaults.set(verboseMemorySpeech, forKey: Key.verboseMemorySpeech) }
    }
    /// When true, pressing "=" speaks the calculated result. Default true.
    @Published var speakResultAfterEquals: Bool {
        didSet { defaults.set(speakResultAfterEquals, forKey: Key.speakResultAfterEquals) }
    }
    /// Stored AVSpeechUtterance rate (minimum...maximum, i.e. 0...1).
    /// UserDefaults key `advancedCalculator.speechRate` holds this rate directly,
    /// not a 0...1 fraction that still needs mapping.
    @Published var speechRate: Double {
        didSet { defaults.set(Self.clampSpeechRate(speechRate), forKey: Key.speechRate) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Key.language), let stored = AppLanguage(rawValue: raw) {
            language = stored
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            language = preferred.hasPrefix("ar") ? .ar : .en
        }
        keyboardSpeech = defaults.object(forKey: Key.keyboardSpeech) as? Bool ?? true
        assistantSpeech = defaults.object(forKey: Key.assistantSpeech) as? Bool ?? true
        startCue = Self.resolveStartCue(defaults)
        verboseMemorySpeech = defaults.object(forKey: Key.verboseMemorySpeech) as? Bool ?? true
        speakResultAfterEquals = defaults.object(forKey: Key.speakResultAfterEquals) as? Bool ?? true
        if defaults.object(forKey: Key.speechRate) != nil {
            speechRate = Self.clampSpeechRate(defaults.double(forKey: Key.speechRate))
        } else {
            speechRate = Self.defaultSpeechRate
        }
        if defaults.string(forKey: Key.startCue) == nil {
            defaults.set(startCue.rawValue, forKey: Key.startCue)
        }
    }

    static func clampSpeechRate(_ rate: Double) -> Double {
        min(max(rate, minimumSpeechRate), maximumSpeechRate)
    }

    /// New installs and anyone who previously left the beep on get beep and vibration.
    /// Users who had explicitly turned the beep off get vibration only, so the beep stays off.
    private static func resolveStartCue(_ defaults: UserDefaults) -> AssistantStartCue {
        if let raw = defaults.string(forKey: Key.startCue), let stored = AssistantStartCue(rawValue: raw) {
            return stored
        }
        if defaults.object(forKey: Key.legacyStartBeep) as? Bool == false {
            return .vibration
        }
        return .both
    }

    private enum Key {
        static let language = "advancedCalculator.language"
        static let keyboardSpeech = "advancedCalculator.keyboardSpeech"
        static let assistantSpeech = "advancedCalculator.assistantSpeech"
        static let startCue = "advancedCalculator.assistantStartCue"
        /// Read only to migrate the old on/off beep toggle. No longer written.
        static let legacyStartBeep = "advancedCalculator.startBeep"
        static let verboseMemorySpeech = "advancedCalculator.verboseMemorySpeech"
        static let speakResultAfterEquals = "advancedCalculator.speakResultAfterEquals"
        /// Double equal to the AVSpeechUtterance rate (min...max).
        static let speechRate = "advancedCalculator.speechRate"
    }
}
