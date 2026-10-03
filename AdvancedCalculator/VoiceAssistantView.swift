import SwiftUI

struct VoiceAssistantView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VoiceAssistantViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("voice.title", language: settings.language))
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            if model.showingExactError {
                Text(verbatim: AppPhrases.notUnderstood)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text(verbatim: AppPhrases.notUnderstood))
            } else {
                Text(model.statusText)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(model.statusText)
            }

            if !model.transcript.isEmpty {
                Text(model.transcript)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("\(L10n.text("voice.youSaid", language: settings.language)) \(model.transcript)")
            }

            if !model.expressionText.isEmpty {
                Text(model.expressionText)
                    .font(.title3.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityLabel(L10n.text("display.expression", language: settings.language))
                    .accessibilityValue(model.expressionText)
            }

            if !model.resultText.isEmpty {
                Text(model.resultText)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityLabel(L10n.text("display.result", language: settings.language))
                    .accessibilityValue(model.resultText)
            }

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                controlButton(
                    title: L10n.text("voice.cancel", language: settings.language),
                    hint: L10n.text("voice.cancel.hint", language: settings.language),
                    systemImage: "xmark.circle.fill",
                    role: .cancel
                ) {
                    model.cancelTapped()
                }
                controlButton(
                    title: L10n.text(model.isPaused ? "voice.resume" : "voice.pause", language: settings.language),
                    hint: L10n.text(model.isPaused ? "voice.resume.hint" : "voice.pause.hint", language: settings.language),
                    systemImage: model.isPaused ? "play.circle.fill" : "pause.circle.fill",
                    role: nil
                ) {
                    model.pauseTapped()
                }
                controlButton(
                    title: L10n.text("voice.save", language: settings.language),
                    hint: L10n.text("voice.save.hint", language: settings.language),
                    systemImage: "square.and.arrow.down.fill",
                    role: nil
                ) {
                    model.saveTapped()
                }
                controlButton(
                    title: L10n.text("voice.exit", language: settings.language),
                    hint: L10n.text("voice.exit.hint", language: settings.language),
                    systemImage: "rectangle.portrait.and.arrow.right",
                    role: nil
                ) {
                    model.shutdown()
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.05, green: 0.055, blue: 0.07).ignoresSafeArea())
        .foregroundStyle(.white)
        .onAppear {
            model.onRequestClose = { dismiss() }
            model.start(settings: settings, history: history)
        }
        .onDisappear { model.shutdown() }
    }

    private func controlButton(
        title: String,
        hint: String,
        systemImage: String,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.13, green: 0.28, blue: 0.42))
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
}
