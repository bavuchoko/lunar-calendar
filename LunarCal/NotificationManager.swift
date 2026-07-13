import Foundation
import UserNotifications
import CoreData
import UIKit

enum NotificationScheduleResult {
    case scheduled
    case skippedPast
    case permissionDenied
    case skippedDisabled
}

/// 미리 알림(Reminders)과 같은 방식의 로컬 알림 — 정해진 시각에 배너·잠금 화면·소리.
/// 시계 앱 전체 화면 알람과는 다른 API입니다.
final class NotificationManager {
    static let shared = NotificationManager()

    private let maxOneTimeSlots = 64
    private let repeatingSolarTypes = ["매주", "매월", "매년 (양력)"]

    private init() {}

    // MARK: - Public

    func rescheduleAll(
        in context: NSManagedObjectContext,
        completion: ((NotificationScheduleResult) -> Void)? = nil
    ) {
        context.perform {
            guard let plan = self.buildPlan(in: context) else {
                DispatchQueue.main.async { completion?(.skippedDisabled) }
                return
            }

            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: plan.staleIdentifiers)

            center.getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.apply(plan: plan, center: center, completion: completion)
                case .notDetermined:
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        if granted {
                            self.apply(plan: plan, center: center, completion: completion)
                        } else {
                            DispatchQueue.main.async { completion?(.permissionDenied) }
                        }
                    }
                case .denied:
                    DispatchQueue.main.async { completion?(.permissionDenied) }
                @unknown default:
                    DispatchQueue.main.async { completion?(.permissionDenied) }
                }
            }
        }
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Plan

    private struct OneTimeItem {
        let id: String
        let title: String
        let alertTime: Date
    }

    private struct RepeatingItem {
        let id: String
        let title: String
        let components: DateComponents
    }

    private struct NotificationPlan {
        let repeating: [RepeatingItem]
        let oneTime: [OneTimeItem]
        let staleIdentifiers: [String]
    }

    private func buildPlan(in context: NSManagedObjectContext) -> NotificationPlan? {
        let calendar = Calendar.current
        let now = Date()

        guard let schedules = try? context.fetch(Schedule.fetchRequest()),
              let rules = try? context.fetch(RepeatSchedule.fetchRequest()) else {
            return nil
        }

        let staleIdentifiers = staleNotificationIdentifiers(schedules: schedules, rules: rules)
        let rulesById = Dictionary(uniqueKeysWithValues: rules.compactMap { rule in
            rule.id.map { ($0, rule) }
        })

        var repeating: [RepeatingItem] = []
        for rule in rules {
            guard let repeatType = rule.repeatType,
                  repeatingSolarTypes.contains(repeatType),
                  let repeatId = rule.id,
                  !isRepeatExpired(rule, now: now, calendar: calendar),
                  let sample = representativeSchedule(for: rule, in: schedules),
                  sample.alertEnabled,
                  let alertTime = sample.alertTime,
                  let title = sample.title ?? rule.title else {
                continue
            }

            guard let components = dateComponents(for: repeatType, alertTime: alertTime, calendar: calendar) else {
                continue
            }

            repeating.append(
                RepeatingItem(
                    id: Self.repeatNotificationId(repeatId),
                    title: title,
                    components: components
                )
            )
        }

        let repeatingRuleIds = Set(rulesById.values.filter {
            repeatingSolarTypes.contains($0.repeatType ?? "")
        }.compactMap(\.id))

        let oneTimeCandidates = schedules.filter { schedule in
            guard schedule.alertEnabled,
                  let alertTime = schedule.alertTime,
                  alertTime > now,
                  let id = schedule.id else {
                return false
            }

            if let repeatId = schedule.repeatId, repeatingRuleIds.contains(repeatId) {
                return false
            }
            return true
        }
        .sorted { ($0.alertTime ?? .distantFuture) < ($1.alertTime ?? .distantFuture) }

        let oneTimeSlotLimit = max(0, maxOneTimeSlots - repeating.count)
        let oneTime = oneTimeCandidates.prefix(oneTimeSlotLimit).compactMap { schedule -> OneTimeItem? in
            guard let id = schedule.id?.uuidString,
                  let title = schedule.title,
                  let alertTime = schedule.alertTime else { return nil }
            return OneTimeItem(id: id, title: title, alertTime: alertTime)
        }

        return NotificationPlan(
            repeating: repeating,
            oneTime: oneTime,
            staleIdentifiers: staleIdentifiers
        )
    }

    private func staleNotificationIdentifiers(
        schedules: [Schedule],
        rules: [RepeatSchedule]
    ) -> [String] {
        var ids = schedules.compactMap { $0.id?.uuidString }
        ids += rules.compactMap { rule in
            rule.id.map { Self.repeatNotificationId($0) }
        }
        return ids
    }

    private static func repeatNotificationId(_ repeatId: UUID) -> String {
        "repeat-\(repeatId.uuidString)"
    }

    private func isRepeatExpired(_ rule: RepeatSchedule, now: Date, calendar: Calendar) -> Bool {
        guard let endDate = rule.repeatEndDate else { return false }
        let endOfDay = calendar.startOfDay(for: endDate)
        let endBoundary = calendar.date(byAdding: .day, value: 1, to: endOfDay) ?? endDate
        return now >= endBoundary
    }

    private func representativeSchedule(for rule: RepeatSchedule, in schedules: [Schedule]) -> Schedule? {
        guard let repeatId = rule.id else { return nil }
        return schedules.first { $0.repeatId == repeatId && $0.alertEnabled }
    }

    private func dateComponents(
        for repeatType: String,
        alertTime: Date,
        calendar: Calendar
    ) -> DateComponents? {
        let hour = calendar.component(.hour, from: alertTime)
        let minute = calendar.component(.minute, from: alertTime)

        switch repeatType {
        case "매주":
            var components = DateComponents()
            components.weekday = calendar.component(.weekday, from: alertTime)
            components.hour = hour
            components.minute = minute
            return components
        case "매월":
            var components = DateComponents()
            components.day = calendar.component(.day, from: alertTime)
            components.hour = hour
            components.minute = minute
            return components
        case "매년 (양력)":
            var components = DateComponents()
            components.month = calendar.component(.month, from: alertTime)
            components.day = calendar.component(.day, from: alertTime)
            components.hour = hour
            components.minute = minute
            return components
        default:
            return nil
        }
    }

    // MARK: - Apply

    private func apply(
        plan: NotificationPlan,
        center: UNUserNotificationCenter,
        completion: ((NotificationScheduleResult) -> Void)?
    ) {
        var scheduledCount = 0

        for item in plan.repeating {
            if enqueueRepeating(center: center, id: item.id, title: item.title, components: item.components) {
                scheduledCount += 1
            }
        }

        for item in plan.oneTime {
            if enqueueOneTime(center: center, id: item.id, title: item.title, alertTime: item.alertTime) {
                scheduledCount += 1
            }
        }

        #if DEBUG
        print("알림 갱신: repeating \(plan.repeating.count)개, 1회성 \(plan.oneTime.count)개")
        #endif

        DispatchQueue.main.async {
            completion?(scheduledCount > 0 ? .scheduled : .skippedPast)
        }
    }

    @discardableResult
    private func enqueueOneTime(
        center: UNUserNotificationCenter,
        id: String,
        title: String,
        alertTime: Date
    ) -> Bool {
        let calendar = Calendar.current
        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alertTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        guard trigger.nextTriggerDate() != nil else { return false }

        let content = UNMutableNotificationContent()
        content.title = "일정 알림"
        content.body = title
        content.sound = .default

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            if let error {
                print("알림 등록 실패:", error.localizedDescription)
            }
        }
        return true
    }

    @discardableResult
    private func enqueueRepeating(
        center: UNUserNotificationCenter,
        id: String,
        title: String,
        components: DateComponents
    ) -> Bool {
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        guard trigger.nextTriggerDate() != nil else { return false }

        let content = UNMutableNotificationContent()
        content.title = "일정 알림"
        content.body = title
        content.sound = .default

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            if let error {
                print("반복 알림 등록 실패:", error.localizedDescription)
            }
        }
        return true
    }
}
