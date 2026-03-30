import Foundation
import KoreanLunarSolarConverter

/// 양력 <-> (한국)음력 변환 유틸의 얇은 래퍼
final class LunarConverter {
    static let shared = LunarConverter()
    private init() {}

    struct LunarDate {
        let year: Int      // 음력 년
        let month: Int     // 음력 월
        let day: Int       // 음력 일
        let isLeap: Bool   // 윤달 여부
    }

    /// 양력 Date -> 음력 정보
    func solarToLunar(_ date: Date) -> LunarDate? {
        // 1. README: KoreanSolarToLunarConverter().lunarDate(fromSolar:)
        let converter = KoreanSolarToLunarConverter()
        guard let result = try? converter.lunarDate(fromSolar: date) else { return nil }

        // 2. result.date(=음력 Date)에서 년/월/일, 윤달 여부 추출
        let lunarDate = result.date
        let lunarCal = Calendar(identifier: .gregorian) // 라이브러리가 이미 한국 음력 계산을 해 줌
        let comps = lunarCal.dateComponents([.year, .month, .day], from: lunarDate)

        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }

        return LunarDate(
            year: y,
            month: m,
            day: d,
            isLeap: result.isIntercalation   // README의 KoreanDate.isIntercalation
        )
    }

    /// 음력(년/월/일/윤달) -> 양력 Date
    func lunarToSolar(year: Int, month: Int, day: Int, isLeap: Bool) -> Date? {
        // 1. 년/월/일로 음력 Date 하나 구성
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 0
        comps.minute = 0

        let lunarCal = Calendar(identifier: .gregorian)
        guard let lunarDate = lunarCal.date(from: comps) else { return nil }

        // 2. README: KoreanLunarToSolarConverter().solarDate(fromLunar:)
        let converter = KoreanLunarToSolarConverter()
        guard let result = try? converter.solarDate(fromLunar: lunarDate) else { return nil }

        // result.date 가 양력 Date
        return result.date
    }
}
