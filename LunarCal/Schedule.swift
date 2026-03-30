import Foundation

extension Schedule {
    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let baseDate = self.date else { return false }
        // 임시 구현: 같은 날이면 발생한 걸로 처리
        return calendar.isDate(baseDate, inSameDayAs: date)
    }
}
