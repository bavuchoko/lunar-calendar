import SwiftUI
import CoreData

struct ScheduleChipDisplay: Identifiable, Hashable {
    let id: String
    let title: String
    let colorHex: String?
}

/// 연속 스크롤용 단일 월 섹션 (요일 헤더는 상위에 고정)
struct MonthSectionView: View {
    let month: Date
    @Binding var scheduleNavigationDay: ScheduleDayNavigation?
    var schedules: FetchedResults<Schedule>
    var showLunar: Bool
    @ObservedObject var holidayManager: HolidayManager
    var scheduleDisplayToken: UUID

    private let calendar = Calendar.current
    private let helper = CalendarHelper.shared
    private let cellHeight: CGFloat = 96

    var body: some View {
        // 토큰이 바뀌면 칩/공휴일 표시를 다시 그림 (스크롤 id는 건드리지 않음)
        let _ = scheduleDisplayToken
        let dates = CalendarHelper.shared.daysInMonth(for: month)
        let rowCount = max(dates.count / 7, 1)

        VStack(alignment: .leading, spacing: 0) {
            Text(CalendarHelper.shared.monthTitle(for: month))
                .font(.system(size: 28, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(dates, id: \.timeIntervalSince1970) { date in
                    Button {
                        scheduleNavigationDay = ScheduleDayNavigation(date: date)
                    } label: {
                        CalendarCellView(
                            date: date,
                            month: month,
                            chips: chipsForDate(date),
                            isSelected: calendar.isDateInToday(date),
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
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
        }
    }

    private func chipsForDate(_ date: Date) -> [ScheduleChipDisplay] {
        schedules
            .filter { schedule in
                guard let d = schedule.date else { return false }
                return calendar.isDate(d, inSameDayAs: date)
            }
            .sorted { lhs, rhs in
                let l = lhs.createdAt ?? .distantPast
                let r = rhs.createdAt ?? .distantPast
                return l < r
            }
            .map { schedule in
                let hex = schedule.category?.colorHex
                return ScheduleChipDisplay(
                    id: "\(schedule.objectID.uriRepresentation().absoluteString)-\(hex ?? "none")",
                    title: schedule.title ?? "",
                    colorHex: hex
                )
            }
    }
}

struct DayOfWeekHeaderView: View {
    var body: some View {
        let days = ["일", "월", "화", "수", "목", "금", "토"]
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(day == "일" ? .red : (day == "토" ? .blue : .secondary))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
}

struct ScheduleDayNavigation: Identifiable, Hashable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}
