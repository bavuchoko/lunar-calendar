import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    /// 광고를 실제로 받았는지 알려 줍니다. 받기 전이나 실패했을 때는 광고 자리를 숨기는 데 씁니다.
    @Binding var isLoaded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)   // 예전: GADBannerView + GADAdSizeBanner
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication
            .shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        banner.load(Request())                          // 예전: GADRequest()
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        context.coordinator.isLoaded = $isLoaded
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var isLoaded: Binding<Bool>

        init(isLoaded: Binding<Bool>) {
            self.isLoaded = isLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            isLoaded.wrappedValue = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            // 다음 자동 새로고침에서 광고를 받으면 bannerViewDidReceiveAd가 다시 불립니다.
            isLoaded.wrappedValue = false
        }
    }
}
