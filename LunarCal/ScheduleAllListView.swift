import SwiftUI
import CoreData

struct ScheduleAllListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Schedule.date, ascending: true),
            NSSortDescriptor(keyPath: \Schedule.createdAt, ascending: true)
        ],
        animation: .default
    )
    private var schedules: FetchedResults<Schedule>

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ScheduleCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \ScheduleCategory.name, ascending: true)
        ],
        animation: .default
    )
    private var categories: FetchedResults<ScheduleCategory>

    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = 0
    @State private var selectedCategoryFilterId: UUID?
    @State private var yearFilterOpen = false
    @State private var monthFilterOpen = false
    @State private var categoryFilterOpen = false

    private struct MonthSection: Identifiable {
        let id: String
        let title: String
        let schedules: [Schedule]
    }

    private var filteredSchedules: [Schedule] {
        let calendar = Calendar.current
        return schedules.filter { schedule in
            guard let date = schedule.date else { return false }

            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            guard year == selectedYear else { return false }
            if selectedMonth != 0, month != selectedMonth { return false }
            if let categoryId = selectedCategoryFilterId,
               schedule.category?.id != categoryId {
                return false
            }
            return true
        }
    }

    private var pickerYears: [Int] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let scheduleYears = schedules.compactMap { schedule -> Int? in
            guard let date = schedule.date else { return nil }
            return calendar.component(.year, from: date)
        }

        let minYear = min(scheduleYears.min() ?? currentYear, selectedYear, currentYear) - 1
        let maxYear = max(scheduleYears.max() ?? currentYear, selectedYear, currentYear) + 1
        return Array(minYear...maxYear).reversed()
    }

    private var screenTitle: String {
        if selectedMonth == 0 {
            return "\(selectedYear)년 일정"
        }
        return "\(selectedYear)년 \(selectedMonth)월 일정"
    }

    private var selectedCategoryFilterName: String {
        guard let selectedCategoryFilterId,
              let category = categories.first(where: { $0.id == selectedCategoryFilterId }) else {
            return "전체 태그"
        }
        return category.name ?? "태그"
    }

    private var selectedCategoryFilterColor: Color? {
        guard let selectedCategoryFilterId,
              let category = categories.first(where: { $0.id == selectedCategoryFilterId }) else {
            return nil
        }
        return ScheduleCategoryColor.color(from: category.colorHex)
    }

    private var ratioSourceSchedules: [Schedule] {
        let calendar = Calendar.current
        return schedules.filter { schedule in
            guard let date = schedule.date else { return false }

            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            guard year == selectedYear else { return false }
            if selectedMonth != 0, month != selectedMonth { return false }
            return true
        }
    }

    private var categoryRatioItems: [ScheduleCategoryRatioItem] {
        ScheduleCategoryRatioBuilder.items(
            from: ratioSourceSchedules,
            categories: Array(categories)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(KanbanTheme.background)

                if !categoryRatioItems.isEmpty {
                    ScheduleCategoryRatioBar(
                        items: categoryRatioItems,
                        totalCount: ratioSourceSchedules.count
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .background(KanbanTheme.background)
                }

                ZStack {
                    KanbanTheme.background.ignoresSafeArea()

                    if filteredSchedules.isEmpty {
                        emptyState
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 24) {
                                    ForEach(buildSections()) { section in
                                        monthBlock(section: section)
                                    }

                                    Text("\(screenTitle)은 날짜순입니다")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 8)
                                        .padding(.bottom, 24)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            }
                            .scrollIndicators(.visible)
                            .onAppear {
                                scrollToInitialMonth(using: proxy)
                            }
                            .onChange(of: selectedYear) {
                                scrollToInitialMonth(using: proxy)
                            }
                            .onChange(of: selectedMonth) {
                                scrollToInitialMonth(using: proxy)
                            }
                            .onChange(of: selectedCategoryFilterId) {
                                scrollToInitialMonth(using: proxy)
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(screenTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KanbanTheme.titleNavy)
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .navigationBarLeading) {
                        scheduleAllDismissButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        scheduleAllDismissButton
                    }
                }
            }
            .toolbarBackground(KanbanTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterSelectButton(
                    title: "\(selectedYear)년",
                    isActive: true,
                    isPresented: Binding(
                        get: { yearFilterOpen },
                        set: { newValue in
                            yearFilterOpen = newValue
                            if newValue {
                                monthFilterOpen = false
                                categoryFilterOpen = false
                            }
                        }
                    )
                ) {
                    FilterOptionList(scrollToID: selectedYear, isOpen: yearFilterOpen) {
                        ForEach(pickerYears, id: \.self) { year in
                            FilterOptionRow(
                                title: "\(year)년",
                                isSelected: selectedYear == year
                            ) {
                                selectedYear = year
                                yearFilterOpen = false
                            }
                            .id(year)
                        }
                    }
                }

                FilterSelectButton(
                    title: selectedMonth == 0 ? "전체 월" : "\(selectedMonth)월",
                    isActive: selectedMonth != 0,
                    isPresented: Binding(
                        get: { monthFilterOpen },
                        set: { newValue in
                            monthFilterOpen = newValue
                            if newValue {
                                yearFilterOpen = false
                                categoryFilterOpen = false
                            }
                        }
                    )
                ) {
                    FilterOptionList {
                        FilterOptionRow(
                            title: "전체 월",
                            isSelected: selectedMonth == 0
                        ) {
                            selectedMonth = 0
                            monthFilterOpen = false
                        }
                        ForEach(1...12, id: \.self) { month in
                            FilterOptionRow(
                                title: "\(month)월",
                                isSelected: selectedMonth == month
                            ) {
                                selectedMonth = month
                                monthFilterOpen = false
                            }
                        }
                    }
                }

                FilterSelectButton(
                    title: selectedCategoryFilterName,
                    color: selectedCategoryFilterColor,
                    isActive: selectedCategoryFilterId != nil,
                    isPresented: Binding(
                        get: { categoryFilterOpen },
                        set: { newValue in
                            categoryFilterOpen = newValue
                            if newValue {
                                yearFilterOpen = false
                                monthFilterOpen = false
                            }
                        }
                    )
                ) {
                    FilterOptionList {
                        FilterOptionRow(
                            title: "전체 태그",
                            isSelected: selectedCategoryFilterId == nil
                        ) {
                            selectedCategoryFilterId = nil
                            categoryFilterOpen = false
                        }
                        ForEach(categories, id: \.objectID) { category in
                            if let id = category.id {
                                FilterOptionRow(
                                    title: category.name ?? "이름 없음",
                                    color: ScheduleCategoryColor.color(from: category.colorHex),
                                    isSelected: selectedCategoryFilterId == id
                                ) {
                                    selectedCategoryFilterId = id
                                    categoryFilterOpen = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleAllDismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("닫기")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("\(screenTitle)에 등록된 일정이 없습니다")
                .font(.headline)
                .foregroundStyle(KanbanTheme.titleNavy)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func monthBlock(section: MonthSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(KanbanTheme.titleNavy)
                Spacer()
                Text("\(section.schedules.count)건")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Capsule())
            }
            .id(section.id)

            ForEach(Array(section.schedules.enumerated()), id: \.element.objectID) { index, schedule in
                NavigationLink(destination: ScheduleEditView(schedule: schedule)) {
                    ScheduleKanbanCard(
                        title: schedule.title ?? "제목 없음",
                        shortDate: scheduleShortDate(schedule),
                        primaryTag: schedule.cardPrimaryTag,
                        secondaryTag: schedule.cardSecondaryTag,
                        tagHex: schedule.cardTagHex
                    )
                    .id("\(schedule.objectID.uriRepresentation().absoluteString)-\(schedule.cardTagHex ?? "none")-\(schedule.cardPrimaryTag)")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func buildSections() -> [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSchedules) { (s: Schedule) -> Date in
            let d = s.date ?? Date()
            let comps = calendar.dateComponents([.year, .month], from: d)
            return calendar.date(from: comps) ?? d
        }

        let sortedMonths = grouped.keys.sorted()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월"

        return sortedMonths.map { monthStart in
            let id = monthId(for: monthStart)
            let title = formatter.string(from: monthStart)
            let items = (grouped[monthStart] ?? []).sorted {
                ($0.date ?? .distantPast) < ($1.date ?? .distantPast)
            }
            return MonthSection(id: id, title: title, schedules: items)
        }
    }

    private func scrollToInitialMonth(using proxy: ScrollViewProxy) {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())
        let targetDate: Date

        if selectedYear == currentYear,
           (selectedMonth == 0 || selectedMonth == currentMonth) {
            targetDate = Date()
        } else if let firstSection = buildSections().first,
                  let firstSchedule = firstSection.schedules.first,
                  let date = firstSchedule.date {
            targetDate = date
        } else {
            let month = selectedMonth == 0 ? 1 : selectedMonth
            targetDate = calendar.date(from: DateComponents(year: selectedYear, month: month, day: 1)) ?? Date()
        }

        let targetMonthId = monthId(for: targetDate)
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(targetMonthId, anchor: .top)
            }
        }
    }

    private func monthId(for date: Date) -> String {
        let calendar = Calendar.current
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }

    private func scheduleShortDate(_ s: Schedule) -> String {
        guard let d = s.date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d"
        return f.string(from: d)
    }
}
