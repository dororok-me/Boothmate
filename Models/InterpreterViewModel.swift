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

    // 자막
    @Published var segments: [Segment] = []
    @Published var liveSource = ""
    @Published var liveTranslation = ""

    // 실행 상태
    @Published var isRunning = false
    @Published var secondsLeft: Int?
    @Published var errorText: String?
    @Published var statusText = ""

    // 언어쌍 + 방향
    @Published var langA: InterpretLanguage = .ko
    @Published var langB: InterpretLanguage = .en
    @Published var dirMode: DirMode = .auto
    /// 현재 출력(번역) 언어 — auto에서 감지로 전환됨.
    @Published var curTarget: InterpretLanguage = .en

    private let audio = AudioCapture()
    private let relay = RelayClient()

    private var passKey = ""
    private var userStopped = false
    private var reconnectAttempts = 0

    init() {
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
        self.passKey = passKey

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self = self else { return }
                guard granted else { self.errorText = "마이크 권한이 필요합니다"; return }
                self.begin()
            }
        }
    }

    private func begin() {
        segments.removeAll()
        liveSource = ""
        liveTranslation = ""
        userStopped = false
        reconnectAttempts = 0
        curTarget = defaultTarget()
        connectRelay()
        do {
            try audio.start()
            isRunning = true
            statusText = "통역 중"
        } catch {
            errorText = "오디오 시작 실패: \(error.localizedDescription)"
            relay.disconnect()
        }
    }

    func stop() {
        userStopped = true
        audio.stop()
        relay.disconnect()
        isRunning = false
        statusText = ""
        flushLive()
    }

    // MARK: - 방향

    private func defaultTarget() -> InterpretLanguage {
        switch dirMode {
        case .bToA: return langA
        default:    return langB   // auto 기본 방향은 A→B
        }
    }

    /// auto 모드: 감지된 입력의 반대 언어가 현재 타겟과 다르면 전환+재연결.
    private func maybeFlipDirection(_ srcText: String) {
        guard dirMode == .auto, isRunning, !userStopped else { return }
        guard let det = LanguageDetector.detect(srcText, langA, langB) else { return }
        let desired = (det.prefix == langA.prefix) ? langB : langA
        if desired.prefix == curTarget.prefix { return }
        curTarget = desired
        statusText = "언어 방향 전환 중…"
        reconnectForFlip()
    }

    private func reconnectForFlip() {
        relay.disconnect()   // userClosed=true → 옛 소켓 onClose 억제
        connectRelay()
    }

    private func connectRelay() {
        relay.connect(passKey: passKey, setup: makeSetup())
    }

    // MARK: - setup 메시지

    private func makeSetup() -> [String: Any] {
        let target = curTarget
        let other = (target.prefix == langA.prefix) ? langB : langA

        var instruction =
            "You are a professional simultaneous interpreter between \(langA.englishName) and \(langB.englishName). " +
            "The expected input is \(other.englishName). Translate every input utterance into \(target.englishName). " +
            "Output ONLY \(target.englishName); never echo the input language. " +
            "LANGUAGE LOCK — this session handles ONLY \(langA.englishName) and \(langB.englishName). " +
            "If an utterance is spoken in any OTHER language, IGNORE it and output nothing. " +
            "CRITICAL — preserve every number's exact magnitude. Korean units: " +
            "만=10 thousand, 십만=100 thousand, 백만=1 million, 천만=10 million, 억=100 million, 십억=1 billion, 조=1 trillion " +
            "(e.g., 3천만 달러 → 30 million dollars, 2.2억 원 → 220 million won). Never change the order of magnitude. " +
            "Keep each number as one contiguous token."

        if dirMode != .auto {
            instruction +=
                " ONE-WAY MODE — translate ONLY \(other.englishName) speech into \(target.englishName). " +
                "If an utterance is already in \(target.englishName), stay silent and output nothing."
        }

        return [
            "model": AppConfig.geminiModel,
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "translationConfig": ["targetLanguageCode": target.geminiCode],
            ],
            "inputAudioTranscription": [:],
            "outputAudioTranscription": [:],
            "systemInstruction": ["parts": [["text": instruction]]],
        ]
    }

    // MARK: - 릴레이 콜백

    private func wireRelay() {
        relay.onSource = { [weak self] t in
            Task { @MainActor in
                guard let self = self else { return }
                self.reconnectAttempts = 0   // 실데이터 수신 = 정상 세션 → 재시도 카운터 리셋
                if self.isRunning { self.statusText = "통역 중" }
                self.liveSource += t
                self.maybeFlipDirection(self.liveSource)
            }
        }
        relay.onTranslation = { [weak self] t in
            Task { @MainActor in
                guard let self = self else { return }
                self.reconnectAttempts = 0
                self.liveTranslation += t
            }
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
        relay.onOpen = { [weak self] in
            // 열림만으로 카운터를 리셋하지 않는다(즉시 닫히는 무한 재연결 방지).
            // 리셋은 실제 데이터(onSource/onTranslation) 수신 시에만.
            Task { @MainActor in
                guard let self = self, self.isRunning else { return }
                self.statusText = "통역 중"
            }
        }
        relay.onClose = { [weak self] _ in
            Task { @MainActor in self?.handleUnexpectedClose() }
        }
    }

    /// 세션 만료(goAway)/네트워크 끊김 → 자동 재연결(백오프).
    private func handleUnexpectedClose() {
        guard isRunning, !userStopped else { return }
        reconnectAttempts += 1
        if reconnectAttempts > 6 {
            errorText = "연결에 실패했습니다. 통과키와 네트워크를 확인하고 다시 시작해 주세요."
            stop()
            return
        }
        statusText = "재연결 중… (\(reconnectAttempts))"
        let delay = min(Double(reconnectAttempts) * 0.5, 3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isRunning, !self.userStopped else { return }
            self.connectRelay()
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
