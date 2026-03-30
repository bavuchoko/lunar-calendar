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

    // 일정 목록 시트
    @State private var showScheduleList = false
    @State private var showTools = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {

                    // 🔼 상단 헤더: "< 2025"
                    HStack {
                        // 왼쪽: 연도 버튼 (YearMonthPicker 열기)
                        Button {
                            // 버튼 눌렀을 때 상태를 오늘로 리셋
                            let today = Date()
                            currentYear  = Calendar.current.component(.year, from: today)
                            currentMonth = Calendar.current.component(.month, from: today)
                            currentDate  = today
                            selectedDate = today

                            showingYearMonthPicker = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "chevron.left")
                                Text(String(currentYear))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 88, alignment: .leading)
                        }

                        Spacer()

                        Button("오늘") {
                            let today = Date()
                            currentYear  = Calendar.current.component(.year, from: today)
                            currentMonth = Calendar.current.component(.month, from: today)
                            currentDate  = today
                            selectedDate = today
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    // 🔽 달력 본문
                    LunarCalendarView(
                        currentDate: $currentDate,
                        showLunar: $showLunar,
                        holidayManager: holidayManager,
                        selectedDate: $selectedDate
                    )

                    Spacer(minLength: 0)

                    // 🔽 광고 영역
                    if !purchaseManager.isAdsRemoved {
                        BannerAdView(
                            adUnitID: "ca-app-pub-8998366944335616/8089042227"
                        )
                        .frame(height: 60)
                    }

                    // 🔽 하단 버튼 바 (공휴일 / 음력)
                    HStack {
                        Spacer()

                        // 공휴일 → 목록 화면(새로고침은 목록 내 아이콘)
                        Button {
                            showHolidayList = true
                        } label: {
                            VStack {
                                Image(systemName: "party.popper")
                                Text("공휴일").font(.caption2)
                            }
                        }

                        Spacer()

                        // 음력 토글 버튼
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
                        
                        
                        
                        // 일정 목록 버튼
                        Button {
                            showScheduleList = true
                        } label: {
                            VStack {
                                Image(systemName: "calendar")
                                Text("일정").font(.caption2)
                            }
                        }

                        Spacer()

                        // 설정/도구 버튼
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

            }
            // 🔽 네비게이션 바 여백 최소화
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EmptyView() // 시스템 기본 타이틀/버튼 제거
                }
            }
            .fullScreenCover(isPresented: $showingYearMonthPicker) {
                // ✅ 여기서 "오늘" 기준 연/월 계산
                let today = Date()
                let todayYear  = Calendar.current.component(.year, from: today)
                let todayMonth = Calendar.current.component(.month, from: today)

                YearMonthPickerView(
                    selectedYear: todayYear,      // 항상 오늘 연도
                    selectedMonth: todayMonth     // 항상 오늘 월
                ) { year, month in
                    // 1) 사용자가 선택하면 상태 갱신
                    currentYear = year
                    currentMonth = month

                    if let newDate = Calendar.current.date(
                        from: DateComponents(year: year, month: month, day: 1)
                    ) {
                        selectedDate = newDate
                        currentDate  = newDate
                    }

                    showingYearMonthPicker = false
                }
            }
            .sheet(isPresented: $showHolidayList) {
                HolidayListView(holidayManager: holidayManager)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
            }
            .fullScreenCover(isPresented: $showScheduleList) {
                ScheduleAllListView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showTools) {
                ToolsView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        // iOS 17 스타일 onChange: 연도 반영
        .onChange(of: currentDate) {
            let cal = Calendar.current
            let year = cal.component(.year, from: currentDate)
            currentYear = year
            currentMonth = cal.component(.month, from: currentDate)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    CalendarContainerView()
        .environment(\.managedObjectContext, context)
}
