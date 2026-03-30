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
        
        // 다음 달 채우기 (42칸 또는 35칸 맞추기)
        let remainingCells = 42 - days.count  // 6주 = 42칸
        if remainingCells > 0 {
            let lastDay = days.last!
            for i in 1...remainingCells {
                if let next = calendar.date(byAdding: .day, value: i, to: lastDay) {
                    days.append(next)
                }
            }
        }
        
        return days
    }
    
    func lunarDayString(from date: Date) -> String {
        let lunar = Calendar(identifier: .chinese)
        let month = lunar.component(.month, from: date)
        let day = lunar.component(.day, from: date)
        return "\(month).\(day)"
    }
    
//    func lunarDayString(from date: Date) -> String {
//        let lunar = Calendar(identifier: .chinese)
//        let components = lunar.dateComponents([.month, .day], from: date)
//        
//        guard let month = components.month, let day = components.day else {
//            return ""
//        }
//        
//        // 음력 1일이면 월도 함께 표시
//        if day == 1 {
//            return "\(month).\(day)"  // 예: "10.1"
//        } else {
//            return "\(day)"  // 예: "15"
//        }
//    }
}
