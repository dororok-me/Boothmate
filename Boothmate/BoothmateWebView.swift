import SwiftUI
import WebKit
import AVFoundation
import Combine

// MARK: - 로딩 상태 (웹 준비되면 스플래시 숨김)

final class WebLoadState: ObservableObject {
    @Published var ready = false
}

// MARK: - 네이티브 스플래시(로딩) 화면

struct BoothmateSplashView: View {
    @State private var appeared = false
    @State private var pulse = false

    // 로딩 중 순서대로 보여줄 메시지
    private let loadingMessages = [
        "최신 언어 엔진을 로딩 중입니다",
        "언어 엔진 최적화를 확인합니다",
        "실시간 환율 정보를 업데이트 중입니다"
    ]
    @State private var statusText = "최신 언어 엔진을 로딩 중입니다"
    @State private var tickCount = 0
    @State private var dotTimer: Timer? = nil

    var body: some View {
        ZStack {
            // 로고와 어울리는 파랑→초록 그라데이션 배경
            LinearGradient(
                colors: [Color(red: 0.24, green: 0.55, blue: 0.91),
                         Color(red: 0.30, green: 0.85, blue: 0.53)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
                    .scaleEffect(appeared ? (pulse ? 1.04 : 1.0) : 0.78)
                    .opacity(appeared ? 1 : 0)

                // 로딩 메시지 (순서대로 전환 + 점 애니메이션)
                HStack(spacing: 9) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                        .frame(minWidth: 220, alignment: .leading)
                }
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            // 튀어오르듯 등장
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
            // 로딩 중 은은한 숨쉬기(펄스)
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.5)) { pulse = true }
            startStatusAnimation()
        }
        .onDisappear {
            dotTimer?.invalidate()
            dotTimer = nil
        }
    }

    private func startStatusAnimation() {
        // 0.35초마다: 점(...) 애니메이션 + 약 1.4초마다 다음 메시지로 전환
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            tickCount += 1
            let idx = min(tickCount / 4, loadingMessages.count - 1)   // 마지막 메시지에서 멈춤
            let dots = String(repeating: ".", count: tickCount % 4)   // 0~3개 반복
            statusText = loadingMessages[idx] + dots
        }
    }
}

// MARK: - 루트: 웹뷰 + 스플래시 오버레이

struct BoothmateRootView: View {
    @StateObject private var loadState = WebLoadState()
    @StateObject private var signIn = SignInManager()
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            BoothmateWebView(loadState: loadState, signIn: signIn)
                .ignoresSafeArea(edges: .bottom)

            if signIn.user == nil {
                LoginGateView(signIn: signIn)          // 로그인 전: 애플 로그인 게이트
                    .transition(.opacity)
            } else if !loadState.ready {
                BoothmateSplashView()                  // 로그인 후·로딩 중: 스플래시
                    .transition(.opacity)
            }

            // [임시 테스트] 시간권 구매 화면 여는 버튼. 나중에 실제 '충전' 흐름으로 교체.
            if signIn.user != nil && loadState.ready {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showPaywall = true } label: {
                            Text("🛒 시간권(테스트)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                        }
                        .padding(.trailing, 14).padding(.bottom, 30)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: loadState.ready)
        .animation(.easeInOut(duration: 0.4), value: signIn.user)
        .sheet(isPresented: $showPaywall) { TimePassPaywallView() }
        .onAppear {
            // 폴백: 준비 신호가 안 와도 최대 15초 후엔 스플래시 해제
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { loadState.ready = true }
        }
    }
}

// MARK: - 웹뷰

struct BoothmateWebView: UIViewRepresentable {

    static let remoteURL = URL(string: "https://online.boothmate.co.kr/?app=ios&lang=en")!
    let loadState: WebLoadState
    let signIn: SignInManager

    func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        c.loadState = loadState
        c.user = signIn.user
        return c
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let marker = WKUserScript(
            source: "window.__bmBuild='v9-splash'; try{document.documentElement.classList.add('bm-app','bm-lang-en');}catch(e){}",
            injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(marker)
        config.userContentController.add(context.coordinator, name: "bmReady")

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webViewRef = webView
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }

        webView.load(URLRequest(url: BoothmateWebView.remoteURL, cachePolicy: .reloadIgnoringLocalCacheData))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.user = signIn.user
        context.coordinator.tryInjectLogin()   // 로그인 후 웹에 사용자 주입
    }

    // 실제 마이크 사용 시점에만 오디오 카테고리 설정 (setActive는 안 함 — 시작 지연 방지)
    private static var audioConfigured = false
    static func ensureAudioSession() {
        guard !audioConfigured else { return }
        audioConfigured = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        } catch {
            print("[Boothmate] AudioSession 카테고리 설정 실패: \(error)")
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var loadState: WebLoadState?
        weak var webViewRef: WKWebView?
        var user: SignInManager.AppleUser?
        private var didFallback = false
        private var loaded = false
        private var injectedEmail: String?

        private func jsQuote(_ s: String) -> String {
            var t = s.replacingOccurrences(of: "\\", with: "\\\\")
            t = t.replacingOccurrences(of: "'", with: "\\'")
            t = t.replacingOccurrences(of: "\n", with: " ")
            return "'\(t)'"
        }

        /// 로그인된 애플 사용자를 웹 로그인 브리지로 주입 (로드 완료 + 사용자 존재 시 1회).
        func tryInjectLogin() {
            guard loaded, let u = user, injectedEmail != u.email, let wv = webViewRef else { return }
            injectedEmail = u.email
            let js = "if(window.__boothmateNativeLogin){window.__boothmateNativeLogin({email:\(jsQuote(u.email)),name:\(jsQuote(u.name))});}"
            wv.evaluateJavaScript(js)
        }

        /// 웹이 "화면 렌더 완료"를 알리면 스플래시 숨김.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "bmReady" {
                DispatchQueue.main.async { self.loadState?.ready = true }
            }
        }

        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            BoothmateWebView.ensureAudioSession()
            decisionHandler(.grant)
        }

        /// 로드 완료 → 자동 로그인 + 두 번의 애니메이션 프레임 뒤(실제 렌더됨) 준비 신호.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            tryInjectLogin()   // 이미 로그인돼 있으면 웹에 주입
            let js = "requestAnimationFrame(function(){requestAnimationFrame(function(){try{window.webkit.messageHandlers.bmReady.postMessage('ready');}catch(e){}});});"
            webView.evaluateJavaScript(js)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadBundledFallback(webView)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadBundledFallback(webView)
        }

        private func loadBundledFallback(_ webView: WKWebView) {
            guard !didFallback else { return }
            didFallback = true
            let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web")
                ?? Bundle.main.url(forResource: "index", withExtension: "html")
            guard let indexURL else {
                webView.loadHTMLString("<h2 style='font-family:-apple-system;padding:24px'>인터넷 연결을 확인해주세요.</h2>", baseURL: nil)
                return
            }
            webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        }
    }
}
