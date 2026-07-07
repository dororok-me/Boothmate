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
                conversionSection
                aboutSection
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
        Section("Booth & Language") {
            Picker("Booth", selection: $speechManager.selectedBooth) {
                ForEach(BoothMode.allCases) { booth in
                    Text(booth.rawValue).tag(booth)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: speechManager.selectedBooth) { _, newBooth in
                speechManager.selectedLanguage = newBooth.defaultLanguage
            }
        }
    }

    private var fontSection: some View {
        Section("Font Size & Line Spacing") {
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(speechManager.fontSize))")
                    .foregroundColor(.secondary)
            }

            Slider(value: $speechManager.fontSize, in: 16...36, step: 1)

            HStack {
                Text("Line Spacing")
                Spacer()
                Text("\(Int(speechManager.lineSpacing))")
                    .foregroundColor(.secondary)
            }

            Slider(value: $speechManager.lineSpacing, in: 0...30, step: 2)

            HStack {
                Text("Font Weight")
                Spacer()
                Picker("", selection: $speechManager.fontBold) {
                    Text("Normal").tag(false)
                    Text("Bold").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Text("Preview Text\nSecond line here")
                .font(.system(size: speechManager.fontSize,
                              weight: speechManager.fontBold ? .bold : .regular))
                .lineSpacing(speechManager.lineSpacing)
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

    private var conversionSection: some View {
        Section("Conversion") {
            Toggle("실시간 환율·단위 변환", isOn: $speechManager.unitConversionEnabled)
        }
    }

    private var aboutSection: some View {
        Section {
            VStack(spacing: 4) {
                Text("Boothmate v1.0")
                    .font(.footnote.bold())
                    .foregroundColor(.secondary)
                Text("dororok AI Lab")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }
}
