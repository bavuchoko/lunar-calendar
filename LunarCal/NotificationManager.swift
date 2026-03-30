import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// 권한이 아직 없으면 요청한 뒤 등록합니다. 포그라운드 표시는 `AppDelegate`의 델리게이트가 담당합니다.
    func scheduleNotification(for schedule: Schedule) {
        guard let id = schedule.id?.uuidString,
              let title = schedule.title,
              let alertTime = schedule.alertTime else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.enqueueRequest(center: center, id: id, title: title, alertTime: alertTime)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    self.enqueueRequest(center: center, id: id, title: title, alertTime: alertTime)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func enqueueRequest(
        center: UNUserNotificationCenter,
        id: String,
        title: String,
        alertTime: Date
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "일정 알림"
        content.body = title
        content.sound = .default

        let cal = Calendar.current
        let triggerDate = cal.dateComponents([.year, .month, .day, .hour, .minute], from: alertTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        guard trigger.nextTriggerDate() != nil else {
            #if DEBUG
            print("알림 시각이 이미 지났거나 유효하지 않습니다. (알림 등록 생략)")
            #endif
            return
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("알림 등록 실패:", error.localizedDescription)
            }
        }
    }

    func removeNotification(for schedule: Schedule) {
        if let id = schedule.id?.uuidString {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }
    }
}
