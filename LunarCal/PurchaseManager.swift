import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // TODO: App Store Connect에 등록한 Product ID로 교체하세요.
    private let removeAdsProductId = "lunarcal.remove_ads"

    @Published private(set) var isAdsRemoved: Bool = UserDefaults.standard.bool(forKey: "isAdsRemoved")
    @Published var lastErrorMessage: String?
    @Published var isBusy: Bool = false

    private init() {
        Task { await refreshEntitlements() }
    }

    func purchaseRemoveAds() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let products = try await Product.products(for: [removeAdsProductId])
            guard let product = products.first else {
                lastErrorMessage = "상품 정보를 찾을 수 없어요. Product ID를 확인해 주세요."
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                lastErrorMessage = "결제가 보류 중이에요."
            @unknown default:
                lastErrorMessage = "알 수 없는 결제 상태예요."
            }
        } catch {
            lastErrorMessage = "결제 실패: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "복원 실패: \(error.localizedDescription)"
        }
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func refreshEntitlements() async {
        var removed = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == removeAdsProductId {
                removed = true
            }
        }
        setAdsRemoved(removed)
    }

    private func setAdsRemoved(_ value: Bool) {
        isAdsRemoved = value
        UserDefaults.standard.set(value, forKey: "isAdsRemoved")
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "PurchaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "영수증 검증에 실패했어요."])
        case .verified(let signed):
            return signed
        }
    }
}

