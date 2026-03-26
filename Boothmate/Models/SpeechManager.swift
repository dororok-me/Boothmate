import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

@MainActor
class SpeechManager: ObservableObject {
    @Published var subtitles: [String] = []
    @Published var currentText: String = ""
    @Published var isRecording: Bool = false
    @Published var selectedLanguage: String = "en-US"
    @Published var fontSize: CGFloat = 20.0
    @Published var selectedTheme: SubtitleTheme = .normal

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    let languages = [
        ("English", "en-US"),
        ("한국어", "ko-KR")
    ]

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status != .authorized {
                    print("음성인식 권한이 거부되었습니다")
                }
            }
        }

        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                if !granted {
                    print("마이크 권한이 거부되었습니다")
                }
            }
        }
    }

    func startRecording() {
        stopRecording()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("음성인식을 사용할 수 없습니다")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                        
            // USB-C 외장 마이크 우선 사용
            if let preferredInput = audioSession.availableInputs?.first(where: { $0.portType == .usbAudio }) {
            try audioSession.setPreferredInput(preferredInput)
                        }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

            guard let recognitionRequest = recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let result = result {
                        self.currentText = result.bestTranscription.formattedString

                        if result.isFinal {
                            if !self.currentText.isEmpty {
                                self.subtitles.append(self.currentText)
                            }
                            self.currentText = ""
                            if self.isRecording {
                                self.restartRecording()
                            }
                        }
                    }

                    if let error = error {
                        print("인식 에러: \(error.localizedDescription)")
                        if self.isRecording {
                            self.restartRecording()
                        }
                    }
                }
            }
        } catch {
            print("오디오 엔진 에러: \(error.localizedDescription)")
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

        if !currentText.isEmpty {
            subtitles.append(currentText)
            currentText = ""
        }
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
        currentText = ""
    }
}

// MARK: - 테마 열거형 추가 (가장 하단에 작성)
// SpeechManager.swift 파일 하단의 SubtitleTheme 열거형 수정

enum SubtitleTheme: String, CaseIterable, Identifiable {
    case normal = "Normal View"
    case night = "Night View"
    case legal = "Legal Pad"
    
    var id: String { self.rawValue }
    
    // 테마별 배경색 (동일)
    var backgroundColor: Color {
        switch self {
        case .normal: return Color.white
        case .night: return Color.black
        case .legal: return Color(red: 1.0, green: 1.0, blue: 0.8)
        }
    }
    
    // 테마별 텍스트 색상 (동일)
    var textColor: Color {
        switch self {
        case .normal: return Color.black
        case .night: return Color.white
        case .legal: return Color(red: 0.0, green: 0.0, blue: 0.5)
        }
    }

    // 🌟 테마별 아이콘(톱니바퀴 등) 색상 추가
    var iconColor: Color {
        switch self {
        case .normal: return Color.black    // 일반: 검은색
        case .night: return Color.white     // 나이트: 흰색
        case .legal: return Color(red: 0.0, green: 0.0, blue: 0.5) // 리걸패드: 남색 (텍스트와 동일)
        }
    }
    
    // 리걸 패드용 줄무늬 색상 (동일)
    var lineColor: Color {
        return Color.red.opacity(0.3)
    }
}
