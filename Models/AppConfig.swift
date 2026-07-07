import Foundation

/// 앱 전역 설정 상수 (v2.0 네이티브 재구축).
/// 서버·모델·상품 식별자를 한 곳에 모아둔다. 자세한 배경은 docs/REBUILD_DESIGN.md 참고.
enum AppConfig {

    // MARK: - 중계 서버 (Railway)

    /// Gemini Live 중계 WebSocket 베이스. 실제 연결은 `\(relayWSBase)/?ticket=<발급티켓>`.
    static let relayWSBase = "wss://boothmateonline-production.up.railway.app"

    /// 티켓/결제/무료체험 HTTP 베이스 (POST /ticket, /iap/verify, /trial/claim).
    static let relayHTTPBase = "https://boothmateonline-production.up.railway.app"

    // MARK: - Gemini

    /// 전사+번역 모델 (서버가 setup 메시지에 사용).
    static let geminiModel = "models/gemini-3.5-live-translate-preview"

    /// 마이크 캡처 → 서버 전송 샘플레이트 (Gemini Live 요구사항).
    static let audioSampleRate: Double = 16000

    // MARK: - 인증 (Firebase)

    /// Firebase 프로젝트 ID (Apple/Google 로그인). 서버 토큰 검증과 일치해야 함.
    static let firebaseProjectId = "dororokrealtimespeech"

    // MARK: - 인앱결제 (소비형 시간권)

    static let bundleId = "com.dororok.Boothmate"

    enum Product: String, CaseIterable {
        case pass5h  = "com.dororok.Boothmate.pass.5h"
        case pass10h = "com.dororok.Boothmate.pass.10h"

        /// 구매 시 적립되는 초 (서버 매핑과 일치).
        var seconds: Int {
            switch self {
            case .pass5h:  return 5 * 3600
            case .pass10h: return 10 * 3600
            }
        }
    }

    /// 무료 체험(초) — 서버가 App Attest/계정 검증 후 부여.
    static let trialSeconds = 3600
}
