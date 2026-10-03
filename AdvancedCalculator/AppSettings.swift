import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ar

    var id: String { rawValue }
    var localeIdentifier: String { self == .ar ? "ar" : "en" }
    var speechLocale: String { self == .ar ? "ar-SA" : "en-US" }
    var isRTL: Bool { self == .ar }
}

final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }
    @Published var keyboardSpeech: Bool {
        didSet { defaults.set(keyboardSpeech, forKey: Key.keyboardSpeech) }
    }
    @Published var assistantSpeech: Bool {
        didSet { defaults.set(assistantSpeech, forKey: Key.assistantSpeech) }
    }
    @Published var startBeep: Bool {
        didSet { defaults.set(startBeep, forKey: Key.startBeep) }
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
        startBeep = defaults.object(forKey: Key.startBeep) as? Bool ?? true
    }

    private enum Key {
        static let language = "advancedCalculator.language"
        static let keyboardSpeech = "advancedCalculator.keyboardSpeech"
        static let assistantSpeech = "advancedCalculator.assistantSpeech"
        static let startBeep = "advancedCalculator.startBeep"
    }
}
