import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var showGlossaryList = false
    @State private var showPaywall = false

    var body: some View {
        NavigationView {
            Form {
                languageSection
                fontSection
                themeSection
                glossarySection
                exportSection
                subscriptionSection
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
            .sheet(isPresented: $showGlossaryList) {
                if let store = speechManager.glossaryStore {
                    GlossaryView(glossaryStore: store)
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
                let boothLanguage: String
                switch newBooth {
                case .kr: boothLanguage = "en-US"
                case .cn: boothLanguage = "zh-CN"
                case .jp: boothLanguage = "ja-JP"
                }
                NotificationCenter.default.post(name: .boothChanged, object: boothLanguage)
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

    private var glossarySection: some View {
        Section("Glossary") {
            Toggle("Glossary On/Off", isOn: $speechManager.glossaryEnabled)
            Toggle("Unit Conversion On/Off", isOn: $speechManager.unitConversionEnabled)

            Button {
                showGlossaryList = true
            } label: {
                HStack {
                    Image(systemName: "text.book.closed")
                    Text("Edit Glossary")
                }
            }

            if speechManager.glossaryEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("괄호 안 단어 색상")
                        .font(.subheadline)

                    HStack(spacing: 12) {
                        ForEach(GlossaryColor.allCases) { color in
                            Button {
                                speechManager.glossaryColor = color
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 32, height: 32)

                                    if speechManager.glossaryColor == color {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2.5)
                                            .frame(width: 38, height: 38)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    Text("example(\(speechManager.glossaryColor.label))")
                        .font(.system(size: speechManager.fontSize, weight: .medium))
                        .foregroundColor(speechManager.glossaryColor.color)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var exportSection: some View {
        Section("Export Subtitles") {
            if subscriptionManager.isSubscribed {
                Button {
                    shareSubtitles()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Subtitles")
                    }
                }
                .disabled(speechManager.allSubtitles.isEmpty)

                Text("총 \(speechManager.allSubtitles.count)줄 저장됨")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("Only for subscribers")
                        .foregroundColor(.secondary)
                }

                Button {
                    showPaywall = true
                } label: {
                    Text("Upgrade to Pro")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    private var subscriptionSection: some View {
        Section("구독") {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Boothmate Pro 구독 관리")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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

    private func shareSubtitles() {
        let text = speechManager.exportAllSubtitles()
        guard !text.isEmpty else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("subtitles.txt")

        try? text.data(using: .utf8)?.write(to: fileURL)

        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
        }

        topVC.present(activityVC, animated: true)
    }

    private func displayLanguageName(for code: String) -> String {
        switch code {
        case "en-US": return "English"
        case "ko-KR": return "한국어"
        case "ja-JP": return "日本語"
        case "zh-CN": return "中文"
        default: return code
        }
    }
}
