import UIKit
import UserNotifications
import GoogleMobileAds

/// 포그라운드에서도 배너·소리가 나오도록 하고, 알림 센터 델리게이트를 연결합니다.
/// Google Mobile Ads 등이 delegate를 덮어쓸 수 있어, 초기화 직후·포그라운드 복귀 시마다 다시 붙입니다.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        bindNotificationDelegate()
        MobileAds.shared.start()
        bindNotificationDelegate()
        DispatchQueue.main.async { [weak self] in
            self?.bindNotificationDelegate()
            NotificationManager.shared.rescheduleAll(
                in: PersistenceController.shared.container.viewContext
            )
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        bindNotificationDelegate()
    }

    private func bindNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
