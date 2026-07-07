import SwiftUI
import WebKit

struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var logoOpacity: CGFloat = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var taglineOpacity: CGFloat = 0
    @State private var labOpacity: CGFloat = 0
    @State private var statusOpacity: CGFloat = 0
    @State private var statusText: String = "최신 언어 엔진을 로딩 중입니다"
    @State private var tickCount: Int = 0
    @State private var dotTimer: Timer? = nil
    @State private var warmupDone: Bool = false

    // 시작 중 순서대로 보여줄 메시지
    private let loadingMessages = [
        "최신 언어 엔진을 로딩 중입니다",
        "언어 엔진 최적화를 확인합니다",
        "실시간 환율 정보를 업데이트 중입니다"
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 로고 영역
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("Boothmate")
                            .font(.system(size: 42, weight: .bold, design: .default))
                            .foregroundColor(.primary)

                        Text("Your another boothmate")
                            .font(.system(size: 16, weight: .light, design: .default))
                            .foregroundColor(.secondary)
                            .opacity(taglineOpacity)
                    }
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                }

                Spacer()

                // 하단 영역
                VStack(spacing: 20) {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.secondary)
                        Text(statusText)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            // 메시지가 바뀔 때 부드럽게 전환
                            .id(statusText.replacingOccurrences(of: ".", with: ""))
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value:
                                statusText.replacingOccurrences(of: ".", with: ""))
                    }
                    .opacity(statusOpacity)

                    Text("dororok AI Lab")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                        .opacity(labOpacity)
                }
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            startAnimation()
            startWarmup()
        }
    }

    private func startAnimation() {
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.5)) {
                taglineOpacity = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.4)) {
                statusOpacity = 1
                labOpacity = 1
            }
            startStatusAnimation()
        }
    }

    private func startStatusAnimation() {
        // 0.35초마다: 점(...) 애니메이션 + 일정 주기로 다음 메시지로 전환
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            tickCount += 1

            // 약 1초(3틱)마다 다음 메시지로, 마지막 메시지에서 멈춤
            let idx = min(tickCount / 3, loadingMessages.count - 1)
            let dots = String(repeating: ".", count: tickCount % 4)  // 0~3개 반복
            statusText = loadingMessages[idx] + dots

            // 실제 워밍업이 끝났고 세 메시지를 충분히 보여줬으면 마무리
            if warmupDone && tickCount >= 8 {
                finishSplash()
            }
        }
    }

    private func finishSplash() {
        guard dotTimer != nil else { return }   // 중복 호출 방지
        dotTimer?.invalidate()
        dotTimer = nil
        statusText = "준비 완료"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isFinished = true
            }
        }
    }

    private func startWarmup() {
        // WKWebView 워밍업 (백그라운드에서 다음 사전 미리 로드)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WarmupWebView.shared.warmup {
                DispatchQueue.main.async {
                    warmupDone = true   // 전환은 startStatusAnimation 타이머가 처리
                }
            }
        }
    }
}

// MARK: - WebView 워밍업

class WarmupWebView: NSObject, WKNavigationDelegate {
    static let shared = WarmupWebView()
    private var webView: WKWebView?
    private var completion: (() -> Void)?
    private var timer: Timer?

    func warmup(completion: @escaping () -> Void) {
        self.completion = completion

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.navigationDelegate = self
        self.webView = wv

        if let url = URL(string: "https://dic.daum.net/search.do?q=hello&dic=eng&search_first=Y&lang=EN_KO") {
            wv.load(URLRequest(url: url))
        }

        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.finish()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish() }

    private func finish() {
        timer?.invalidate()
        timer = nil
        completion?()
        completion = nil
    }
}
