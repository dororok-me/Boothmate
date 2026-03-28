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
        @Published var glossaryEnabled: Bool = true
        @Published var glossaryColor: GlossaryColor = .orange

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
            ("KR", "ko-KR"),
            ("EN", "en-US"),
            ("JP", "ja-JP"),
            ("CN", "zh-CN")
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
        guard glossaryEnabled else { return text }
        guard let glossaryStore = glossaryStore else { return text }

            var output = text

            // 1단계: 긴 구문부터 먼저 매칭 (여러 단어 구문 우선)
            let sortedEntries = glossaryStore.entries.sorted {
                $0.source.count > $1.source.count
            }

            for entry in sortedEntries {
                let source = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
                let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty, !target.isEmpty else { continue }

                let annotatedST = "\(source)(\(target))"
                let annotatedTS = "\(target)(\(source))"

                // 이미 주석 붙어있으면 건너뛰기
                if output.localizedCaseInsensitiveContains(annotatedST) ||
                   output.localizedCaseInsensitiveContains(annotatedTS) { continue }

                // 여러 단어 구문인 경우: 문자열 전체에서 매칭
                if source.contains(" ") {
                    if output.localizedCaseInsensitiveContains(source) {
                        output = output.replacingOccurrences(
                            of: source,
                            with: annotatedST,
                            options: .caseInsensitive
                        )
                    }
                    else if output.localizedCaseInsensitiveContains(target) {
                        output = output.replacingOccurrences(
                            of: target,
                            with: annotatedTS,
                            options: .caseInsensitive
                        )
                    }
                }
            }

            // 2단계: 단일 단어 매칭
            let words = output.components(separatedBy: " ")
            var result: [String] = []

            for word in words {
                // 이미 구문 매칭으로 주석이 붙었으면 건너뛰기
                if word.contains("(") && word.contains(")") {
                    result.append(word)
                    continue
                }

                let leading = String(word.prefix(while: { $0.isPunctuation || $0.isWhitespace }))
                let trailing = String(word.reversed().prefix(while: { $0.isPunctuation || $0.isWhitespace }).reversed())
                let startIndex = word.index(word.startIndex, offsetBy: leading.count)
                let endIndex = word.index(word.endIndex, offsetBy: -trailing.count)
                let clean = startIndex < endIndex ? String(word[startIndex..<endIndex]) : word

                var matched = false

                for entry in sortedEntries {
                    let source = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
                    let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !source.isEmpty, !target.isEmpty else { continue }
                    guard !source.contains(" ") else { continue } // 구문은 1단계에서 처리 완료

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

        enum GlossaryColor: String, CaseIterable, Identifiable {
            case orange = "Orange"
            case blue = "Blue"
            case green = "Green"
            case red = "Red"
            case purple = "Purple"

            var id: String { rawValue }

            var label: String {
                switch self {
                case .orange: return "주황"
                case .blue: return "파랑"
                case .green: return "초록"
                case .red: return "빨강"
                case .purple: return "보라"
                }
            }

            var color: Color {
                switch self {
                case .orange: return .orange
                case .blue: return .blue
                case .green: return .green
                case .red: return .red
                case .purple: return .purple
                }
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
