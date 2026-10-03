import Foundation

enum L10n {
    static func text(_ key: String, language: AppLanguage) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func failure(_ failure: EvalFailure, language: AppLanguage) -> String {
        switch failure {
        case .divideByZero:
            return text("error.divideByZero", language: language)
        case .domain:
            return text("error.domain", language: language)
        case .syntax:
            return text("error.syntax", language: language)
        }
    }
}
