import SwiftUI
import CoreData

struct CalendarCellView: View {
    var date: Date
    var month: Date
    var chips: [ScheduleChipDisplay]
    var isSelected: Bool
    var cellHeight: CGFloat
    var showLunar: Bool
    var holidayManager: HolidayManager

    private let calendar = Calendar.current
    private let helper = CalendarHelper.shared

    private var isInCurrentMonth: Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: date))")
                .font(.headline)
                .foregroundColor(isSelected && isInCurrentMonth ? .white : colorForDate())
                .frame(width: 32, height: 32)
                .background {
                    if isSelected && isInCurrentMonth {
                        Circle().fill(Color.red)
                    }
                }

            if isInCurrentMonth {
                if let holidayName = holidayManager.holidayName(for: date) {
                    Text(holidayName)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else if showLunar {
                    Text(helper.lunarDayString(from: date))
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }

            if isInCurrentMonth {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(chips.prefix(3)) { chip in
                        TagChipView(
                            text: chip.title,
                            hex: chip.colorHex,
                            fontSize: 12,
                            compact: true
                        )
                        .id(chip.id)
                    }
                    if chips.count > 3 {
                        Text("+\(chips.count - 3)개")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 0.5) // 인접 날짜 일정 사이 약 1px 간격
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight, alignment: .top)
        .padding(.top, 4)
        .cornerRadius(6)
    }

    func colorForDate() -> Color {
        guard isInCurrentMonth else {
            return .gray.opacity(0.3)
        }

        if holidayManager.isHoliday(date) {
            return .red
        }

        let w = calendar.component(.weekday, from: date)
        if w == 1 { return .red }
        if w == 7 { return .blue }
        return .primary
    }
}
