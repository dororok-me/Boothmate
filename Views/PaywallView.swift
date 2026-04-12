import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 배경
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.1, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 로고 & 타이틀
                VStack(spacing: 12) {
                    Text("🎙️")
                        .font(.system(size: 60))

                    Text("Boothmate Pro")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("통역사를 위한 실시간 자막 도구")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 40)

                // 기능 목록
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "waveform", text: "실시간 음성 인식 자막")
                    featureRow(icon: "text.book.closed", text: "글로서리 자동 적용")
                    featureRow(icon: "ruler", text: "도량형 자동 환산")
                    featureRow(icon: "clock.arrow.circlepath", text: "검색어 히스토리 (GM)")
                    featureRow(icon: "doc", text: "파일 뷰어 & 메모 패널")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // 가격
                VStack(spacing: 8) {
                    Text("월 $9.99")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("언제든지 취소 가능")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 24)

                // 구독 버튼
                Button {
                    Task {
                        isPurchasing = true
                        let success = await subscriptionManager.purchase()
                        isPurchasing = false
                        if success { dismiss() }
                        else { showError = true }
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("구독 시작하기")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0.25, green: 0.78, blue: 0.65))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
                .disabled(isPurchasing || isRestoring)

                // 복원 버튼
                Button {
                    Task {
                        isRestoring = true
                        await subscriptionManager.restorePurchases()
                        isRestoring = false
                        if subscriptionManager.isSubscribed { dismiss() }
                    }
                } label: {
                    Text(isRestoring ? "복원 중..." : "구매 복원")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 8)

                // 이용약관
                HStack(spacing: 4) {
                    Link("개인정보처리방침", destination: URL(string: "https://dororok-me.github.io/privacy-policy/privacy-policy.html")!)
                    Text("·").foregroundColor(.white.opacity(0.4))
                    Link("이용약관", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .padding(.bottom, 32)

                Spacer()
            }
        }
        .alert("구매 실패", isPresented: $showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("구매 중 오류가 발생했습니다. 다시 시도해주세요.")
        }
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.checkSubscriptionStatus()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.25, green: 0.78, blue: 0.65))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
    }
}
