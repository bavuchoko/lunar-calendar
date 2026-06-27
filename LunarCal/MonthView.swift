import SwiftUI
import CoreData

struct ScheduleDayNavigation: Identifiable, Hashable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct MonthView: View {
    @Binding var currentDate: Date
    @Binding var scheduleNavigationDay: ScheduleDayNavigation?
    var schedules: FetchedResults<Schedule>
    var showLunar: Bool
    @ObservedObject var holidayManager: HolidayManager

    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // 월 제목
            Text(monthTitle(for: currentDate))
                .font(.title.bold()).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            // 요일 헤더
            dayOfWeekHeader()
                .padding(.bottom, 4)
            
            // 날짜 그리드
            let dates = daysInMonth(for: currentDate)
            let rowCount = dates.count / 7
            let cellHeight: CGFloat = 80

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(dates, id: \.timeIntervalSince1970) { date in
                    Button {
                        scheduleNavigationDay = ScheduleDayNavigation(date: date)
                    } label: {
                        CalendarCellView(
                            date: date,
                            month: currentDate,
                            schedules: schedulesForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date()),
                            cellHeight: cellHeight,
                            showLunar: showLunar,
                            holidayManager: holidayManager
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: CGFloat(rowCount) * cellHeight)
            .clipped()
            .padding(.horizontal)
        }
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
        fmt.dateFormat = "M월"
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
        .padding(.horizontal)
    }

    private func daysInMonth(for date: Date) -> [Date] {
        CalendarHelper.shared.daysInMonth(for: date)
    }
}

#Preview {
    // 미리보기용 래퍼 뷰
    struct MonthViewPreviewWrapper: View {
        @State private var currentDate = Date()
        @StateObject private var holidayManager = HolidayManager()
        @Environment(\.managedObjectContext) private var viewContext

        // 단순 FetchRequest로 FetchedResults<Schedule> 만들기
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Schedule.date, ascending: true)],
            animation: .default
        ) private var schedules: FetchedResults<Schedule>

        var body: some View {
            NavigationStack {
                MonthView(
                    currentDate: $currentDate,
                    scheduleNavigationDay: .constant(nil),
                    schedules: schedules,
                    showLunar: false,
                    holidayManager: holidayManager
                )
            }
        }
    }

    let context = PersistenceController.preview.container.viewContext
    return MonthViewPreviewWrapper()
        .environment(\.managedObjectContext, context)
}
