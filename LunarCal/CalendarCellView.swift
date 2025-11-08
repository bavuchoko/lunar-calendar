import SwiftUI
import CoreData

struct CalendarCellView: View {
    var date: Date
    var month: Date
    var schedules: [Schedule]
    var isSelected: Bool
    var cellHeight: CGFloat
    var showLunar: Bool
    var holidayManager: HolidayManager
    
    private let calendar = Calendar.current
    private let helper = CalendarHelper.shared
    
    var body: some View {
        VStack(spacing: 2) {
            // 날짜
            Text("\(calendar.component(.day, from: date))")
                .font(.headline)
                .foregroundColor(colorForDate())
            
            // 공휴일 이름 또는 음력 (현재 달만 표시)
            if calendar.isDate(date, equalTo: month, toGranularity: .month) {
                if let holidayName = holidayManager.holidayName(for: date) {
                    Text(holidayName)
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.8))
                } else if showLunar {
                    Text(helper.lunarDayString(from: date))
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            
            // 일정 표시 (현재 달만)
            if calendar.isDate(date, equalTo: month, toGranularity: .month) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(schedules.prefix(3), id: \.id) { s in
                        Text(s.title ?? "")
                            .font(.system(size: 8))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if schedules.count > 3 {
                        Text("+\(schedules.count - 3)개")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }.frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight, alignment: .top)
        .padding(.top, 4)
        .background(isSelected ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    func colorForDate() -> Color {
        // 다른 달 날짜는 회색
        guard calendar.isDate(date, equalTo: month, toGranularity: .month) else {
            return .gray.opacity(0.3)
        }
        
        // 공휴일이면 빨간색
        if holidayManager.isHoliday(date) {
            return .red
        }
        
        // 주말 색상 처리
        let w = calendar.component(.weekday, from: date)
        if w == 1 { return .red }      // 일요일
        if w == 7 { return .blue }     // 토요일
        return .primary
    }
}
