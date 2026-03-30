import Foundation

// MARK: - UI / 캐시용 모델

struct HolidayItem: Codable, Identifiable {
    let id: String
    let date: String
    let name: String
    let isHoliday: Bool

    enum CodingKeys: String, CodingKey {
        case id, date, name
        case isHoliday = "is_holiday"
    }
}

// MARK: - 공공데이터포털 특일정보 API (한국천문연구원) JSON

private struct PublicHolidayRoot: Decodable {
    let response: PublicHolidayEnvelope
}

private struct PublicHolidayEnvelope: Decodable {
    let header: PublicHolidayHeader
    let body: PublicHolidayBody?
}

private struct PublicHolidayHeader: Decodable {
    let resultCode: String
    let resultMsg: String?
}

private struct PublicHolidayBody: Decodable {
    let items: PublicHolidayItems?

    enum CodingKeys: String, CodingKey { case items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard c.contains(.items) else {
            self.items = nil
            return
        }
        if let str = try? c.decode(String.self, forKey: .items), str.isEmpty {
            self.items = nil
            return
        }
        self.items = try? c.decode(PublicHolidayItems.self, forKey: .items)
    }
}

private struct PublicHolidayItems: Decodable {
    let item: FlexibleHolidayItems

    enum CodingKeys: String, CodingKey { case item }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let flex = try? c.decode(FlexibleHolidayItems.self, forKey: .item) {
            item = flex
        } else {
            item = .empty
        }
    }
}

/// API가 item을 배열 또는 단일 객체로 줄 수 있음
private struct FlexibleHolidayItems: Decodable {
    let values: [RawPublicHoliday]

    static let empty = FlexibleHolidayItems(values: [])

    private init(values: [RawPublicHoliday]) {
        self.values = values
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let arr = try? c.decode([RawPublicHoliday].self) {
            values = arr
        } else if let one = try? c.decode(RawPublicHoliday.self) {
            values = [one]
        } else {
            values = []
        }
    }
}

private struct RawPublicHoliday: Decodable {
    let locdate: LocdateField
    let dateName: String
}

private enum LocdateField: Decodable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else {
            let s = try c.decode(String.self)
            self = .string(s)
        }
    }

    var yyyymmdd: String {
        switch self {
        case .int(let i):
            return String(format: "%08d", i)
        case .string(let s):
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: - Holiday Manager

/// 공공데이터포털 「한국천문연구원_특일 정보」 `getRestDeInfo` 사용
/// 인증키: `Info.plist` → `HolidayPublicDataServiceKey` (공공데이터포털에서 발급)
class HolidayManager: ObservableObject {
    @Published var holidays: [String: String] = [:]
    @Published var holidayList: [HolidayItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cachedHolidays"
    private let lastUpdateKey = "holidayLastUpdate"
    private let lastYearKey = "holidayLastYear"
    /// 수동 새로고침(툴바·다시 시도) 성공 시각 — 1주일에 한 번만 허용
    private let lastManualRefreshKey = "holidayLastManualRefreshDate"
    private let manualRefreshCooldown: TimeInterval = 7 * 24 * 60 * 60

    /// 수동 갱신이 쿨다운 중일 때 목록 화면에 표시
    @Published var refreshRateLimitMessage: String?

    private var serviceKey: String {
        func clean(_ raw: String) -> String {
            raw
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "HolidayPublicDataServiceKey") as? String, !clean(s).isEmpty {
            return clean(s)
        }
        // GENERATE_INFOPLIST_FILE 병합 이슈로 object가 비어도 infoDictionary에는 있을 수 있음
        if let s = Bundle.main.infoDictionary?["HolidayPublicDataServiceKey"] as? String, !clean(s).isEmpty {
            return clean(s)
        }
        return ""
    }

    /// 디코딩 키: `+` 등이 쿼리에서 깨지지 않도록 인코딩. 포털에서 **인코딩 키**를 붙여 넣은 경우(`%` 포함)는 이중 인코딩하지 않음.
    private static func percentEncodeQueryValue(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// 수동 쿼리 조립. `usePercentEncodingForKey == false`이면 키를 그대로 붙임(포털 **인코딩** 키 전체 붙여넣기 시).
    private func holidayManualURL(
        year: Int,
        month: Int,
        key: String,
        usePercentEncodingForKey: Bool
    ) -> URL? {
        guard !key.isEmpty else { return nil }

        let keyFragment: String
        if usePercentEncodingForKey {
            if key.contains("%") {
                keyFragment = "serviceKey=\(key)"
            } else {
                keyFragment = "serviceKey=\(Self.percentEncodeQueryValue(key))"
            }
        } else {
            keyFragment = "serviceKey=\(key)"
        }

        let query = [
            keyFragment,
            "solYear=\(year)",
            "solMonth=\(String(format: "%02d", month))",
            "numOfRows=100",
            "pageNo=1",
            "_type=json"
        ].joined(separator: "&")

        return URL(string: apiBase + "?" + query)
    }

    /// 401 대응: 여러 방식으로 URL을 만들어 순서대로 시도
    private func holidayAPICandidateURLs(year: Int, month: Int) -> [URL] {
        let key = serviceKey
        guard !key.isEmpty else { return [] }

        var seen = Set<String>()
        var urls: [URL] = []
        func append(_ u: URL?) {
            guard let u = u, !seen.contains(u.absoluteString) else { return }
            seen.insert(u.absoluteString)
            urls.append(u)
        }

        append(holidayManualURL(year: year, month: month, key: key, usePercentEncodingForKey: true))
        append(holidayManualURL(year: year, month: month, key: key, usePercentEncodingForKey: false))
        append(holidayAPIURLUsingComponents(year: year, month: month))
        return urls
    }

    /// 디코딩 키용 대안: 시스템이 `serviceKey`를 쿼리로 인코딩 (401 시 수동 URL과 함께 재시도)
    private func holidayAPIURLUsingComponents(year: Int, month: Int) -> URL? {
        var components = URLComponents(string: apiBase)!
        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: serviceKey),
            URLQueryItem(name: "solYear", value: String(year)),
            URLQueryItem(name: "solMonth", value: String(format: "%02d", month)),
            URLQueryItem(name: "numOfRows", value: "100"),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "_type", value: "json")
        ]
        return components.url
    }

    private let apiBase = "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo"

    init() {
        loadFromCache()
        checkAndUpdateIfNeeded()
    }

    // MARK: - UserDefaults 캐시

    private func loadFromCache() {
        if let data = userDefaults.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([String: String].self, from: data) {
            self.holidays = cached
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

    private func checkAndUpdateIfNeeded() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let lastYear = userDefaults.integer(forKey: lastYearKey)

        if lastYear < currentYear || holidays.isEmpty {
            print("연도 변경 감지 또는 캐시 없음 - 공휴일 데이터 업데이트")
            Task {
                await fetchHolidays(recordManualRefresh: false)
            }
        }
    }

    // MARK: - 공공 API

    /// `recordManualRefresh`: 툴바 새로고침·다시 시도 등 사용자가 직접 요청한 갱신(성공 시 7일 쿨다운 기록)
    func fetchHolidays(recordManualRefresh: Bool = false) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            if recordManualRefresh {
                refreshRateLimitMessage = nil
            }
        }

        if recordManualRefresh, !isManualRefreshAllowed {
            await MainActor.run {
                isLoading = false
                refreshRateLimitMessage = "API 할당량 제한으로 빈번한 업데이트는 허용되지 않습니다."
            }
            return
        }

        guard !serviceKey.isEmpty else {
            await MainActor.run {
                isLoading = false
                errorMessage = "공공데이터포털 인증키가 없습니다. Info.plist의 HolidayPublicDataServiceKey를 설정하세요."
            }
            return
        }

        let year = Calendar.current.component(.year, from: Date())

        var merged: [String: String] = [:]

        for month in 1...12 {
            do {
                let monthMap = try await fetchRestDeInfo(year: year, month: month)
                for (k, v) in monthMap {
                    merged[k] = v
                }
            } catch {
                let ns = error as NSError
                let hint: String
                if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorBadServerResponse {
                    hint = " (인증키는 포털의 디코딩 키 또는 인코딩 키 중 하나만 넣고, 앞뒤 공백·줄바꿈이 없는지 확인하세요.)"
                } else {
                    hint = ""
                }
                print("공휴일 API (\(year)-\(month)) 오류: \(error.localizedDescription)\(hint)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = "공휴일 조회 실패: \(error.localizedDescription)\(hint)"
                }
                return
            }
        }

        let list = merged.map { date, name in
            HolidayItem(id: date, date: date, name: name, isHoliday: true)
        }.sorted { $0.date < $1.date }

        await MainActor.run {
            self.holidays = merged
            self.holidayList = list
            saveToCache()
            if recordManualRefresh {
                userDefaults.set(Date(), forKey: lastManualRefreshKey)
            }
            isLoading = false
            print("공공데이터 API에서 \(year)년 공휴일 \(merged.count)개 로드 완료")
        }
    }

    /// 월별 `getRestDeInfo` 호출 → [yyyy-MM-dd: 공휴일명]
    private func fetchRestDeInfo(year: Int, month: Int) async throws -> [String: String] {
        let key = serviceKey
        guard !key.isEmpty else { throw URLError(.badURL) }

        let candidateURLs = holidayAPICandidateURLs(year: year, month: month)
        guard !candidateURLs.isEmpty else { throw URLError(.badURL) }

        for (index, url) in candidateURLs.enumerated() {
            do {
                return try await fetchRestDeInfoData(from: url)
            } catch {
                let ns = error as NSError
                let retry401 = ns.domain == "HolidayPublicAPI" && ns.code == 401 && index + 1 < candidateURLs.count
                if retry401 {
                    #if DEBUG
                    print("공휴일 API 401 → 대안 URL로 재시도 (\(index + 1)/\(candidateURLs.count))")
                    #endif
                    continue
                }
                throw error
            }
        }
        throw NSError(
            domain: "HolidayPublicAPI",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "공휴일 요청에 실패했습니다."]
        )
    }

    private static func makeHTTPError(statusCode: Int, body: Data) -> NSError {
        let snippet = String(data: body.prefix(500), encoding: .utf8) ?? ""
        if statusCode == 401 {
            let msg = """
            인증 실패(HTTP 401). 활용신청이 승인돼 있어도 아래 때문에 401이 날 수 있습니다.
            • 포털 API 상세 → 일반 인증키에서 **인코딩(Encoding)** 값을 복사해 Info.plist에 넣어 보세요(디코딩만 넣었다면).
            • Xcode Target → Info → 사용자 정의 속성에 `HolidayPublicDataServiceKey`가 있는지 확인하세요. (GENERATE_INFOPLIST_FILE 사용 시 plist만으로는 번들에 안 들어가는 경우가 있습니다.)
            • 이용 기간 시작일 이후인지, 키를 재발급했다면 새 키로 교체했는지 확인하세요.
            서버 응답: \(snippet)
            """
            return NSError(domain: "HolidayPublicAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return NSError(
            domain: "HolidayPublicAPI",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode). 응답: \(snippet)"]
        )
    }

    private func fetchRestDeInfoData(from url: URL) async throws -> [String: String] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // 일부 게이트웨이는 기본 UA를 거부하는 사례가 있어 브라우저에 가깝게 설정
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw Self.makeHTTPError(statusCode: http.statusCode, body: data)
        }

        let root: PublicHolidayRoot
        do {
            root = try JSONDecoder().decode(PublicHolidayRoot.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(800), encoding: .utf8) ?? "(바이너리)"
            throw NSError(
                domain: "HolidayPublicAPI",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "JSON 파싱 실패: \(error.localizedDescription). 응답 앞부분: \(snippet)"
                ]
            )
        }
        let code = root.response.header.resultCode.trimmingCharacters(in: .whitespaces)

        guard code == "00" else {
            let msg = root.response.header.resultMsg ?? "알 수 없는 오류"
            throw NSError(
                domain: "HolidayPublicAPI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API 오류 (\(code)): \(msg)"]
            )
        }

        guard let items = root.response.body?.items else {
            return [:]
        }

        var map: [String: String] = [:]
        for raw in items.item.values {
            let ymd = raw.locdate.yyyymmdd
            guard ymd.count == 8 else { continue }
            let dashed = Self.dashedYMD(ymd)
            let name = raw.dateName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            map[dashed] = name
        }
        return map
    }

    private static func dashedYMD(_ yyyymmdd: String) -> String {
        let y = yyyymmdd.prefix(4)
        let m = yyyymmdd.dropFirst(4).prefix(2)
        let d = yyyymmdd.dropFirst(6).prefix(2)
        return "\(y)-\(m)-\(d)"
    }

    /// 툴바 새로고침(7일 1회 제한은 `fetchHolidays(recordManualRefresh: true)`에서 처리)
    func manualRefresh() async {
        print("수동 갱신 시작")
        await fetchHolidays(recordManualRefresh: true)
    }

    private var isManualRefreshAllowed: Bool {
        guard let last = userDefaults.object(forKey: lastManualRefreshKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= manualRefreshCooldown
    }

    // MARK: - Helpers

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

    func getCurrentYearHolidays() -> [HolidayItem] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return holidayList.filter { item in
            item.date.starts(with: "\(currentYear)")
        }
    }

    func holidayCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let monthString = String(format: "%04d-%02d", year, month)
        return holidays.keys.filter { $0.starts(with: monthString) }.count
    }
}
