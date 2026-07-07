import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class InterpreterViewModel: ObservableObject {

    // 누적 원문/번역 (표시 시 문장 단위로 나눠 쌍을 만든다)
    @Published var sourceText = ""
    @Published var translationText = ""

    // 실행 상태
    @Published var isRunning = false
    @Published var secondsLeft: Int?
    @Published var errorText: String?
    @Published var statusText = ""

    // 언어쌍 + 방향
    @Published var langA: InterpretLanguage = .ko
    @Published var langB: InterpretLanguage = .en
    @Published var dirMode: DirMode = .auto
    @Published var curTarget: InterpretLanguage = .en

    private let audio = AudioCapture()
    private let relay = RelayClient()

    // 자막 환율·도량형 변환 (결과 캐시 — 완료된 문장 재계산 방지)
    let currency = CurrencyConverter()
    private var convCache: [String: String] = [:]

    private var passKey = ""
    private var userStopped = false
    private var reconnectAttempts = 0

    /// 문장에 환율·도량형 환산값을 괄호로 병기 (캐시 사용).
    func converted(_ s: String) -> String {
        if let c = convCache[s] { return c }
        let out = UnitConverter.applyConversion(to: currency.applyConversion(to: s))
        if convCache.count > 400 { convCache.removeAll(keepingCapacity: true) }
        convCache[s] = out
        return out
    }

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
        sourceText = ""
        translationText = ""
        convCache.removeAll(keepingCapacity: true)
        currency.fetchRates()
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
    }

    // MARK: - 방향

    private func defaultTarget() -> InterpretLanguage {
        switch dirMode {
        case .bToA: return langA
        default:    return langB
        }
    }

    /// auto 모드: '이번 청크'의 언어를 감지해 반대 언어가 타겟과 다르면 전환+재연결.
    private func maybeFlipDirection(_ chunk: String) {
        guard dirMode == .auto, isRunning, !userStopped else { return }
        guard let det = LanguageDetector.detect(chunk, langA, langB) else { return }
        let desired = (det.prefix == langA.prefix) ? langB : langA
        if desired.prefix == curTarget.prefix { return }
        print("[flip] 감지=\(det.code) 타겟 \(curTarget.code)→\(desired.code)")
        curTarget = desired
        statusText = "언어 방향 전환 중…"
        reconnectForFlip()
    }

    private func reconnectForFlip() {
        relay.disconnect()
        connectRelay()
    }

    private func connectRelay() {
        print("[connect] target=\(curTarget.code) dir=\(dirMode.rawValue)")
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
                self.reconnectAttempts = 0
                if self.isRunning { self.statusText = "통역 중" }
                self.sourceText += t
                self.trimIfNeeded()
                self.maybeFlipDirection(t)
            }
        }
        relay.onTranslation = { [weak self] t in
            Task { @MainActor in
                guard let self = self else { return }
                self.reconnectAttempts = 0
                self.translationText += t
                self.trimIfNeeded()
            }
        }
        relay.onTurnComplete = { [weak self] in
            Task { @MainActor in self?.appendTurnBreak() }
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
            Task { @MainActor in
                guard let self = self, self.isRunning else { return }
                self.statusText = "통역 중"
            }
        }
        relay.onClose = { [weak self] _ in
            Task { @MainActor in self?.handleUnexpectedClose() }
        }
    }

    /// 턴 종료 시 다음 발화가 이전 문장과 붙지 않도록 공백 보장.
    private func appendTurnBreak() {
        if let l = sourceText.last, l != " ", l != "\n" { sourceText += " " }
        if let l = translationText.last, l != " ", l != "\n" { translationText += " " }
    }

    /// 장시간 세션 메모리 방어 — 너무 길면 앞쪽을 잘라낸다.
    private func trimIfNeeded() {
        let cap = 8000
        if sourceText.count > cap { sourceText = String(sourceText.suffix(cap)) }
        if translationText.count > cap { translationText = String(translationText.suffix(cap)) }
    }

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
}
