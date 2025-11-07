import Foundation

final class CalendarHelper {
    static let shared = CalendarHelper()
    private let calendar = Calendar.current

    func daysInMonth(for date: Date) -> [Date] {
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date] = []

        // 이전 달 채우기
        if firstWeekday > 1 {
            for i in stride(from: firstWeekday - 2, through: 0, by: -1) {
                if let prev = calendar.date(byAdding: .day, value: -i - 1, to: firstDay) {
                    days.append(prev)
                }
            }
        }

        // 현재 달
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }

        // 다음 달 채우기
        while days.count % 7 != 0 {
            if let next = calendar.date(byAdding: .day, value: days.count - range.count, to: firstDay) {
                days.append(next)
            }
        }

        return days
    }

    func lunarDayString(from date: Date) -> String {
        let lunar = Calendar(identifier: .chinese)
        let c = lunar.dateComponents([.month, .day], from: date)
        if let m = c.month, let d = c.day {
            return "\(m).\(d)"
        }
        return ""
    }
}
