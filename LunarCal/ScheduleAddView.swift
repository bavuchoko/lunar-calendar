import SwiftUI
import CoreData

struct ScheduleAddView: View {
    let selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title: String = ""
    @State private var memo: String = ""
    @State private var repeatType: String = "없음"

    // 반복 일정은 종료일을 반드시 받는다.
    @State private var repeatEndDate: Date = Date()

    @State private var alertEnabled: Bool = false
    @State private var alertTime: Date = Date()

    private let repeatOptions = ["없음", "매주", "매월", "매년 (양력)", "매년 (음력)"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("날짜")) {
                    Text(dateString(from: selectedDate))
                        .font(.headline)
                }

                Section(header: Text("제목")) {
                    TextField("제목을 입력하세요", text: $title)
                }

                Section(header: Text("메모")) {
                    ZStack(alignment: .topLeading) {
                        if memo.isEmpty {
                            Text("메모를 입력하세요")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $memo)
                            .frame(minHeight: 100)
                    }
                }

                Section(header: Text("반복")) {
                    Picker("반복 옵션", selection: $repeatType) {
                        ForEach(repeatOptions, id: \.self) { Text($0) }
                    }

                    if repeatType != "없음" {
                        DatePicker(
                            "종료 날짜",
                            selection: $repeatEndDate,
                            in: selectedDate...,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                Section(header: Text("알림")) {
                    Toggle("알림 사용", isOn: $alertEnabled)
                    if alertEnabled {
                        DatePicker(
                            "알림 시각",
                            selection: $alertTime,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("일정 등록")
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .confirmationAction) {
                        scheduleSaveToolbarButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        scheduleSaveToolbarButton
                    }
                }
            }
        }
        .onAppear {
            if repeatEndDate < selectedDate {
                repeatEndDate = selectedDate
            }
            if let nine = Calendar.current.date(
                bySettingHour: 9, minute: 0, second: 0, of: selectedDate
            ) {
                alertTime = nine
            }
        }
    }

    private var scheduleSaveToolbarButton: some View {
        let isEnabled = !title.isEmpty
        return Button {
            guard isEnabled else { return }
            saveSchedule()
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(isEnabled ? Color.orange.opacity(0.95) : Color.gray.opacity(0.6))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.6)
        .accessibilityLabel("저장")
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }

    // MARK: - 저장 로직

    private func saveSchedule() {
        // 반복이면 종료일은 반드시 anchor(선택 날짜) 이상이어야 함
        if repeatType != "없음", repeatEndDate < selectedDate {
            repeatEndDate = selectedDate
        }

        // 1) 반복 없음: 단일 일정만 저장
        if repeatType == "없음" {
            let s = Schedule(context: viewContext)
            s.id = UUID()
            s.title = title
            s.memo = memo
            s.date = selectedDate
            s.startTime = nil
            s.endTime = nil
            s.alertEnabled = alertEnabled
            s.alertTime = alertEnabled ? merge(date: selectedDate, timeOfDay: alertTime) : nil
            s.isFromRepeat = false
            s.repeatId = nil
            s.repeatRule = nil

            if alertEnabled {
                NotificationManager.shared.scheduleNotification(for: s)
            }

        } else if repeatType == "매년 (음력)" {
            // 2-A) 음력 반복: 음력 정보 저장 + 올해/내년 생성

            let rule = RepeatSchedule(context: viewContext)
            rule.id = UUID()
            rule.title = title
            rule.anchorDate = selectedDate
            rule.repeatType = repeatType
            rule.repeatEndDate = repeatEndDate

            // 양력 selectedDate를 음력으로 변환해서 규칙에 저장
            if let lunar = LunarConverter.shared.solarToLunar(selectedDate) {
                rule.isLunar = true
                rule.lunarMonth = Int16(lunar.month)
                rule.lunarDay = Int16(lunar.day)
                rule.isLeapMonth = lunar.isLeap
            } else {
                rule.isLunar = false
            }

            // 음력 기준으로 종료일까지 occurrence 생성
            generateLunarOccurrencesUntilEndDate(from: rule, endDate: repeatEndDate)

        } else if repeatType == "매주" || repeatType == "매월" || repeatType == "매년 (양력)" {
            // 2-B) 주/월/양력 연 반복: 기존 로직

            let rule = RepeatSchedule(context: viewContext)
            rule.id = UUID()
            rule.title = title
            rule.anchorDate = selectedDate
            rule.repeatType = repeatType
            rule.repeatEndDate = repeatEndDate

            // 종료일까지 occurrence 생성
            generateOccurrencesUntilEndDate(from: rule, endDate: repeatEndDate)

        } else {
            // 3) 예외: 안전하게 단일 일정 처리
            let s = Schedule(context: viewContext)
            s.id = UUID()
            s.title = title
            s.memo = memo
            s.date = selectedDate
            s.startTime = nil
            s.endTime = nil
            s.alertEnabled = alertEnabled
            s.alertTime = alertEnabled ? merge(date: selectedDate, timeOfDay: alertTime) : nil
            s.isFromRepeat = false
            s.repeatId = nil
            s.repeatRule = nil

            if alertEnabled {
                NotificationManager.shared.scheduleNotification(for: s)
            }
        }

        do {
            try viewContext.save()
            print("일정 저장 완료")
        } catch {
            print("Core Data 저장 실패:", error.localizedDescription)
        }
    }

    // MARK: - 반복 인스턴스 생성 헬퍼

    /// 단일 occurrence 하나 생성 (Schedule + 관계 설정)
    private func createOccurrence(on date: Date, rule: RepeatSchedule) {
        let s = Schedule(context: viewContext)
        s.id = UUID()
        s.title = title
        s.memo = memo
        s.date = date
        s.startTime = nil
        s.endTime = nil
        s.alertEnabled = alertEnabled
        s.alertTime = alertEnabled ? merge(date: date, timeOfDay: alertTime) : nil
        s.isFromRepeat = true
        s.repeatId = rule.id
        s.repeatRule = rule

        rule.addToOccurrences(s)

        if alertEnabled {
            NotificationManager.shared.scheduleNotification(for: s)
        }
    }

    private func merge(date: Date, timeOfDay: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let time = calendar.dateComponents([.hour, .minute, .second], from: timeOfDay)
        var merged = DateComponents()
        merged.year = day.year
        merged.month = day.month
        merged.day = day.day
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = time.second
        return calendar.date(from: merged) ?? date
    }

    /// 종료일까지 반복 일정 생성 (주/월/양력 연)
    private func generateOccurrencesUntilEndDate(from rule: RepeatSchedule, endDate: Date) {
        let calendar = Calendar.current
        let anchor = rule.anchorDate ?? selectedDate
        let endBoundary = endDate
        if anchor > endBoundary { return }

        // anchor부터 생성
        createOccurrence(on: anchor, rule: rule)

        var current = nextOccurrenceDate(after: anchor, rule: rule, calendar: calendar)
        while current <= endBoundary {
            createOccurrence(on: current, rule: rule)
            current = nextOccurrenceDate(after: current, rule: rule, calendar: calendar)
        }
    }

    /// 음력 기준: 종료일까지 반복 일정 생성
    private func generateLunarOccurrencesUntilEndDate(from rule: RepeatSchedule, endDate: Date) {
        guard rule.isLunar,
              let anchor = rule.anchorDate else { return }

        let calendar = Calendar.current
        let endBoundary = endDate
        if anchor > endBoundary { return }

        let startYear = calendar.component(.year, from: anchor)
        let endYear = calendar.component(.year, from: endBoundary)

        for year in startYear...endYear {
            guard let solarDate = LunarConverter.shared.lunarToSolar(
                year: year,
                month: Int(rule.lunarMonth),
                day: Int(rule.lunarDay),
                isLeap: rule.isLeapMonth
            ) else { continue }

            guard solarDate >= anchor,
                  solarDate <= endBoundary else { continue }

            createOccurrence(on: solarDate, rule: rule)
        }
    }

    /// 규칙에 따라 다음 발생일 계산 (주/월/양력 연)
    private func nextOccurrenceDate(
        after date: Date,
        rule: RepeatSchedule,
        calendar: Calendar
    ) -> Date {
        switch rule.repeatType {
        case "매주":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case "매월":
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case "매년 (양력)":
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case "매년 (음력)":
            // 음력은 generateLunarOccurrencesForTwoYears에서 처리하므로 여기선 사용 안 함
            return date
        default:
            return date
        }
    }
}

#Preview {
    ScheduleAddView(selectedDate: Date())
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
}
