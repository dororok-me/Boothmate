import Foundation
import MicrosoftCognitiveServicesSpeech

class AzureSpeechManager {

    // MARK: - Properties

    private var speechRecognizer: SPXSpeechRecognizer?
    private var audioConfig: SPXAudioConfiguration?
    private var speechConfig: SPXSpeechConfiguration?

    var onRecognizing: ((String) -> Void)?   // 중간 결과 (실시간)
    var onRecognized: ((String) -> Void)?    // 확정 결과
    var onError: ((String) -> Void)?         // 에러
    var onStopped: (() -> Void)?             // 세션 종료

    private(set) var isRecording = false

    // MARK: - Start

    func startRecording(apiKey: String, region: String, language: String) {
        guard !isRecording else { return }

        do {
            speechConfig = try SPXSpeechConfiguration(subscription: apiKey, region: region)
            speechConfig?.speechRecognitionLanguage = language

            // 마이크 입력
            audioConfig = SPXAudioConfiguration()

            guard let config = speechConfig, let audio = audioConfig else {
                onError?("Azure 설정 실패")
                return
            }

            speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: audio)

            guard let recognizer = speechRecognizer else {
                onError?("Azure 인식기 생성 실패")
                return
            }

            // 중간 결과 (실시간 자막)
            recognizer.addRecognizingEventHandler { [weak self] _, event in
                let text = event.result.text ?? ""
                DispatchQueue.main.async {
                    self?.onRecognizing?(text)
                }
            }

            // 확정 결과
            recognizer.addRecognizedEventHandler { [weak self] _, event in
                let text = event.result.text ?? ""
                if !text.isEmpty {
                    DispatchQueue.main.async {
                        self?.onRecognized?(text)
                    }
                }
            }

            // 취소/에러
            recognizer.addCanceledEventHandler { [weak self] _, event in
                let details = event.errorDetails ?? "알 수 없는 오류"
                DispatchQueue.main.async {
                    self?.onError?("Azure 오류: \(details)")
                    self?.isRecording = false
                }
            }

            // 세션 종료
            recognizer.addSessionStoppedEventHandler { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.isRecording = false
                    self?.onStopped?()
                }
            }

            // 연속 인식 시작
            try recognizer.startContinuousRecognition()
            isRecording = true
            print("🎙️ Azure STT 시작 (\(language))")

        } catch {
            onError?("Azure 시작 오류: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop

    func stopRecording() {
        guard isRecording, let recognizer = speechRecognizer else { return }

        do {
            try recognizer.stopContinuousRecognition()
            print("🎙️ Azure STT 중지")
        } catch {
            print("Azure 중지 오류: \(error.localizedDescription)")
        }

        isRecording = false
        speechRecognizer = nil
        audioConfig = nil
        speechConfig = nil
    }
}
