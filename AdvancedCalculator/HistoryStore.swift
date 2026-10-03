import Combine
import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var expression: String
    var result: String
    var createdAt: Date
}

final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    private let defaults: UserDefaults
    private let storageKey = "advancedCalculator.history.v1"
    private let limit = 100

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(expression: String, result: String) {
        let trimmedExpression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExpression.isEmpty, !trimmedResult.isEmpty else { return }
        if let first = entries.first, first.expression == trimmedExpression, first.result == trimmedResult {
            return
        }
        entries.insert(
            HistoryEntry(id: UUID(), expression: trimmedExpression, result: trimmedResult, createdAt: Date()),
            at: 0
        )
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        persist()
    }

    func clearAll() {
        entries = []
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
