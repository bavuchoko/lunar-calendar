import SwiftUI
import CoreData

struct LunarCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Schedule.date, ascending: true),
            NSSortDescriptor(keyPath: \Schedule.createdAt, ascending: true)
        ],
        animation: .default
    ) private var schedules: FetchedResults<Schedule>

    @Binding var currentDate: Date
    @Binding var showLunar: Bool
    @ObservedObject var holidayManager: HolidayManager
    @Binding var selectedDate: Date
    @Binding var scheduleNavigationDay: ScheduleDayNavigation?
    /// 값이 바뀌면 이번 달로 스크롤합니다. (헤더의 "오늘" 버튼)
    var todayScrollToken = UUID()

    private let calendar = Calendar.current
    private let helper = CalendarHelper.shared

    @State private var months: [Date] = []
    @State private var scrollMonth: String?
    @State private var isProgrammaticScroll = false
    @State private var ignoreScrollSyncUntil = Date.distantPast
    @State private var scheduleDisplayToken = UUID()

    var body: some View {
        VStack(spacing: 0) {
            DayOfWeekHeaderView()

            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(months, id: \.timeIntervalSince1970) { month in
                        MonthSectionView(
                            month: month,
                            scheduleNavigationDay: $scheduleNavigationDay,
                            schedules: schedules,
                            showLunar: showLunar,
                            holidayManager: holidayManager,
                            scheduleDisplayToken: scheduleDisplayToken
                        )
                        .id(helper.monthKey(for: month))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollMonth, anchor: .top)
            .onAppear {
                rebuildMonths(around: currentDate)
                scrollToCurrentMonth(animated: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .lunarCalSchedulesDidChange)) { _ in
                bumpScheduleDisplay()
            }
            .onChange(of: scheduleNavigationDay) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    bumpScheduleDisplay()
                }
            }
            .onChange(of: currentDate) { _, newValue in
                handleExternalDateChange(newValue)
            }
            .onChange(of: scrollMonth) { _, newValue in
                syncCurrentDateFromScroll(newValue)
            }
            .onChange(of: todayScrollToken) {
                scrollToToday(using: proxy)
            }
            }
        }
    }

    private func bumpScheduleDisplay() {
        viewContext.processPendingChanges()
        scheduleDisplayToken = UUID()
    }

    private func rebuildMonths(around date: Date) {
        months = helper.months(around: date, past: 36, future: 36)
    }

    private func handleExternalDateChange(_ newValue: Date) {
        let key = helper.monthKey(for: newValue)
        if scrollMonth == key { return }

        let visibleKeys = Set(months.map { helper.monthKey(for: $0) })
        if !visibleKeys.contains(key) {
            rebuildMonths(around: newValue)
        }
        scrollToCurrentMonth(animated: false)
    }

    private func scrollToCurrentMonth(animated: Bool) {
        let key = helper.monthKey(for: currentDate)
        beginProgrammaticScroll()

        let apply = {
            scrollMonth = key
            endProgrammaticScroll(after: 0.45)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.25), apply)
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// scrollPosition 값은 빠르게 스크롤하면 실제 화면과 어긋날 수 있어,
    /// 값 비교 없이 ScrollViewReader로 직접 이동합니다.
    private func scrollToToday(using proxy: ScrollViewProxy) {
        let today = Date()
        let key = helper.monthKey(for: today)
        if month(forKey: key) == nil {
            rebuildMonths(around: today)
        }

        beginProgrammaticScroll()
        currentDate = today
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(key, anchor: .top)
            }
            scrollMonth = key
            endProgrammaticScroll(after: 0.45)
        }
    }

    private func beginProgrammaticScroll() {
        isProgrammaticScroll = true
        ignoreScrollSyncUntil = Date().addingTimeInterval(0.5)
    }

    private func endProgrammaticScroll(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isProgrammaticScroll = false
            ignoreScrollSyncUntil = Date().addingTimeInterval(0.15)
        }
    }

    private func syncCurrentDateFromScroll(_ newValue: String?) {
        guard !isProgrammaticScroll,
              Date() >= ignoreScrollSyncUntil,
              let newValue,
              let month = month(forKey: newValue) else { return }

        let newStart = helper.startOfMonth(for: month)
        let currentStart = helper.startOfMonth(for: currentDate)
        guard !calendar.isDate(newStart, equalTo: currentStart, toGranularity: .month) else { return }

        // LazyVStack 글리치로 한 번에 멀리 점프하는 값 무시
        let diff = calendar.dateComponents([.month], from: currentStart, to: newStart).month ?? 0
        guard abs(diff) <= 3 else { return }

        currentDate = newStart
    }

    private func month(forKey key: String) -> Date? {
        months.first { helper.monthKey(for: $0) == key }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    NavigationStack {
        LunarCalendarView(
            currentDate: .constant(Date()),
            showLunar: .constant(false),
            holidayManager: HolidayManager(),
            selectedDate: .constant(Date()),
            scheduleNavigationDay: .constant(nil)
        )
        .environment(\.managedObjectContext, context)
    }
}
