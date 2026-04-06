import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

@MainActor
class SpeechManager: ObservableObject {

    // MARK: - Published Properties

    @Published var subtitles: [String] = []
    @Published var currentText: String = ""
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var selectedLanguage: String = "en-US"
    @Published var fontSize: CGFloat = 22
    @Published var lineSpacing: CGFloat = 8
    @Published var selectedTheme: SubtitleTheme = .normal
    @Published var elapsedSeconds: Int = 0
    @Published var glossaryEnabled: Bool = true
    @Published var glossaryColor: GlossaryColor = .orange
    @Published var unitConversionEnabled: Bool = true
    @Published var selectedBooth: BoothMode = .kr

    @Published var scrollTrigger: Int = 0

    // MARK: - Storage

    var allSubtitles: [String] = []
    weak var glossaryStore: GlossaryStore?
    var currencyConverter: CurrencyConverter?

    // MARK: - Azure STT
    @AppStorage("useAzure") var useAzure: Bool = false
    @AppStorage("azureApiKey") var azureApiKey: String = ""
    @AppStorage("azureRegion") var azureRegion: String = "koreacentral"
    private let azureSpeechManager = AzureSpeechManager()

    // MARK: - Private Properties

    private let maxDisplayLines = 5
    private let fontSizes: [CGFloat] = [16, 22, 28, 36]
    private var fontSizeIndex: Int = 1
    private var timer: Timer?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // currentText throttle
    private var lastUpdateTime: Date = .distantPast

    // Apple Speech 10분 리셋용
    private var sessionSeconds: Int = 0
    private var isRestarting = false
    private let sessionLimit = 600  // 10분

    // MARK: - Languages

    var languages: [(String, String)] {
        switch selectedBooth {
        case .kr: return [("KR", "ko-KR"), ("EN", "en-US")]
        case .cn: return [("KR", "ko-KR"), ("CN", "zh-CN")]
        case .jp: return [("KR", "ko-KR"), ("JP", "ja-JP")]
        }
    }

    // MARK: - Font Size

    func cycleFontSize() {
        fontSizeIndex = (fontSizeIndex + 1) % fontSizes.count
        fontSize = fontSizes[fontSizeIndex]
    }

    // MARK: - Permissions

    func requestPermissions() {
        Task {
            SFSpeechRecognizer.requestAuthorization { _ in }
            AVAudioApplication.requestRecordPermission { _ in }
        }
    }

    // MARK: - Conversions

    private func applyConversions(to text: String) -> String {
        var displayed = text
        if unitConversionEnabled {
            if let converter = currencyConverter {
                displayed = converter.applyConversion(to: displayed)
            }
            displayed = UnitConverter.applyConversion(to: displayed)
        }
        return displayed
    }

    // MARK: - 실시간 자막 업데이트 (throttle + 글로서리)

    private func updateCurrentText(_ rawText: String) {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) > 0.1 else { return }
        lastUpdateTime = now

        var displayed = applyGlossary(to: rawText)
        displayed = applyConversions(to: displayed)

        self.currentText = displayed
        self.scrollTrigger += 1
    }

    // MARK: - 확정 자막 처리

    private func processFinalText(_ rawText: String) {
        var processed = applyGlossary(to: rawText)
        processed = applyConversions(to: processed)
        self.currentText = processed

        if !self.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.allSubtitles.append(self.currentText)
            self.subtitles.append(self.currentText)
            if self.subtitles.count > self.maxDisplayLines {
                self.subtitles.removeFirst(self.subtitles.count - self.maxDisplayLines)
            }
        }
        self.currentText = ""
        self.scrollTrigger += 1
    }

    // MARK: - Azure Recording

    func startAzureRecording() {
        guard !azureApiKey.isEmpty else {
            print("Azure API 키가 없습니다")
            return
        }

        stopRecording()
        isRecording = true
        elapsedSeconds = 0

        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer

        azureSpeechManager.onRecognizing = { [weak self] text in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateCurrentText(text)
            }
        }

        azureSpeechManager.onRecognized = { [weak self] text in
            Task { @MainActor in
                guard let self = self else { return }
                self.processFinalText(text)
            }
        }

        azureSpeechManager.onError = { [weak self] error in
            Task { @MainActor in
                print("❌ \(error)")
                self?.stopRecording()
            }
        }

        azureSpeechManager.startRecording(
            apiKey: azureApiKey,
            region: azureRegion,
            language: selectedLanguage
        )
    }

    // MARK: - Start Recording (Apple Speech)

    func startRecording() {
        if useAzure {
            startAzureRecording()
            return
        }
        stopRecording()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("현재 선택된 언어의 음성 인식을 사용할 수 없습니다.")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
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

            elapsedSeconds = 0
            sessionSeconds = 0
            let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.elapsedSeconds += 1
                    self.sessionSeconds += 1
                    // Apple Speech 10분 리셋
                    if self.sessionSeconds >= self.sessionLimit
                        && self.isRecording && !self.isRestarting {
                        self.restartRecognition()
                    }
                }
            }
            RunLoop.main.add(newTimer, forMode: .common)
            timer = newTimer

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let result = result {
                        let rawText = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.processFinalText(rawText)
                        } else {
                            self.updateCurrentText(rawText)
                        }
                    }
                    if let error = error {
                        // 리스타트 중 에러는 무시
                        if !self.isRestarting {
                            print("음성 인식 오류: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            print("녹음 시작 오류: \(error.localizedDescription)")
        }
    }

    // MARK: - 10분 리셋 (매끄러운 전환)

    private func restartRecognition() {
        guard !isRestarting else { return }
        isRestarting = true

        // 현재 인식 세션 정리
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        // 현재 텍스트가 있으면 확정 처리
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            var processed = applyGlossary(to: trimmed)
            processed = applyConversions(to: processed)
            allSubtitles.append(processed)
            subtitles.append(processed)
            if subtitles.count > maxDisplayLines {
                subtitles.removeFirst(subtitles.count - maxDisplayLines)
            }
        }
        currentText = ""

        // 짧은 딜레이 후 재시작
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2초
            if self.isRecording {
                self.sessionSeconds = 0
                self.isRestarting = false
                self.startRecognitionOnly()
                print("🔄 음성인식 세션 리스타트 (\(self.elapsedSeconds)초)")
            } else {
                self.isRestarting = false
            }
        }
    }

    // MARK: - 리셋 시 인식만 재시작 (타이머/UI 유지)

    private func startRecognitionOnly() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
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

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let result = result {
                        let rawText = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.processFinalText(rawText)
                        } else {
                            self.updateCurrentText(rawText)
                        }
                    }
                    if let error = error {
                        if !self.isRestarting {
                            print("음성 인식 오류: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            print("리스타트 오류: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop Recording

    func stopRecording() {
        azureSpeechManager.stopRecording()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        isPaused = false
        isRestarting = false
        timer?.invalidate()
        timer = nil

        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            var processed = applyGlossary(to: currentText)
            processed = applyConversions(to: processed)
            allSubtitles.append(processed)
            subtitles.append(processed)
            if subtitles.count > maxDisplayLines {
                subtitles.removeFirst(subtitles.count - maxDisplayLines)
            }
        }
        currentText = ""
    }

    // MARK: - Subtitles Management

    func clearSubtitles() {
        subtitles.removeAll()
        allSubtitles.removeAll()
        currentText = ""
    }

    func exportAllSubtitles() -> String {
        return allSubtitles.joined(separator: "\n")
    }

    // MARK: - Glossary

    private func applyGlossary(to text: String) -> String {
        guard glossaryEnabled else { return text }
        guard let glossaryStore = glossaryStore else { return text }
        guard !glossaryStore.entries.isEmpty else { return text }

        var output = text
        let sortedEntries = glossaryStore.entries.sorted { $0.source.count > $1.source.count }

        // 1단계: 복합어(공백 포함) 먼저 처리
        for entry in sortedEntries {
            let source = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !target.isEmpty else { continue }

            let annotatedST = "\(source)(\(target))"
            let annotatedTS = "\(target)(\(source))"

            if output.localizedCaseInsensitiveContains(annotatedST) ||
               output.localizedCaseInsensitiveContains(annotatedTS) { continue }

            if source.contains(" ") {
                if output.localizedCaseInsensitiveContains(source) {
                    output = output.replacingOccurrences(of: source, with: annotatedST, options: .caseInsensitive)
                } else if output.localizedCaseInsensitiveContains(target) {
                    output = output.replacingOccurrences(of: target, with: annotatedTS, options: .caseInsensitive)
                }
            }
        }

        // 2단계: 단일 단어 처리
        let words = output.components(separatedBy: " ")
        var result: [String] = []

        for word in words {
            if word.contains("(") && word.contains(")") {
                result.append(word)
                continue
            }

            let leading = String(word.prefix(while: { $0.isPunctuation || $0.isWhitespace }))
            let trailing = String(word.reversed().prefix(while: { $0.isPunctuation || $0.isWhitespace }).reversed())
            let startIdx = word.index(word.startIndex, offsetBy: leading.count)
            let endIdx = word.index(word.endIndex, offsetBy: -trailing.count)
            let clean = startIdx < endIdx ? String(word[startIdx..<endIdx]) : word

            var matched = false
            for entry in sortedEntries {
                let source = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
                let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty, !target.isEmpty else { continue }
                guard !source.contains(" ") else { continue }

                if clean.localizedCaseInsensitiveCompare(source) == .orderedSame {
                    result.append("\(leading)\(clean)(\(target))\(trailing)")
                    matched = true
                    break
                } else if clean.localizedCaseInsensitiveCompare(target) == .orderedSame {
                    result.append("\(leading)\(clean)(\(source))\(trailing)")
                    matched = true
                    break
                }
            }
            if !matched { result.append(word) }
        }

        return result.joined(separator: " ")
    }
}

// MARK: - Glossary Color

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

// MARK: - Subtitle Theme

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
    var lineColor: Color { Color.red.opacity(0.3) }
}

// MARK: - Booth Mode

enum BoothMode: String, CaseIterable, Identifiable {
    case kr = "KR Booth"
    case cn = "CN Booth"
    case jp = "JP Booth"

    var id: String { rawValue }
    var shortLabel: String {
        switch self {
        case .kr: return "KR"
        case .cn: return "CN"
        case .jp: return "JP"
        }
    }
    var next: BoothMode {
        switch self {
        case .kr: return .cn
        case .cn: return .jp
        case .jp: return .kr
        }
    }
    var defaultLanguage: String {
        switch self {
        case .kr: return "en-US"
        case .cn: return "zh-CN"
        case .jp: return "ja-JP"
        }
    }
    func dictionaryType(for language: String) -> String {
        switch self {
        case .kr: return "eng"
        case .cn: return "ch"
        case .jp: return "jp"
        }
    }
}
