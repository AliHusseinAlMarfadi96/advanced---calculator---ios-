import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        languageButton(.en)
                        languageButton(.ar)
                    } header: {
                        Text(L10n.text("settings.language", language: settings.language))
                    } footer: {
                        Text(L10n.text("settings.language.hint", language: settings.language))
                    }

                    Section {
                        Toggle(isOn: $settings.keyboardSpeech) {
                            Text(L10n.text("settings.keyboardSpeech", language: settings.language))
                        }
                        .accessibilityHint(L10n.text("settings.keyboardSpeech.hint", language: settings.language))

                        Toggle(isOn: $settings.assistantSpeech) {
                            Text(L10n.text("settings.assistantSpeech", language: settings.language))
                        }
                        .accessibilityHint(L10n.text("settings.assistantSpeech.hint", language: settings.language))

                        Toggle(isOn: $settings.verboseMemorySpeech) {
                            Text(L10n.text("settings.verboseMemory", language: settings.language))
                        }
                        .accessibilityHint(L10n.text("settings.verboseMemory.hint", language: settings.language))

                        Picker(selection: $settings.startCue) {
                            ForEach(AssistantStartCue.allCases) { cue in
                                Text(L10n.text(cue.titleKey, language: settings.language)).tag(cue)
                            }
                        } label: {
                            Text(L10n.text("settings.startBeep", language: settings.language))
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint(L10n.text("settings.startBeep.hint", language: settings.language))

                        Toggle(isOn: $settings.speakResultAfterEquals) {
                            Text(L10n.text("settings.speakResult", language: settings.language))
                        }
                        .accessibilityHint(L10n.text("settings.speakResult.hint", language: settings.language))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text("settings.speechRate", language: settings.language))
                                .font(.body)
                                .accessibilityHidden(true)
                            Slider(
                                value: $settings.speechRate,
                                in: AppSettings.minimumSpeechRate...AppSettings.maximumSpeechRate
                            )
                            .accessibilityLabel(L10n.text("settings.speechRate", language: settings.language))
                            .accessibilityHint(L10n.text("settings.speechRate.hint", language: settings.language))
                        }
                        .accessibilityElement(children: .contain)
                    } header: {
                        Text(L10n.text("settings.section.speech", language: settings.language))
                    }
                }
                Text(verbatim: AppPhrases.credits)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .accessibilityLabel(Text(verbatim: AppPhrases.credits))
            }
            .navigationTitle(L10n.text("settings.title", language: settings.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("history.close", language: settings.language)) {
                        dismiss()
                    }
                    .accessibilityLabel(L10n.text("history.close", language: settings.language))
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        let selected = settings.language == language
        let titleKey = language == .en ? "language.english" : "language.arabic"
        let hintKey = language == .en ? "language.english.hint" : "language.arabic.hint"
        return Button {
            settings.language = language
        } label: {
            HStack {
                Text(L10n.text(titleKey, language: settings.language))
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel(L10n.text(titleKey, language: settings.language))
        .accessibilityHint(L10n.text(hintKey, language: settings.language))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
    }
}
