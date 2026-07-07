import SwiftUI

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
    @State private var showReady: Bool = false

    // 마침표 세 개가 순서대로 켜지고 사라지는 애니메이션
    @State private var dotPhase: Int = 0

    // 한 메시지가 화면에 머무는 시간 (0.3초 tick × ticksPerMessage)
    private let ticksPerMessage: Int = 4

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
                                    .id(messageIndex)
                                    .transition(.opacity)
                                animatedDots
                            }
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
        .task {
            await runSequence()
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

    // MARK: - 로딩 시퀀스 (Timer 대신 async/await로 구동해 시작 시 main-thread 지터에 덜 취약)

    @MainActor
    private func runSequence() async {
        // 1단계: 로고 페이드인
        withAnimation(.easeOut(duration: 0.5)) {
            logoOpacity = 1
            logoScale = 1.0
        }
        await sleep(0.25)

        // 2단계: 서브타이틀
        withAnimation(.easeOut(duration: 0.4)) {
            taglineOpacity = 1
        }
        await sleep(0.2)

        // 3단계: 로딩 상태 등장
        withAnimation(.easeOut(duration: 0.4)) {
            statusOpacity = 1
            labOpacity = 1
        }

        // 4단계: 메시지 시퀀스 (각 메시지를 순서대로 노출하며 마침표 애니메이션 재생)
        for index in statusMessages.indices {
            if index != 0 {
                withAnimation(.easeInOut(duration: 0.25)) {
                    messageIndex = index
                }
            }
            for _ in 0..<ticksPerMessage {
                await sleep(0.3)
                withAnimation(.easeInOut(duration: 0.2)) {
                    dotPhase = (dotPhase + 1) % 4
                }
            }
        }

        // 5단계: 준비 완료 → 전환
        withAnimation(.easeInOut(duration: 0.25)) {
            showReady = true
        }
        await sleep(0.5)
        withAnimation(.easeInOut(duration: 0.4)) {
            isFinished = true
        }
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
