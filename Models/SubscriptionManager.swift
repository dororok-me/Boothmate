import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // 구독 상품 ID
    let productID = "com.dororok.Boothmate.monthly"

    // 첫 실행일 저장 키
    private let firstLaunchKey = "boothmate_first_launch_date"

    @Published var isSubscribed: Bool = false
    @Published var isInTrialPeriod: Bool = true
    @Published var daysRemaining: Int = 30
    @Published var products: [Product] = []

    private init() {
        setFirstLaunchDateIfNeeded()
        updateTrialStatus()
    }

    // MARK: - 첫 실행일 설정

    private func setFirstLaunchDateIfNeeded() {
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }

    // MARK: - 무료 체험 상태 확인

    func updateTrialStatus() {
        guard let firstDate = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date else {
            isInTrialPeriod = true
            daysRemaining = 30
            print("❌ firstDate 없음")
            return
        }
        let elapsed = Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
        daysRemaining = max(0, 30 - elapsed)
        isInTrialPeriod = elapsed < 30
        print("✅ elapsed: \(elapsed), isInTrialPeriod: \(isInTrialPeriod), canUseApp: \(canUseApp)")
    }

    // MARK: - 앱 사용 가능 여부

    var canUseApp: Bool {
        return isInTrialPeriod || isSubscribed
    }

    // MARK: - 상품 로드

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [productID])
            products = storeProducts
        } catch {
            print("상품 로드 실패: \(error)")
        }
    }

    // MARK: - 구독 구매

    func purchase() async -> Bool {
        guard let product = products.first else {
            await loadProducts()
            guard let product = products.first else { return false }
            return await doPurchase(product)
        }
        return await doPurchase(product)
    }

    private func doPurchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isSubscribed = true
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("구매 실패: \(error)")
            return false
        }
    }

    // MARK: - 구독 복원

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            print("복원 실패: \(error)")
        }
    }

    // MARK: - 구독 상태 확인

    func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productID && transaction.revocationDate == nil {
                    isSubscribed = true
                    return
                }
            }
        }
        isSubscribed = false
    }

    // MARK: - 검증

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
