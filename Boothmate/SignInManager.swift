import SwiftUI
import AuthenticationServices
import Combine

/// Sign in with Apple 로그인 상태 관리 + 저장.
final class SignInManager: ObservableObject {

    struct AppleUser: Codable, Equatable {
        let id: String       // 애플이 주는 안정적 사용자 식별자
        let email: String
        let name: String
    }

    @Published var user: AppleUser?
    @Published var status: String?   // 진단용: 진행/오류 상태 표시

    private let storeKey = "bm_apple_user"

    init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let u = try? JSONDecoder().decode(AppleUser.self, from: data) {
            user = u
        }
    }

    /// SignInWithAppleButton 결과 처리.
    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            status = nil
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                status = "로그인 정보를 읽지 못했습니다."
                return
            }
            // email·name은 '최초 로그인'에만 제공됨 → 기존 저장값으로 보완
            let email = cred.email ?? user?.email ?? "\(cred.user)@appleid.boothmate"
            let nameParts = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }
            let joined = nameParts.joined(separator: " ")
            let name = joined.isEmpty ? (user?.name ?? "Boothmate") : joined
            let u = AppleUser(id: cred.user, email: email, name: name)
            user = u
            if let data = try? JSONEncoder().encode(u) {
                UserDefaults.standard.set(data, forKey: storeKey)
            }
        case .failure(let error):
            let ns = error as NSError
            if ns.code == ASAuthorizationError.canceled.rawValue {
                status = nil   // 사용자가 취소 → 조용히
            } else {
                status = "로그인 실패 [\(ns.domain) \(ns.code)]: \(error.localizedDescription)"
            }
            print("[Boothmate] Apple 로그인 실패: \(ns)")
        }
    }

    func signOut() {
        user = nil
        UserDefaults.standard.removeObject(forKey: storeKey)
    }
}

/// 로그인 게이트: 로고 + Sign in with Apple 버튼.
struct LoginGateView: View {
    @ObservedObject var signIn: SignInManager
    @State private var appeared = false

    var body: some View {
        ZStack {
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
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 8)

                Text("Real-time interpretation")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))

                SignInWithAppleButton(.signIn) { request in
                    signIn.status = "애플 로그인 창을 여는 중…"
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    signIn.handle(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .cornerRadius(12)
                .padding(.horizontal, 44)
                .padding(.top, 6)

                if let status = signIn.status {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 4)
                }
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true } }
    }
}
