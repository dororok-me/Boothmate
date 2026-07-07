import Foundation

/// 중계 서버(Gemini Live 프록시)와의 WebSocket 클라이언트.
/// 프로토콜:
///   연결: wss://<relay>/?pass=<통과키>(P1) 또는 /?ticket=<티켓>(P2)
///   송신: {"setup":{...}} → {"realtimeInput":{"audio":{data,mimeType}}}
///   수신: serverContent.inputTranscription/outputTranscription/turnComplete,
///         boothmate.{time|time_up}, goAway
final class RelayClient: NSObject, URLSessionWebSocketDelegate {

    // 콜백 (호출 스레드 임의 — 수신자가 메인 홉 처리)
    var onSource: ((String) -> Void)?
    var onTranslation: ((String) -> Void)?
    var onTurnComplete: (() -> Void)?
    var onTime: ((Int) -> Void)?
    var onTimeUp: (() -> Void)?
    var onOpen: (() -> Void)?
    var onClose: ((Int) -> Void)?

    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var closeReported = false

    func connect(passKey: String, setup: [String: Any]) {
        connect(query: URLQueryItem(name: "pass", value: passKey), setup: setup)
    }

    func connect(ticket: String, setup: [String: Any]) {
        connect(query: URLQueryItem(name: "ticket", value: ticket), setup: setup)
    }

    private func connect(query: URLQueryItem, setup: [String: Any]) {
        guard var comps = URLComponents(string: AppConfig.relayWSBase) else { return }
        comps.path = "/"
        comps.queryItems = [query]
        guard let url = comps.url else { return }

        closeReported = false
        let t = session.webSocketTask(with: url)
        task = t
        t.resume()
        sendJSON(["setup": setup])
        receiveLoop(t)
    }

    func sendAudio(base64: String) {
        sendJSON(["realtimeInput": ["audio": ["data": base64, "mimeType": "audio/pcm;rate=16000"]]])
    }

    /// 사용자/방향전환에 의한 정상 종료. task를 비워 이후 옛 소켓 이벤트를 무시.
    func disconnect() {
        let old = task
        task = nil
        old?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
        guard webSocketTask === task else { return }
        onOpen?()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        reportClose(from: webSocketTask, code: closeCode.rawValue)
    }

    // MARK: - 내부

    /// 현재 task의 종료만 1회 보고 (옛 소켓 이벤트는 무시).
    private func reportClose(from t: URLSessionWebSocketTask, code: Int) {
        guard t === task, !closeReported else { return }
        closeReported = true
        onClose?(code)
    }

    private func sendJSON(_ obj: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    private func receiveLoop(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            guard let self = self, t === self.task else { return }
            switch result {
            case .failure:
                self.reportClose(from: t, code: -1)
            case .success(let message):
                switch message {
                case .string(let text): self.handle(text)
                case .data(let data): self.handle(String(data: data, encoding: .utf8) ?? "")
                @unknown default: break
                }
                if t === self.task { self.receiveLoop(t) }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }

        if let bm = msg["boothmate"] as? [String: Any], let type = bm["type"] as? String {
            if type == "time", let s = bm["secondsLeft"] as? Int {
                onTime?(s)
            } else if type == "time_up" {
                onTimeUp?()
            }
            return
        }

        if msg["goAway"] != nil { return }

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
