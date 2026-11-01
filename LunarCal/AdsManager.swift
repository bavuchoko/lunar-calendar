import AppTrackingTransparency
import GoogleMobileAds

/// 광고 추적 허용(ATT) 응답을 받은 뒤에 Google Mobile Ads를 시작합니다.
/// 광고를 제거한 사용자에게는 추적 허용을 묻지 않고 광고도 시작하지 않습니다.
@MainActor
final class AdsManager: ObservableObject {
    static let shared = AdsManager()

    /// true가 되면 배너 광고를 요청해도 됩니다.
    @Published private(set) var isReady = false

    private var isRequesting = false

    private init() {}

    /// 앱이 활성 상태가 될 때마다 호출합니다. 추적 허용 팝업은 앱이 활성 상태일 때만 표시됩니다.
    func prepareIfNeeded() async {
        guard !isReady, !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        // 재설치 직후에는 저장된 구매 상태가 비어 있으므로, 구매 내역을 먼저 확인합니다.
        await PurchaseManager.shared.refreshEntitlements()
        guard !PurchaseManager.shared.isAdsRemoved else { return }

        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
            // 다른 시스템 팝업이 떠 있으면 응답 없이 끝날 수 있어, 다음 활성화 때 다시 묻습니다.
            guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else { return }
        }

        _ = await MobileAds.shared.start()
        isReady = true
    }
}
