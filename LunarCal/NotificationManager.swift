import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print(" 알림 권한 허용됨")
            } else {
                print(" 알림 권한 거부됨")
            }
        }
    }

    func scheduleNotification(for schedule: Schedule) {
        guard let id = schedule.id?.uuidString,
              let title = schedule.title,
              let alertTime = schedule.alertTime else { return }

        let content = UNMutableNotificationContent()
        content.title = "일정 알림"
        content.body = title
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func removeNotification(for schedule: Schedule) {
        if let id = schedule.id?.uuidString {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }
    }
}
