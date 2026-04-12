import SwiftUI
import WebKit

struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var logoOpacity: CGFloat = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var taglineOpacity: CGFloat = 0
    @State private var labOpacity: CGFloat = 0
    @State private var statusOpacity: CGFloat = 0
    @State private var statusText: String = "앱을 시작하는 중입니다..."
    @State private var dotCount: Int = 0
    @State private var dotTimer: Timer? = nil
    @State private var warmupDone: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 로고 영역
                VStack(spacing: 16) {
                    // Boothmate 워드마크
                    VStack(spacing: 6) {
                        Text("Boothmate")
                            .font(.system(size: 42, weight: .bold, design: .default))
                            .foregroundColor(.primary)

                        // 서브타이틀
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
                    // 로딩 상태
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.secondary)
                        Text(statusText)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .opacity(statusOpacity)

                    // dororok AI Lab
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
        // 1단계: 로고 페이드인
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale = 1.0
        }

        // 2단계: 서브타이틀
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.5)) {
                taglineOpacity = 1
            }
        }

        // 3단계: 로딩 상태
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.4)) {
                statusOpacity = 1
                labOpacity = 1
            }
            startDotAnimation()
        }
    }

    private func startDotAnimation() {
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            dotCount = (dotCount + 1) % 4
            let dots = String(repeating: ".", count: dotCount)
            statusText = "앱을 시작하는 중입니다\(dots)"
        }
    }

    private func startWarmup() {
        // WKWebView 워밍업 (백그라운드에서 다음 사전 미리 로드)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WarmupWebView.shared.warmup {
                DispatchQueue.main.async {
                    dotTimer?.invalidate()
                    warmupDone = true
                    statusText = "준비 완료"

                    // 잠깐 보여주고 전환
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isFinished = true
                        }
                    }
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

        if let url = URL(string: "https://small.dic.daum.net/search.do?q=hello&dic=eng") {
            wv.load(URLRequest(url: url))
        }

        // 최대 3초 대기 후 강제 완료
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.finish()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish()
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        completion?()
        completion = nil
    }
}
