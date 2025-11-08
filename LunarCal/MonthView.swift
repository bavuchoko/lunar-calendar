import SwiftUI
import CoreData

struct MonthView: View {
    @Binding var currentDate: Date
    var schedules: FetchedResults<Schedule>
    var showLunar: Bool
    @ObservedObject var holidayManager: HolidayManager
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDate: Date? = nil
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // 월 제목
            Text(monthTitle(for: currentDate))
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            // 요일 헤더
            dayOfWeekHeader()
                .padding(.bottom, 4)
            
            // 날짜 그리드
            let dates = daysInMonth(for: currentDate)
            let rowCount = dates.count / 7
            let cellHeight: CGFloat = 80
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    // NavigationLink를 CalendarCellView 밖에서 감싸기
                    NavigationLink(destination:
                        ScheduleListView(selectedDate: date)
                            .environment(\.managedObjectContext, viewContext)
                    ) {
                        CalendarCellView(
                            date: date,
                            month: currentDate,
                            schedules: schedulesForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date()),
                            cellHeight: cellHeight,
                            showLunar: showLunar,
                            holidayManager: holidayManager
                        )
                        .contentShape(Rectangle())  // 전체 영역 클릭 가능
                    }
                    .buttonStyle(.plain)  // 기본 버튼 스타일 제거
                }
            }
            .frame(height: CGFloat(rowCount) * cellHeight)
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
        .padding(.horizontal)
    }
    
    private func daysInMonth(for date: Date) -> [Date] {
        CalendarHelper.shared.daysInMonth(for: date)
    }
}
