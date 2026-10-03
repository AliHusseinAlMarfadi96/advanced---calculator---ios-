import SwiftUI

struct RootView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var history = HistoryStore()

    var body: some View {
        CalculatorView()
            .environmentObject(settings)
            .environmentObject(history)
            .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
            .environment(\.locale, Locale(identifier: settings.language.localeIdentifier))
            .preferredColorScheme(.dark)
            .tint(Color(red: 1.0, green: 0.62, blue: 0.04))
            .onAppear { SpeechAudioRouter.activateSpeakerPlayback() }
    }
}
