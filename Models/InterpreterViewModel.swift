import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class InterpreterViewModel: ObservableObject {

    struct Segment: Identifiable {
        let id = UUID()
        var source: String
        var translation: String
    }

    // 자막 상태
    @Published var segments: [Segment] = []
    @Published var liveSource = ""
    @Published var liveTranslation = ""

    // 실행 상태
    @Published var isRunning = false
    @Published var secondsLeft: Int?
    @Published var errorText: String?

    // 언어 선택
    @Published var sourceLang: InterpretLanguage = .ko
    @Published var targetLang: InterpretLanguage = .en

    private let audio = AudioCapture()
    private let relay = RelayClient()

    init() {
        // 오디오 스레드에서 relay로 직접 전송 (VM 상태 미접근)
        let relay = self.relay
        audio.onPCM16 = { data in
            relay.sendAudio(base64: data.base64EncodedString())
        }
        wireRelay()
    }

    // MARK: - 시작 / 정지

    func start(passKey: String) {
        errorText = nil
        guard !passKey.isEmpty else { errorText = "개발용 통과키를 입력하세요"; return }

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self = self else { return }
                guard granted else { self.errorText = "마이크 권한이 필요합니다"; return }
                self.begin(passKey: passKey)
            }
        }
    }

    private func begin(passKey: String) {
        segments.removeAll()
        liveSource = ""
        liveTranslation = ""
        relay.connect(passKey: passKey, setup: makeSetup())
        do {
            try audio.start()
            isRunning = true
        } catch {
            errorText = "오디오 시작 실패: \(error.localizedDescription)"
            relay.disconnect()
        }
    }

    func stop() {
        audio.stop()
        relay.disconnect()
        isRunning = false
        flushLive()
    }

    // MARK: - 내부

    private func makeSetup() -> [String: Any] {
        let instruction =
            "You are a professional simultaneous interpreter. " +
            "Translate every \(sourceLang.englishName) utterance into \(targetLang.englishName). " +
            "Output ONLY \(targetLang.englishName); never echo the input language. " +
            "CRITICAL — preserve every number's exact magnitude. Korean units: " +
            "만=10 thousand, 십만=100 thousand, 백만=1 million, 천만=10 million, " +
            "억=100 million, 십억=1 billion, 조=1 trillion. " +
            "Keep each number as one contiguous token."

        return [
            "model": AppConfig.geminiModel,
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "translationConfig": ["targetLanguageCode": targetLang.geminiCode],
            ],
            "inputAudioTranscription": [:],
            "outputAudioTranscription": [:],
            "systemInstruction": ["parts": [["text": instruction]]],
        ]
    }

    private func wireRelay() {
        relay.onSource = { [weak self] t in
            Task { @MainActor in self?.liveSource += t }
        }
        relay.onTranslation = { [weak self] t in
            Task { @MainActor in self?.liveTranslation += t }
        }
        relay.onTurnComplete = { [weak self] in
            Task { @MainActor in self?.flushLive() }
        }
        relay.onTime = { [weak self] s in
            Task { @MainActor in self?.secondsLeft = s }
        }
        relay.onTimeUp = { [weak self] in
            Task { @MainActor in
                self?.errorText = "구매한 통역 시간이 모두 소진되었습니다."
                self?.stop()
            }
        }
        relay.onClose = { [weak self] reason in
            Task { @MainActor in
                guard let self = self, self.isRunning else { return }
                self.errorText = "연결 종료: \(reason ?? "알 수 없음")"
                self.stop()
            }
        }
    }

    private func flushLive() {
        let s = liveSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = liveTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty || !t.isEmpty {
            segments.append(Segment(source: s, translation: t))
            if segments.count > 100 { segments.removeFirst(segments.count - 100) }
        }
        liveSource = ""
        liveTranslation = ""
    }
}
