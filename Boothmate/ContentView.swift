import SwiftUI
import Speech
import AVFoundation

// MARK: - 색상 정의

struct AppColors {
    static let boothKR = Color.blue
    static let boothCN = Color.red
    static let boothJP = Color.black
}

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var currencyConverter = CurrencyConverter()

    var body: some View {
        SubtitleScreen(speechManager: speechManager)
            .onAppear {
                speechManager.currencyConverter = currencyConverter
                DispatchQueue.global(qos: .utility).async {
                    SFSpeechRecognizer.requestAuthorization { _ in }
                    AVAudioApplication.requestRecordPermission { _ in }
                    Task { @MainActor in currencyConverter.fetchRates() }
                }
            }
    }
}

// MARK: - Glow Button Style

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.15) : Color.clear)
                    .blur(radius: configuration.isPressed ? 4 : 0)
            )
            .shadow(
                color: configuration.isPressed ? Color.blue.opacity(0.5) : Color.clear,
                radius: configuration.isPressed ? 8 : 0
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
