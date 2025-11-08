import Foundation

// MARK: - API Response Models

struct HolidayResponse: Codable {
    let holidays: [HolidayItem]
    let year: Int
}

struct HolidayItem: Codable, Identifiable {
    let id: String
    let date: String        // "2025-01-01" 형식
    let name: String        // "신정"
    let isHoliday: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case name
        case isHoliday = "is_holiday"
    }
}

// MARK: - Holiday Manager

class HolidayManager: ObservableObject {
    @Published var holidays: [String: String] = [:]  // [날짜: 공휴일명]
    @Published var holidayList: [HolidayItem] = []   // 공휴일 목록
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let serverURL = "https://jongu.kr:19001/holiday"
    private let authToken = "abcabc"
    
    // 🔧 더미 데이터 사용 여부 (서버 준비되면 false로 변경)
    private let useDummyData = true
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cachedHolidays"
    private let lastUpdateKey = "holidayLastUpdate"
    private let lastYearKey = "holidayLastYear"
    
    init() {
        loadFromCache()
        checkAndUpdateIfNeeded()
    }
    
    // MARK: - UserDefaults 캐시 관리
    
    private func loadFromCache() {
        // 공휴일 딕셔너리 로드
        if let data = userDefaults.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([String: String].self, from: data) {
            self.holidays = cached
            
            // 리스트 형태로도 변환
            self.holidayList = cached.map { date, name in
                HolidayItem(id: date, date: date, name: name, isHoliday: true)
            }.sorted { $0.date < $1.date }
            
            print("캐시에서 공휴일 \(cached.count)개 로드")
        }
    }
    
    private func saveToCache() {
        if let encoded = try? JSONEncoder().encode(holidays) {
            userDefaults.set(encoded, forKey: cacheKey)
            userDefaults.set(Date(), forKey: lastUpdateKey)
            
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            userDefaults.set(currentYear, forKey: lastYearKey)
            
            print("공휴일 \(holidays.count)개 캐시에 저장")
        }
    }
    
    // MARK: - 자동 업데이트 로직
    
    private func checkAndUpdateIfNeeded() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let lastYear = userDefaults.integer(forKey: lastYearKey)
        
        // 연도가 바뀌었거나 캐시가 없으면 업데이트
        if lastYear < currentYear || holidays.isEmpty {
            print("연도 변경 감지 또는 캐시 없음 - 공휴일 데이터 업데이트")
            Task {
                await fetchHolidays()
            }
        }
    }
    
    // MARK: - 서버 API 호출 (또는 더미 데이터)
    
    func fetchHolidays() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 더미 데이터 사용
        if useDummyData {
            await loadDummyData()
            return
        }
        
        // 실제 서버 호출
        guard let url = URL(string: serverURL) else {
            await MainActor.run {
                isLoading = false
                errorMessage = "잘못된 서버 URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("서버 응답 코드: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "서버 오류: \(httpResponse.statusCode)"
                    }
                    return
                }
            }
            
            let decoder = JSONDecoder()
            let holidayResponse = try decoder.decode(HolidayResponse.self, from: data)
            
            await MainActor.run {
                self.holidays = Dictionary(uniqueKeysWithValues:
                    holidayResponse.holidays.map { ($0.date, $0.name) }
                )
                
                self.holidayList = holidayResponse.holidays.sorted { $0.date < $1.date }
                
                saveToCache()
                
                isLoading = false
                print("서버에서 \(holidayResponse.year)년 공휴일 \(self.holidays.count)개 로드 완료")
            }
            
        } catch {
            print("네트워크 오류: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
                errorMessage = "네트워크 오류: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 더미 데이터 로드
    
    private func loadDummyData() async {
        // 로딩 시뮬레이션 (0.5초 대기)
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let dummyHolidays = [
            HolidayItem(id: "2025-01-01", date: "2025-01-01", name: "신정", isHoliday: true),
            HolidayItem(id: "2025-01-28", date: "2025-01-28", name: "설날 연휴", isHoliday: true),
            HolidayItem(id: "2025-01-29", date: "2025-01-29", name: "설날", isHoliday: true),
            HolidayItem(id: "2025-01-30", date: "2025-01-30", name: "설날 연휴", isHoliday: true),
            HolidayItem(id: "2025-03-01", date: "2025-03-01", name: "삼일절", isHoliday: true),
            HolidayItem(id: "2025-03-03", date: "2025-03-03", name: "대체공휴일", isHoliday: true),
            HolidayItem(id: "2025-05-05", date: "2025-05-05", name: "어린이날", isHoliday: true),
            HolidayItem(id: "2025-05-06", date: "2025-05-06", name: "부처님오신날", isHoliday: true),
            HolidayItem(id: "2025-06-06", date: "2025-06-06", name: "현충일", isHoliday: true),
            HolidayItem(id: "2025-08-15", date: "2025-08-15", name: "광복절", isHoliday: true),
            HolidayItem(id: "2025-10-03", date: "2025-10-03", name: "개천절", isHoliday: true),
            HolidayItem(id: "2025-10-06", date: "2025-10-06", name: "추석 연휴", isHoliday: true),
            HolidayItem(id: "2025-10-07", date: "2025-10-07", name: "추석", isHoliday: true),
            HolidayItem(id: "2025-10-08", date: "2025-10-08", name: "추석 연휴", isHoliday: true),
            HolidayItem(id: "2025-10-09", date: "2025-10-09", name: "한글날", isHoliday: true),
            HolidayItem(id: "2025-12-25", date: "2025-12-25", name: "크리스마스", isHoliday: true)
        ]
        
        await MainActor.run {
            self.holidays = Dictionary(uniqueKeysWithValues:
                dummyHolidays.map { ($0.date, $0.name) }
            )
            
            self.holidayList = dummyHolidays.sorted { $0.date < $1.date }
            
            saveToCache()
            
            isLoading = false
            print("더미 데이터로 2025년 공휴일 \(self.holidays.count)개 로드 완료")
        }
    }
    
    // 수동 갱신
    func manualRefresh() async {
        print("수동 갱신 시작")
        await fetchHolidays()
    }
    
    // MARK: - Helper 메서드
    
    func isHoliday(_ date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return holidays.keys.contains(dateString)
    }
    
    func holidayName(for date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return holidays[dateString]
    }
    
    // 현재 연도 공휴일 목록 (정렬됨)
    func getCurrentYearHolidays() -> [HolidayItem] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        return holidayList.filter { item in
            item.date.starts(with: "\(currentYear)")
        }
    }
    
    // 특정 월의 공휴일 개수
    func holidayCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        let monthString = String(format: "%04d-%02d", year, month)
        
        return holidays.keys.filter { $0.starts(with: monthString) }.count
    }
}
