import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    let productID = "com.dororok.Boothmate.monthly"
    private let firstLaunchKey = "boothmate_first_launch_date"

    @Published var isSubscribed: Bool = false
    @Published var isInTrialPeriod: Bool = true
    @Published var daysRemaining: Int = 30
    @Published var products: [Product] = []

    private init() {
        setFirstLaunchDateIfNeeded()
        updateTrialStatus()
        // ✅ 앱 실행시 구독 상태 자동 확인
        Task {
            await checkSubscriptionStatus()
        }
    }

    private func setFirstLaunchDateIfNeeded() {
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }

    func updateTrialStatus() {
        guard let firstDate = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date else {
            isInTrialPeriod = true
            daysRemaining = 30
            return
        }
        let elapsed = Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
        daysRemaining = max(0, 30 - elapsed)
        isInTrialPeriod = elapsed < 30
    }

    var canUseApp: Bool {
        return isInTrialPeriod || isSubscribed
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [productID])
            products = storeProducts
        } catch {
            print("상품 로드 실패: \(error)")
        }
    }

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

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            print("복원 실패: \(error)")
        }
    }

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
