import SwiftUI
import CoreData


struct MonthView: View {
    @Binding var currentDate: Date
    var schedules: FetchedResults<Schedule>

    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDate: Date? = nil
    private let calendar = Calendar.current

    var body: some View {
        VStack {
            // 월 제목
            Text(monthTitle(for: currentDate))
                .font(.headline)
                .padding(.bottom, 8)

            // 요일 헤더
            dayOfWeekHeader()

            // 날짜 그리드
            GeometryReader { geo in
                let cellHeight = geo.size.height / 6
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                    ForEach(daysInMonth(for: currentDate), id: \.self) { date in
                        NavigationLink(destination:
                            ScheduleListView(selectedDate: date)
                                .environment(\.managedObjectContext, viewContext)
                        ) {
                            CalendarCellView(
                                date: date,
                                month: currentDate,
                                schedules: schedulesForDate(date),
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date()),
                                cellHeight: cellHeight
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 300)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers
    private func schedulesForDate(_ date: Date) -> [Schedule] {
        schedules.filter {
            guard let d = $0.date else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }

    private func monthTitle(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        fmt.dateFormat = "yyyy년 M월"
        return fmt.string(from: date)
    }

    private func dayOfWeekHeader() -> some View {
        let days = ["일", "월", "화", "수", "목", "금", "토"]
        return HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(day == "일" ? .red : (day == "토" ? .blue : .primary))
            }
        }
    }

    private func daysInMonth(for date: Date) -> [Date] {
        CalendarHelper.shared.daysInMonth(for: date)
    }
}

