import Foundation
import CoreData

extension Schedule {
    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let baseDate = self.date else { return false }
        // 임시 구현: 같은 날이면 발생한 걸로 처리
        return calendar.isDate(baseDate, inSameDayAs: date)
    }

    static func category(with id: UUID?, in context: NSManagedObjectContext) -> ScheduleCategory? {
        guard let id else { return nil }
        let request: NSFetchRequest<ScheduleCategory> = ScheduleCategory.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
