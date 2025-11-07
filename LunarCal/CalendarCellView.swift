import SwiftUI
import CoreData

struct CalendarCellView: View {
    var date: Date
    var month: Date
    var schedules: [Schedule]
    var isSelected: Bool
    var cellHeight: CGFloat

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.headline)
                .foregroundColor(
                    calendar.isDate(date, equalTo: month, toGranularity: .month)
                    ? colorForWeekday()
                    : .gray.opacity(0.4)
                )

            Text(CalendarHelper.shared.lunarDayString(from: date))
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))

            VStack(alignment: .leading, spacing: 1) {
                ForEach(schedules.prefix(3), id: \.id) { s in
                    Text(s.title ?? "")
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if schedules.count > 3 {
                    Text("+\(schedules.count - 3)개")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight, alignment: .top)
        .padding(.top, 4)
        .background(isSelected ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    func colorForWeekday() -> Color {
        let w = calendar.component(.weekday, from: date)
        if w == 1 { return .red }
        if w == 7 { return .blue }
        return .primary
    }
}
