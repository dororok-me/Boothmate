import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

@MainActor
class SpeechManager: ObservableObject {
    @Published var subtitles: [String] = []
        var allSubtitles: [String] = []
        @Published var currentText: String = ""
        @Published var isRecording: Bool = false
        @Published var selectedLanguage: String = "en-US"
        @Published var fontSize: CGFloat = 22
        @Published var selectedTheme: SubtitleTheme = .normal
        @Published var elapsedSeconds: Int = 0

        weak var glossaryStore: GlossaryStore?

        private let maxDisplayLines = 10
        private let fontSizes: [CGFloat] = [16, 22, 28, 36]
        private var fontSizeIndex: Int = 1
        private var timer: Timer?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    let languages = [
        ("English", "en-US"),
        ("한국어", "ko-KR")
    ]

    func cycleFontSize() {
        fontSizeIndex = (fontSizeIndex + 1) % fontSizes.count
        fontSize = fontSizes[fontSizeIndex]
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status != .authorized {
                    print("음성 인식 권한이 허용되지 않았습니다.")
                }
            }
        }

        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                if !granted {
                    print("마이크 권한이 허용되지 않았습니다.")
                }
            }
        }
    }

    func startRecording() {
        stopRecording()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("현재 선택된 언어의 음성 인식을 사용할 수 없습니다.")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .record,
                mode: .measurement,
                options: [.duckOthers, .allowBluetooth]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            if let preferredInput = audioSession.availableInputs?.first(where: { $0.portType == .usbAudio }) {
                try audioSession.setPreferredInput(preferredInput)
            }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
                        try audioEngine.start()
                        isRecording = true
            // 타이머 시작
            // 타이머 시작
                        elapsedSeconds = 0
                        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                            Task { @MainActor in
                                self?.elapsedSeconds += 1
                            }
                        }
                        RunLoop.main.add(newTimer, forMode: .common)
                        timer = newTimer

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let result = result {
                        let rawText = result.bestTranscription.formattedString
                        self.currentText = self.applyGlossary(to: rawText)

                        if result.isFinal {
                            if !self.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                self.allSubtitles.append(self.currentText)
                                self.subtitles.append(self.currentText)
                                if self.subtitles.count > self.maxDisplayLines {
                                    self.subtitles.removeFirst(self.subtitles.count - self.maxDisplayLines)
                                }
                            }
                            self.currentText = ""
                        }
                    }

                    if let error = error {
                        print("음성 인식 오류: \(error.localizedDescription)")
                        if self.isRecording {
                            self.restartRecording()
                        }
                    }
                }
            }
        } catch {
            print("녹음 시작 오류: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        timer?.invalidate()
                timer = nil

        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            allSubtitles.append(currentText)
            subtitles.append(currentText)
            if subtitles.count > maxDisplayLines {
                subtitles.removeFirst(subtitles.count - maxDisplayLines)
            }
        }
        currentText = ""
    }

    private func restartRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if self.isRecording {
                self.startRecording()
            }
        }
    }

    func clearSubtitles() {
        subtitles.removeAll()
        allSubtitles.removeAll()
        currentText = ""
    }

    func exportAllSubtitles() -> String {
        return allSubtitles.joined(separator: "\n")
    }

    private func applyGlossary(to text: String) -> String {
        guard let glossaryStore = glossaryStore else { return text }
        guard !glossaryStore.entries.isEmpty else { return text }

        let words = text.components(separatedBy: " ")
        var result: [String] = []

        for word in words {
            let leading = String(word.prefix(while: { $0.isPunctuation || $0.isWhitespace }))
            let trailing = String(word.reversed().prefix(while: { $0.isPunctuation || $0.isWhitespace }).reversed())
            let startIndex = word.index(word.startIndex, offsetBy: leading.count)
            let endIndex = word.index(word.endIndex, offsetBy: -trailing.count)
            let clean = startIndex < endIndex ? String(word[startIndex..<endIndex]) : word

            var matched = false

            for entry in glossaryStore.entries {
                let source = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
                let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty, !target.isEmpty else { continue }

                if clean.localizedCaseInsensitiveCompare(source) == .orderedSame {
                    result.append("\(leading)\(clean)(\(target))\(trailing)")
                    matched = true
                    break
                }
                else if clean.localizedCaseInsensitiveCompare(target) == .orderedSame {
                    result.append("\(leading)\(clean)(\(source))\(trailing)")
                    matched = true
                    break
                }
            }

            if !matched {
                result.append(word)
            }
        }

        return result.joined(separator: " ")
    }
}

enum SubtitleTheme: String, CaseIterable, Identifiable {
    case normal = "Normal View"
    case night = "Night View"
    case legal = "Legal Pad"

    var id: String { rawValue }

    var backgroundColor: Color {
        switch self {
        case .normal: return .white
        case .night: return .black
        case .legal: return Color(red: 1.0, green: 1.0, blue: 0.8)
        }
    }

    var textColor: Color {
        switch self {
        case .normal: return .black
        case .night: return .white
        case .legal: return Color(red: 0.0, green: 0.0, blue: 0.5)
        }
    }

    var iconColor: Color {
        switch self {
        case .normal: return .black
        case .night: return .white
        case .legal: return Color(red: 0.0, green: 0.0, blue: 0.5)
        }
    }

    var lineColor: Color {
        Color.red.opacity(0.3)
    }
}
