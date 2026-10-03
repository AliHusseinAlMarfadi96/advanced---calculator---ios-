import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.dismiss) private var dismiss
    var onSelect: (HistoryEntry) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if history.entries.isEmpty {
                    Text(L10n.text("history.empty", language: settings.language))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(L10n.text("history.empty", language: settings.language))
                } else {
                    List(history.entries) { entry in
                        Button {
                            onSelect(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.expression)
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .environment(\.layoutDirection, .leftToRight)
                                Text(entry.result)
                                    .font(.title3.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.primary)
                                    .environment(\.layoutDirection, .leftToRight)
                                Text(dateText(entry.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel("\(entry.expression), \(entry.result)")
                        .accessibilityHint(L10n.text("history.reuse.hint", language: settings.language))
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .navigationTitle(L10n.text("history.title", language: settings.language))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("history.close", language: settings.language)) {
                        dismiss()
                    }
                    .accessibilityLabel(L10n.text("history.close", language: settings.language))
                    .accessibilityAddTraits(.isButton)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        history.clearAll()
                    } label: {
                        Text(L10n.text("history.clear", language: settings.language))
                    }
                    .accessibilityLabel(L10n.text("history.clear", language: settings.language))
                    .accessibilityHint(L10n.text("history.clear.hint", language: settings.language))
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
