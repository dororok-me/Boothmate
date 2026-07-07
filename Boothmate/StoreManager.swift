import SwiftUI
import StoreKit
import Combine

/// StoreKit 인앱결제(소모성 시간권) 관리. 지금은 로컬 테스트용.
@MainActor
final class StoreManager: ObservableObject {

    // 상품 ID (App Store Connect에도 같은 ID로 등록하게 됨)
    static let pass5h = "com.dororok.Boothmate.pass5h"
    static let pass10h = "com.dororok.Boothmate.pass10h"
    static let productIDs = [pass5h, pass10h]

    @Published var products: [Product] = []
    @Published var message: String?
    @Published var loading = false

    func loadProducts() async {
        loading = true
        defer { loading = false }
        do {
            let prods = try await Product.products(for: StoreManager.productIDs)
            products = prods.sorted { $0.price < $1.price }
            if products.isEmpty { message = "상품을 불러오지 못했습니다. (StoreKit 설정 확인)" }
        } catch {
            message = "상품 로드 실패: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    // TODO(④): 영수증을 Railway 서버로 보내 시간 적립. 지금은 성공만 표시.
                    message = "✅ 구매 성공: \(product.displayName)"
                    await transaction.finish()
                } else {
                    message = "구매 검증 실패"
                }
            case .userCancelled:
                message = nil
            case .pending:
                message = "구매 대기 중(승인 필요)"
            @unknown default:
                message = nil
            }
        } catch {
            message = "구매 실패: \(error.localizedDescription)"
        }
    }
}

/// 시간권 구매 화면 (테스트).
struct TimePassPaywallView: View {
    @StateObject private var store = StoreManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("통역 시간권")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 10)
                Text("필요한 만큼 구매하세요 · 소모성")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if store.loading {
                    ProgressView().padding(.top, 30)
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task { await store.purchase(product) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.displayName).font(.system(size: 16, weight: .semibold))
                                    Text(product.description).font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Color(red: 0.31, green: 0.27, blue: 0.9))
                                    .clipShape(Capsule())
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let msg = store.message {
                    Text(msg).font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("시간권")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .task { await store.loadProducts() }
        }
    }
}
