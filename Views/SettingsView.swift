import SwiftUI

struct SettingsView: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                languageSection
                fontSection
                themeSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var languageSection: some View {
        Section("Language") {
            Picker("Recognition Language", selection: $speechManager.selectedLanguage) {
                ForEach(speechManager.languages, id: \.1) { language in
                    Text(language.0).tag(language.1)
                }
            }
            .pickerStyle(.inline)

            Text("Current: \(displayLanguageName(for: speechManager.selectedLanguage))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var fontSection: some View {
        Section("Font Size") {
            HStack {
                Text("Current Size")
                Spacer()
                Text("\(Int(speechManager.fontSize))")
                    .foregroundColor(.secondary)
            }

            Slider(value: $speechManager.fontSize, in: 16...36, step: 1)

            Button("Cycle Font Size") {
                speechManager.cycleFontSize()
            }

            Text("Preview Text")
                .font(.system(size: speechManager.fontSize))
                .padding(.vertical, 6)
        }
    }

    private var themeSection: some View {
        Section("Theme") {
            Picker("Subtitle Theme", selection: $speechManager.selectedTheme) {
                ForEach(SubtitleTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.inline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Preview")
                    .font(.headline)

                Text("This is a subtitle preview.")
                    .font(.system(size: speechManager.fontSize))
                    .foregroundColor(speechManager.selectedTheme.textColor)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(speechManager.selectedTheme.backgroundColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.vertical, 4)
        }
    }

    private func displayLanguageName(for code: String) -> String {
        switch code {
        case "en-US":
            return "English"
        case "ko-KR":
            return "한국어"
        default:
            return code
        }
    }
}
