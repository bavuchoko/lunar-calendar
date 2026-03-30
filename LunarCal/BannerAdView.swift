import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)   // 예전: GADBannerView + GADAdSizeBanner
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication
            .shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        banner.load(Request())                          // 예전: GADRequest()
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) { }
}
