import SwiftUI
import CoreData

struct CalendarContainerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var purchaseManager = PurchaseManager.shared

    // 연/월 + YearMonthPicker
    @State private var showingYearMonthPicker = false
    @State private var currentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var currentMonth: Int = Calendar.current.component(.month, from: Date())

    // 기존 상태들
    @State private var showLunar: Bool = false
    @StateObject private var holidayManager = HolidayManager()
    @State private var showHolidayList = false
    @State private var selectedDate: Date = Date()
    @State private var currentDate: Date = Date()

    @State private var showTools = false
    @State private var showScheduleList = false
    @State private var scheduleNavigationDay: ScheduleDayNavigation?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LunarCalendarView(
                    currentDate: $currentDate,
                    showLunar: $showLunar,
                    holidayManager: holidayManager,
                    selectedDate: $selectedDate,
                    scheduleNavigationDay: $scheduleNavigationDay
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !purchaseManager.isAdsRemoved {
                    BannerAdView(
                        adUnitID: "ca-app-pub-8998366944335616/8845674056"
                    )
                    .frame(height: 60)
                }

                HStack {
                    Spacer()

                    Button {
                        showHolidayList = true
                    } label: {
                        VStack {
                            Image(systemName: "party.popper")
                            Text("공휴일").font(.caption2)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            showLunar.toggle()
                        }
                    } label: {
                        VStack {
                            Image(systemName: showLunar ? "moon.fill" : "moon")
                                .font(.system(size: 22))
                            Text("음력").font(.caption2)
                        }
                    }

                    Spacer()

                    Button {
                        showScheduleList = true
                    } label: {
                        VStack {
                            Image(systemName: "calendar")
                            Text("일정").font(.caption2)
                        }
                    }

                    Spacer()

                    Button {
                        showTools = true
                    } label: {
                        VStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("도구").font(.caption2)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 6)
                .background(Color.white)
                .foregroundColor(.red)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                calendarHeader
                    .background(Color(.systemBackground))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EmptyView()
                }
            }
            .fullScreenCover(isPresented: $showingYearMonthPicker) {
                YearMonthPickerView(
                    selectedYear: Calendar.current.component(.year, from: currentDate),
                    selectedMonth: Calendar.current.component(.month, from: currentDate)
                ) { year, month in
                    if let newDate = Calendar.current.date(
                        from: DateComponents(year: year, month: month, day: 1)
                    ) {
                        selectedDate = newDate
                        currentDate = newDate
                        currentYear = year
                        currentMonth = month
                    }

                    showingYearMonthPicker = false
                }
                .environment(\.managedObjectContext, viewContext)
            }
            .fullScreenCover(isPresented: $showHolidayList) {
                HolidayListView(holidayManager: holidayManager)
            }
            .fullScreenCover(isPresented: $showScheduleList) {
                ScheduleAllListView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .fullScreenCover(isPresented: $showTools) {
                ToolsView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .navigationDestination(item: $scheduleNavigationDay) { day in
                ScheduleListView(selectedDate: day.date)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .onChange(of: currentDate) {
            let cal = Calendar.current
            let year = cal.component(.year, from: currentDate)
            currentYear = year
            currentMonth = cal.component(.month, from: currentDate)
        }
    }

    private var calendarHeader: some View {
        HStack {
            Button {
                scheduleNavigationDay = nil
                // 헤더 연도는 항상 currentDate 기준으로 맞춤
                currentYear = Calendar.current.component(.year, from: currentDate)
                currentMonth = Calendar.current.component(.month, from: currentDate)
                showingYearMonthPicker = true
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Text(verbatim: "\(Calendar.current.component(.year, from: currentDate))년")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.blue)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    CalendarContainerView()
        .environment(\.managedObjectContext, context)
}
