import SwiftUI

struct YearMonthPickerView: View {
    let selectedYear: Int
    let selectedMonth: Int
    let onSelect: (Int, Int) -> Void   // (year, month)

    @Environment(\.dismiss) private var dismiss

    // 시작 기준 연도 (현재 선택 연도 중심)
    @State private var baseYear: Int

    init(
        selectedYear: Int,
        selectedMonth: Int,
        onSelect: @escaping (Int, Int) -> Void
    ) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.onSelect = onSelect
        _baseYear = State(initialValue: selectedYear)
    }

    private let yearsRange: Int = 10   // 위아래 몇 년까지 보여줄지

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 32) {
                        ForEach((baseYear - yearsRange)...(baseYear + yearsRange), id: \.self) { year in
                            YearSectionView(
                                year: year,
                                selectedYear: selectedYear,
                                selectedMonth: selectedMonth,
                                onSelect: onSelect
                            )
                            .id(year)   // 🔴 이 id를 기준으로 스크롤
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .onAppear {
                    // 🔴 피커가 뜰 때 선택 연도로 스크롤 위치 맞추기
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(selectedYear, anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("\(String(baseYear))년")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

/// 한 해(12개월) 블록
private struct YearSectionView: View {
    let year: Int
    let selectedYear: Int
    let selectedMonth: Int
    let onSelect: (Int, Int) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 연도 타이틀
            Text("\(String(year))년")
                .font(.largeTitle.bold())
                .foregroundColor(year == selectedYear ? .red : .primary)
                .padding(.leading, 8)

            // 3 x 4 월 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 24) {
                ForEach(1...12, id: \.self) { month in
                    MonthMiniView(
                        year: year,
                        month: month,
                        isSelected: year == selectedYear && month == selectedMonth
                    )
                    .onTapGesture {
                        onSelect(year, month)
                    }
                }
            }
        }
    }
}

/// 작은 월 달력 (숫자만 나열)
private struct MonthMiniView: View {
    let year: Int
    let month: Int
    let isSelected: Bool

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(month)월")
                .font(.headline)
                .foregroundColor(isSelected ? .red : .primary)

            // 요일 헤더는 생략하고 숫자만 간단히
            let days = makeDays()
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 14), spacing: 1),
                    count: 7
                ),
                spacing: 1
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day == 0 ? "" : String(day))
                        .font(.system(size: 9))
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(isSelected ? .red : .primary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.red.opacity(0.12) : Color.clear)
        )
    }

    /// 해당 월의 달력 숫자 배열 (앞의 빈칸은 0)
    private func makeDays() -> [Int] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay) // 1=일
        let leadingEmpty = weekday - 1

        let days = Array(range)
        return Array(repeating: 0, count: leadingEmpty) + days
    }
}
