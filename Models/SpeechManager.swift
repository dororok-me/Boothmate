import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

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

// MARK: - SpeechManager

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

    @AppStorage("fontBold") var fontBold: Bool = false
    @AppStorage("useAzure") var useAzure: Bool = false
    @AppStorage("azureApiKey") var azureApiKey: String = ""
    @AppStorage("azureRegion") var azureRegion: String = "koreacentral"
    
    // MARK: - Storage
    
    var allSubtitles: [String] = []
    weak var glossaryStore: GlossaryStore?
    var currencyConverter: CurrencyConverter?
    
    // MARK: - Private Properties
    
    private let maxDisplayLines = 5
    private let fontSizes: [CGFloat] = [16, 22, 28, 36]
    private var fontSizeIndex: Int = 1
    private var timer: Timer?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    private var lastUpdateTime: Date = .distantPast
    
    private var sessionSeconds: Int = 0
    private var isRestarting = false
    private let sessionLimit = 600
    
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
    
    private func updateCurrentText(_ rawText: String) {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) > 0.1 else { return }
        lastUpdateTime = now

        var displayed = applyGlossary(to: rawText)
        displayed = applyConversions(to: displayed)

        guard displayed != self.currentText else { return }
        self.currentText = displayed
        if !self.isPaused {
            self.scrollTrigger += 1
        }
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
        if !self.isPaused {
            self.scrollTrigger += 1
        }
    }
    
    // MARK: - Start Recording
    
    func startRecording() {
        isRecording = true

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                guard status == .authorized else {
                    Task { @MainActor in self?.isRecording = false }
                    return
                }
                Task { @MainActor in self?.requestMicAndBegin() }
            }
            return
        }
        requestMicAndBegin()
    }

    private func requestMicAndBegin() {
        let status = AVAudioApplication.shared.recordPermission
        if status == .granted {
            beginRecording()
        } else {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard granted else {
                    Task { @MainActor in self?.isRecording = false }
                    return
                }
                Task { @MainActor in self?.beginRecording() }
            }
        }
    }

    private func beginRecording() {
        // 엔진 완전 초기화
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine = AVAudioEngine()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            isRecording = false
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

            // 새 엔진의 inputNode에 tap 설치 (removeTap 불필요 — 새 엔진)
            let inputNode = audioEngine.inputNode
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
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
                    if let error = error, !self.isRestarting {
                        print("음성 인식 오류: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("녹음 시작 오류: \(error.localizedDescription)")
            isRecording = false
        }
    }
    
    // MARK: - 10분 리셋
    
    private func restartRecognition() {
        guard !isRestarting else { return }
        isRestarting = true
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        
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
        
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if self.isRecording {
                self.sessionSeconds = 0
                self.isRestarting = false
                self.startRecognitionOnly()
            } else {
                self.isRestarting = false
            }
        }
    }
    
    // MARK: - 리셋 시 인식만 재시작
    
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

            if audioEngine.isRunning { audioEngine.stop() }
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine = AVAudioEngine()

            let newInputNode = audioEngine.inputNode
            newInputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
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
                    if let error = error, !self.isRestarting {
                        print("음성 인식 오류: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("리스타트 오류: \(error.localizedDescription)")
            isRestarting = false
        }
    }
    
    // MARK: - Pause / Resume
    
    func pauseRecording() { isPaused = true }
    func resumeRecording() { isPaused = false }
    
    // MARK: - Stop Recording
    
    func stopRecording() {
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
    
    func exportAllSubtitles() -> String { allSubtitles.joined(separator: "\n") }

    func clearSubtitles() {
        subtitles.removeAll()
        allSubtitles.removeAll()
        currentText = ""
    }
    
    // MARK: - Glossary

    private func applyGlossary(to text: String) -> String {
        guard glossaryEnabled else { return text }
        guard let glossaryStore = glossaryStore else { return text }
        guard !glossaryStore.entries.isEmpty else { return text }

        var output = text
        let sortedEntries = glossaryStore.entries.sorted {
            max($0.source.count, $0.target.count) > max($1.source.count, $1.target.count)
        }

        for entry in sortedEntries {
            let source = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = entry.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !target.isEmpty else { continue }

            if output.localizedCaseInsensitiveContains("〔\(source)") ||
               output.localizedCaseInsensitiveContains("〔\(target)") { continue }

            let sourceNoSpace = source.replacingOccurrences(of: " ", with: "")
            let targetNoSpace = target.replacingOccurrences(of: " ", with: "")

            func findAndReplace(searchTerm: String, displayTerm: String, annotation: String) -> Bool {
                let searchNoSpace = searchTerm.replacingOccurrences(of: " ", with: "")
                if output.localizedCaseInsensitiveContains("〔\(displayTerm)") { return false }
                if output.localizedCaseInsensitiveContains(searchTerm) {
                    output = output.replacingOccurrences(of: searchTerm,
                        with: "〔\(displayTerm)(\(annotation))〕", options: .caseInsensitive)
                    return true
                }
                if searchNoSpace != searchTerm && output.localizedCaseInsensitiveContains(searchNoSpace) {
                    output = output.replacingOccurrences(of: searchNoSpace,
                        with: "〔\(displayTerm)(\(annotation))〕", options: .caseInsensitive)
                    return true
                }
                return false
            }

            if findAndReplace(searchTerm: source, displayTerm: source, annotation: target) { continue }
            if findAndReplace(searchTerm: target, displayTerm: target, annotation: source) { continue }
            if sourceNoSpace != source &&
               findAndReplace(searchTerm: sourceNoSpace, displayTerm: source, annotation: target) { continue }
            if targetNoSpace != target &&
               findAndReplace(searchTerm: targetNoSpace, displayTerm: target, annotation: source) { continue }

            for synonym in entry.synonyms {
                let syn = synonym.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !syn.isEmpty else { continue }
                if findAndReplace(searchTerm: syn, displayTerm: syn, annotation: source) { break }
            }
        }

        return output
    }
}
