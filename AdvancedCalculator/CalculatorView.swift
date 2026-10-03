import SwiftUI

struct CalculatorView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: HistoryStore
    @StateObject private var model = CalculatorViewModel()
    @StateObject private var speaker = ButtonSpeaker()
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showVoice = false

    @ScaledMetric(relativeTo: .largeTitle) private var resultSize = 48

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    if proxy.size.width > 760 {
                        HStack(alignment: .top, spacing: 20) {
                            displayColumn
                            KeypadView(model: model, speaker: speaker)
                        }
                    } else {
                        VStack(spacing: 14) {
                            displayColumn
                            KeypadView(model: model, speaker: speaker)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.05, green: 0.055, blue: 0.07).ignoresSafeArea())
            .navigationTitle(L10n.text("app.title", language: settings.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    historyButton
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    voiceButton
                    settingsButton
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView { entry in
                model.useHistory(entry)
                showHistory = false
            }
            .environmentObject(settings)
            .environmentObject(history)
            .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
        }
        .fullScreenCover(isPresented: $showVoice) {
            VoiceAssistantView()
                .environmentObject(settings)
                .environmentObject(history)
                .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
        }
        .onAppear { model.attach(history) }
    }

    private var displayColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            display
            clearHistoryButton
        }
    }

    private var display: some View {
        let expression = pretty(model.expression)
        let failureText = model.failure.map { L10n.failure($0, language: settings.language) }
        return VStack(alignment: .trailing, spacing: 6) {
            Text(expression)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel(L10n.text("display.expression", language: settings.language))
                .accessibilityValue(expression)
            Text(model.resultText.isEmpty ? " " : model.resultText)
                .font(.system(size: resultSize, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel(L10n.text("display.result", language: settings.language))
                .accessibilityValue(model.resultText)
            if let failureText {
                Text(failureText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.40))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(failureText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .bottom)
        .background(Color(red: 0.09, green: 0.10, blue: 0.13), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var clearHistoryButton: some View {
        Button(role: .destructive) {
            history.clearAll()
        } label: {
            Label(L10n.text("history.clear", language: settings.language), systemImage: "trash")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(Color(red: 0.95, green: 0.33, blue: 0.28))
        .accessibilityLabel(L10n.text("history.clear", language: settings.language))
        .accessibilityHint(L10n.text("history.clear.hint", language: settings.language))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("clearHistory")
    }

    private var historyButton: some View {
        Button {
            showHistory = true
        } label: {
            Label(L10n.text("nav.history", language: settings.language), systemImage: "clock.arrow.circlepath")
        }
        .accessibilityLabel(L10n.text("nav.history", language: settings.language))
        .accessibilityHint(L10n.text("nav.history.hint", language: settings.language))
        .accessibilityAddTraits(.isButton)
    }

    private var voiceButton: some View {
        Button {
            showVoice = true
        } label: {
            Image(systemName: "mic.fill")
        }
        .accessibilityLabel(L10n.text("nav.voice", language: settings.language))
        .accessibilityHint(L10n.text("nav.voice.hint", language: settings.language))
        .accessibilityAddTraits(.isButton)
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
        }
        .accessibilityLabel(L10n.text("nav.settings", language: settings.language))
        .accessibilityHint(L10n.text("nav.settings.hint", language: settings.language))
        .accessibilityAddTraits(.isButton)
    }

    private func pretty(_ raw: String) -> String {
        var text = raw
        let pairs = [("nroot(", "ⁿ√("), ("sqrt(", "√("), ("cbrt(", "∛("), ("*", "×"), ("/", "÷")]
        for (from, to) in pairs {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text
    }
}
