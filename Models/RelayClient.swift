import Foundation

/// 중계 서버(Gemini Live 프록시)와의 WebSocket 클라이언트.
/// 프로토콜(웹 클라이언트/서버 기준):
///   연결: wss://<relay>/?pass=<통과키>  (P1 개발)  또는  /?ticket=<티켓>  (P2)
///   송신: {"setup":{...}}  →  {"realtimeInput":{"audio":{data,mimeType}}}
///   수신: serverContent.inputTranscription/outputTranscription/turnComplete,
///         boothmate.{time|time_up}, goAway
final class RelayClient {

    // 콜백 (호출 스레드 임의 — 수신자가 메인 홉 처리)
    var onSource: ((String) -> Void)?
    var onTranslation: ((String) -> Void)?
    var onTurnComplete: (() -> Void)?
    var onTime: ((Int) -> Void)?
    var onTimeUp: (() -> Void)?
    var onClose: ((String?) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var closed = false

    /// P1: 통과키로 연결. setup 딕셔너리를 즉시 전송.
    func connect(passKey: String, setup: [String: Any]) {
        connect(query: URLQueryItem(name: "pass", value: passKey), setup: setup)
    }

    /// P2: 티켓으로 연결.
    func connect(ticket: String, setup: [String: Any]) {
        connect(query: URLQueryItem(name: "ticket", value: ticket), setup: setup)
    }

    private func connect(query: URLQueryItem, setup: [String: Any]) {
        closed = false
        guard var comps = URLComponents(string: AppConfig.relayWSBase) else { return }
        comps.path = "/"
        comps.queryItems = [query]
        guard let url = comps.url else { return }

        let t = session.webSocketTask(with: url)
        task = t
        t.resume()
        sendJSON(["setup": setup])
        receiveLoop()
    }

    func sendAudio(base64: String) {
        sendJSON(["realtimeInput": ["audio": ["data": base64, "mimeType": "audio/pcm;rate=16000"]]])
    }

    func disconnect() {
        closed = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    // MARK: - 내부

    private func sendJSON(_ obj: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                if !self.closed { self.onClose?(err.localizedDescription) }
            case .success(let message):
                switch message {
                case .string(let text): self.handle(text)
                case .data(let data): self.handle(String(data: data, encoding: .utf8) ?? "")
                @unknown default: break
                }
                if !self.closed { self.receiveLoop() }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }

        // 중계 서버 제어 메시지 (잔여시간 / 소진)
        if let bm = msg["boothmate"] as? [String: Any], let type = bm["type"] as? String {
            if type == "time", let s = bm["secondsLeft"] as? Int {
                onTime?(s)
            } else if type == "time_up" {
                onTimeUp?()
            }
            return
        }

        if msg["goAway"] != nil { return } // 세션 곧 만료 — onClose에서 재연결 처리

        guard let sc = msg["serverContent"] as? [String: Any] else { return }
        if let it = sc["inputTranscription"] as? [String: Any], let t = it["text"] as? String, !t.isEmpty {
            onSource?(t)
        }
        if let ot = sc["outputTranscription"] as? [String: Any], let t = ot["text"] as? String, !t.isEmpty {
            onTranslation?(t)
        }
        if let done = sc["turnComplete"] as? Bool, done {
            onTurnComplete?()
        }
    }
}
