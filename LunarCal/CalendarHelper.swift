import Foundation

final class CalendarHelper {
    static let shared = CalendarHelper()
    private let calendar = Calendar.current

    /// 해당 월 그리드용 날짜 배열 (앞쪽 이전달 패딩 + 당월 + 마지막 주만 다음달로 채움)
    func daysInMonth(for date: Date) -> [Date] {
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        var days: [Date] = []

        if firstWeekday > 1 {
            for i in stride(from: firstWeekday - 2, through: 0, by: -1) {
                if let prev = calendar.date(byAdding: .day, value: -i - 1, to: firstDay) {
                    days.append(prev)
                }
            }
        }

        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }

        while days.count % 7 != 0 {
            guard let last = days.last,
                  let next = calendar.date(byAdding: .day, value: 1, to: last) else { break }
            days.append(next)
        }

        return days
    }

    func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    func monthKey(for date: Date) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }

    func monthTitle(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        fmt.dateFormat = "M월"
        return fmt.string(from: date)
    }

    /// 기준 월 전후 범위의 월 시작일 배열
    func months(around date: Date, past: Int = 36, future: Int = 36) -> [Date] {
        let start = startOfMonth(for: date)
        guard let first = calendar.date(byAdding: .month, value: -past, to: start) else { return [start] }

        var result: [Date] = []
        for offset in 0...(past + future) {
            if let month = calendar.date(byAdding: .month, value: offset, to: first) {
                result.append(month)
            }
        }
        return result
    }

    func lunarDayString(from date: Date) -> String {
        let lunar = Calendar(identifier: .chinese)
        let month = lunar.component(.month, from: date)
        let day = lunar.component(.day, from: date)
        return "\(month).\(day)"
    }
}
