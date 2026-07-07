import SwiftUI
import WebKit

struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var logoOpacity: CGFloat = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var taglineOpacity: CGFloat = 0
    @State private var labOpacity: CGFloat = 0
    @State private var statusOpacity: CGFloat = 0

    // 로딩 메시지 시퀀스 (앱이 실제로 일하고 있다는 인상을 주기 위한 단계별 상태 메시지)
    private let statusMessages: [String] = [
        "최신 언어 엔진을 로딩 중입니다",
        "언어 엔진 최적화를 확인합니다",
        "실시간 환율 정보를 업데이트 중입니다"
    ]
    @State private var messageIndex: Int = 0
    @State private var messageOpacity: CGFloat = 1
    @State private var showReady: Bool = false

    // 마침표 세 개가 순서대로 켜지고 사라지는 애니메이션
    @State private var dotPhase: Int = 0
    @State private var dotTimer: Timer? = nil

    // 각 단계 완료 플래그
    @State private var scheduleDone: Bool = false
    @State private var warmupDone: Bool = false
    @State private var didFinish: Bool = false

    // 한 메시지가 화면에 머무는 시간
    private let messageDuration: Double = 1.2

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

                        if showReady {
                            Text("준비 완료")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        } else {
                            HStack(spacing: 1) {
                                Text(statusMessages[messageIndex])
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                animatedDots
                            }
                            .opacity(messageOpacity)
                            .id(messageIndex)
                        }
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
        .onDisappear {
            dotTimer?.invalidate()
        }
    }

    // 마침표 세 개: 현재 dotPhase보다 인덱스가 작은 점만 켜진다.
    // dotPhase 0 → 모두 꺼짐, 1 → 첫째, 2 → 둘째까지, 3 → 셋째까지 켜진 뒤 다시 꺼짐.
    private var animatedDots: some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { i in
                Text(".")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .opacity(dotPhase > i ? 1 : 0)
            }
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

        // 3단계: 로딩 상태 등장 + 메시지 시퀀스 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.4)) {
                statusOpacity = 1
                labOpacity = 1
            }
            startDotAnimation()
            scheduleMessages()
        }
    }

    private func startDotAnimation() {
        dotTimer?.invalidate()
        dotPhase = 0
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                dotPhase = (dotPhase + 1) % 4
            }
        }
    }

    // 각 메시지를 순서대로 보여준다. 마지막 메시지까지 노출되면 scheduleDone 처리.
    private func scheduleMessages() {
        for index in statusMessages.indices {
            let delay = messageDuration * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard !didFinish else { return }
                advanceMessage(to: index)
            }
        }

        // 모든 메시지를 최소 한 번씩 노출한 뒤에야 스플래시 종료를 허용
        let totalDuration = messageDuration * Double(statusMessages.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            scheduleDone = true
            maybeFinish()
        }
    }

    private func advanceMessage(to index: Int) {
        // 짧게 페이드 아웃 → 텍스트 교체 → 페이드 인
        if index == 0 {
            messageIndex = 0
            messageOpacity = 1
            return
        }
        withAnimation(.easeIn(duration: 0.18)) {
            messageOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            messageIndex = index
            withAnimation(.easeOut(duration: 0.22)) {
                messageOpacity = 1
            }
        }
    }

    private func startWarmup() {
        // WKWebView 워밍업 (백그라운드에서 다음 사전 미리 로드)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WarmupWebView.shared.warmup {
                DispatchQueue.main.async {
                    warmupDone = true
                    maybeFinish()
                }
            }
        }
    }

    // 워밍업과 메시지 시퀀스가 모두 끝났을 때만 종료
    private func maybeFinish() {
        guard scheduleDone, warmupDone, !didFinish else { return }
        didFinish = true

        dotTimer?.invalidate()
        dotTimer = nil

        withAnimation(.easeInOut(duration: 0.25)) {
            showReady = true
        }

        // "준비 완료"를 잠깐 보여주고 전환
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isFinished = true
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
