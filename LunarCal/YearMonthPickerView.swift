import SwiftUI
import CoreData

struct YearMonthPickerView: View {
    let selectedYear: Int
    let selectedMonth: Int
    let onSelect: (Int, Int) -> Void

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Schedule.date, ascending: true),
            NSSortDescriptor(keyPath: \Schedule.createdAt, ascending: true)
        ],
        animation: .default
    )
    private var schedules: FetchedResults<Schedule>

    @State private var isReady = false

    private let yearsRange: Int = 10

    private var yearRange: ClosedRange<Int> {
        (selectedYear - yearsRange)...(selectedYear + yearsRange)
    }

    /// 날짜(yyyy-MM-dd) → 표시 색 (태그 색, 없으면 기본 파랑)
    private var tagColorByDay: [String: Color] {
        let calendar = Calendar.current
        var buckets: [String: [Schedule]] = [:]

        for schedule in schedules {
            guard let date = schedule.date else { continue }
            let key = dayKey(date, calendar: calendar)
            buckets[key, default: []].append(schedule)
        }

        var result: [String: Color] = [:]
        for (key, list) in buckets {
            let ordered = list.sorted { lhs, rhs in
                let l = lhs.date ?? .distantFuture
                let r = rhs.date ?? .distantFuture
                if l != r { return l < r }
                let lc = lhs.createdAt ?? .distantPast
                let rc = rhs.createdAt ?? .distantPast
                return lc < rc
            }
            guard !ordered.isEmpty else { continue }

            if let hex = ordered.first(where: {
                let value = $0.category?.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !value.isEmpty
            })?.category?.colorHex {
                result[key] = ScheduleCategoryColor.color(from: hex)
            } else {
                result[key] = Color.blue
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    // LazyVStack은 높이 추정 오차로 현재 연도 스크롤이 어긋남 → VStack 사용
                    VStack(spacing: 32) {
                        ForEach(Array(yearRange), id: \.self) { year in
                            YearSectionView(
                                year: year,
                                selectedYear: selectedYear,
                                selectedMonth: selectedMonth,
                                tagColorByDay: tagColorByDay,
                                onSelect: onSelect
                            )
                            .id(year)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .opacity(isReady ? 1 : 0)
                .task(id: selectedYear) {
                    await scrollToSelectedYear(proxy: proxy)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @MainActor
    private func scrollToSelectedYear(proxy: ScrollViewProxy) async {
        isReady = false
        // 레이아웃이 잡힌 뒤 현재 연도 상단에 맞춤 (한 번으로는 어긋날 수 있어 재시도)
        for _ in 0..<3 {
            await Task.yield()
            proxy.scrollTo(selectedYear, anchor: .top)
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        proxy.scrollTo(selectedYear, anchor: .top)
        isReady = true
    }

    private func dayKey(_ date: Date, calendar: Calendar) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

private struct YearSectionView: View {
    let year: Int
    let selectedYear: Int
    let selectedMonth: Int
    let tagColorByDay: [String: Color]
    let onSelect: (Int, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(String(year))년")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(year == selectedYear ? .red : .primary)
                .padding(.leading, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 28) {
                ForEach(1...12, id: \.self) { month in
                    MonthMiniView(
                        year: year,
                        month: month,
                        isSelected: year == selectedYear && month == selectedMonth,
                        tagColorByDay: tagColorByDay
                    )
                    .onTapGesture {
                        onSelect(year, month)
                    }
                }
            }
        }
    }
}

private struct MonthMiniView: View {
    let year: Int
    let month: Int
    let isSelected: Bool
    let tagColorByDay: [String: Color]

    private let calendar = Calendar(identifier: .gregorian)

    private var todayDay: Int? {
        let today = Date()
        guard calendar.component(.year, from: today) == year,
              calendar.component(.month, from: today) == month else {
            return nil
        }
        return calendar.component(.day, from: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(month)월")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .red : .primary)

            let days = makeDays()
            let today = todayDay
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 16), spacing: 1),
                    count: 7
                ),
                spacing: 2
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayCell(day: day, isToday: day != 0 && day == today)
                }
            }
        }
        .padding(6)
    }

    @ViewBuilder
    private func dayCell(day: Int, isToday: Bool) -> some View {
        if day == 0 {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 18)
        } else {
            let tagColor = tagColorByDay[String(format: "%04d-%02d-%02d", year, month, day)]
            let hasHighlight = isToday || tagColor != nil
            let fillColor: Color = isToday ? .red : (tagColor ?? .clear)
            let textColor: Color = {
                if isToday { return .white }
                if let tagColor {
                    return ScheduleCategoryColor.contrastingTextColor(for: tagColor)
                }
                return .primary
            }()

            Text(String(day))
                .font(.system(size: 11, weight: hasHighlight ? .semibold : .regular))
                .foregroundColor(textColor)
                .frame(width: 18, height: 18)
                .background {
                    if hasHighlight {
                        Circle().fill(fillColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 18)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func makeDays() -> [Int] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmpty = weekday - 1
        return Array(repeating: 0, count: leadingEmpty) + Array(range)
    }
}
