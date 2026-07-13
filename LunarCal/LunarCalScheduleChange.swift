import Foundation

extension Notification.Name {
    static let lunarCalSchedulesDidChange = Notification.Name("lunarCalSchedulesDidChange")
}

enum LunarCalScheduleChange {
    static func post() {
        NotificationCenter.default.post(name: .lunarCalSchedulesDidChange, object: nil)
    }
}
