import SwiftUI

struct HolidayListView: View {
    @ObservedObject var holidayManager: HolidayManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if holidayManager.isLoading {
                    VStack {
                        ProgressView()
                        Text("공휴일 데이터 로딩 중...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                } else if holidayManager.holidayList.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("공휴일 데이터가 없습니다")
                            .font(.headline)
                        Button(action: {
                            Task {
                                await holidayManager.fetchHolidays()
                            }
                        }) {
                            Label("다시 시도", systemImage: "arrow.clockwise")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    List {
                        // 월별로 그룹핑된 공휴일
                        ForEach(groupedHolidays(), id: \.month) { group in
                            Section {
                                // 월 헤더 (크게)
                                Text(monthHeaderText(group.month))
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                
                                // 공휴일 목록
                                ForEach(group.holidays) { holiday in
                                    HStack(spacing: 12) {
                                        // 공휴일 이름
                                        Text(holiday.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        // 요일 + 날짜
                                        HStack(spacing: 6) {
                                            Text(getDayOnly(from: holiday.date))
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            
                                            Text(getDayOfWeek(from: holiday.date))
                                                .font(.subheadline)
                                                .foregroundColor(getDayOfWeekColor(from: holiday.date))
                                            
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .cornerRadius(8)
                                    }
                                    .padding(.vertical, 8)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("공휴일 목록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await holidayManager.manualRefresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                    }
                    .disabled(holidayManager.isLoading)
                }
            }
        }
    }
    
    // MARK: - 월별 그룹핑
    
    struct MonthGroup: Identifiable {
        let id = UUID()
        let month: String  // "2025-01"
        let holidays: [HolidayItem]
    }
    
    private func groupedHolidays() -> [MonthGroup] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // 현재 연도 공휴일만 필터링
        let currentYearHolidays = holidayManager.holidayList.filter { item in
            item.date.starts(with: "\(currentYear)")
        }
        
        // 월별로 그룹핑
        let grouped = Dictionary(grouping: currentYearHolidays) { holiday -> String in
            String(holiday.date.prefix(7))  // "2025-01"
        }
        
        // 정렬 및 MonthGroup으로 변환
        return grouped.keys.sorted().map { month in
            MonthGroup(
                month: month,
                holidays: grouped[month]?.sorted { $0.date < $1.date } ?? []
            )
        }
    }
    
    // MARK: - Helper Functions
    private func getDayOfWeekColor(from dateString: String) -> Color {
        let dayOfWeek = getDayOfWeek(from: dateString)
        
        if dayOfWeek == "(일)" {
            return .red
        } else if dayOfWeek == "(토)" {
            return .blue
        } else {
            return .black
        }
    }
    
    private func monthHeaderText(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        if components.count == 2 {
            let month = String(components[1])
            return "\(month)월"
        }
        return monthString
    }
    
    private func getDayOnly(from dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: dateString) {
            let calendar = Calendar.current
            let day = calendar.component(.day, from: date)
            return "\(day)일"
        }
        return ""
    }
    
    private func getDayOfWeek(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        let weekdays = ["(일)", "(월)", "(화)", "(수)", "(목)", "(금)", "(토)"]
        return weekdays[weekday - 1]
    }
}

#Preview {
    HolidayListView(holidayManager: HolidayManager())
}
