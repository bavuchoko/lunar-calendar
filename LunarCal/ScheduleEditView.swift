import SwiftUI
import CoreData
import UserNotifications

struct ScheduleEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var schedule: Schedule

    @State private var title: String = ""
    @State private var memo: String = ""
    @State private var date: Date = Date()

    // 반복: 등록 화면처럼 전체 수정 허용 (없음/매주/매월/매년(양력)/매년(음력) + 종료일)
    @State private var repeatType: String = "없음"
    @State private var repeatEndDate: Date = Date()

    @State private var alertEnabled: Bool = false
    @State private var alertTime: Date = Date()
    @State private var showDeleteDialog: Bool = false
    @State private var showSaveDialog: Bool = false
    @State private var selectedCategoryId: UUID?

    @State private var initialRepeatType: String = "없음"
    @State private var initialRepeatEndDate: Date = Date()

    private enum SaveScope {
        case thisOccurrenceOnly
        case thisAndFuture
    }

    private let repeatOptions = ["없음", "매주", "매월", "매년 (양력)", "매년 (음력)"]

    private var isRepeatSchedule: Bool {
        schedule.repeatRule != nil || schedule.repeatId != nil
    }

    private var repeatSettingsChanged: Bool {
        repeatType != initialRepeatType
            || !Calendar.current.isDate(repeatEndDate, inSameDayAs: initialRepeatEndDate)
    }

    var body: some View {
        Form {
            Section(header: Text("제목")) {
                TextField("제목", text: $title)
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

            Section(header: Text("날짜")) {
                DatePicker("날짜", selection: $date, displayedComponents: .date)
            }

            ScheduleCategoryPickerSection(selectedCategoryId: $selectedCategoryId)

            Section(header: Text("반복")) {
                Picker("반복 옵션", selection: $repeatType) {
                    ForEach(repeatOptions, id: \.self) { Text($0) }
                }

                if repeatType != "없음" {
                    DatePicker(
                        "종료 날짜",
                        selection: $repeatEndDate,
                        in: date...,
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
        .navigationTitle("일정 수정")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteDialog = true
                } label: {
                    Image(systemName: "trash")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                let isEnabled = !title.isEmpty
                Button {
                    guard isEnabled else { return }
                    requestSave()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isEnabled ? Color.orange.opacity(0.95) : Color.gray.opacity(0.6))
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .opacity(isEnabled ? 1.0 : 0.6)
            }
        }
        .onAppear { loadData() }
        .confirmationDialog(
            schedule.repeatRule != nil || schedule.repeatId != nil ? "반복 일정 삭제" : "일정을 삭제할까요?",
            isPresented: $showDeleteDialog,
            titleVisibility: .visible
        ) {
            if schedule.repeatRule != nil || schedule.repeatId != nil {
                Button("해당 일자만 삭제", role: .destructive) {
                    deleteOnlyThisSchedule()
                }
                Button("해당 일자 이후 반복일정 모두 삭제", role: .destructive) {
                    deleteThisAndFutureSchedules()
                }
            } else {
                Button("삭제", role: .destructive) {
                    deleteOnlyThisSchedule()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제하면 복구할 수 없습니다.")
        }
        .confirmationDialog(
            "반복 일정 수정",
            isPresented: $showSaveDialog,
            titleVisibility: .visible
        ) {
            Button("해당 일자만 수정") {
                performSave(scope: .thisOccurrenceOnly)
            }
            Button("해당 일자 이후 반복일정 모두 수정") {
                performSave(scope: .thisAndFuture)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("변경 내용을 어떻게 적용할까요?")
        }
    }

    private func loadData() {
        // 기본 필드
        title = schedule.title ?? ""
        memo = schedule.memo ?? ""
        date = schedule.date ?? Date()
        selectedCategoryId = schedule.category?.id

        // 반복: repeatRule이 있으면 거기서 타입/종료일 가져옴
        if let rule = schedule.repeatRule {
            repeatType = rule.repeatType ?? "없음"
            repeatEndDate = rule.repeatEndDate ?? date
        } else {
            repeatType = "없음"
            repeatEndDate = date
        }

        initialRepeatType = repeatType
        initialRepeatEndDate = repeatEndDate

        // 알림
        alertEnabled = schedule.alertEnabled
        if let at = schedule.alertTime {
            alertTime = at
        } else if let nine = Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: date
        ) {
            alertTime = nine
        } else {
            alertTime = date
        }
    }

    private func requestSave() {
        if isRepeatSchedule {
            showSaveDialog = true
        } else {
            performSave(scope: .thisOccurrenceOnly)
        }
    }

    private func performSave(scope: SaveScope) {
        if repeatEndDate < date {
            repeatEndDate = date
        }

        if !isRepeatSchedule && repeatType != "없음" {
            applyRepeatChangeFromThisSchedule()
            updateSchedule(for: schedule, date: date)
            persistChanges(for: schedule)
            return
        }

        switch scope {
        case .thisOccurrenceOnly:
            if repeatSettingsChanged, repeatType == "없음" {
                schedule.isFromRepeat = false
                schedule.repeatId = nil
                schedule.repeatRule = nil
            }
            updateSchedule(for: schedule, date: date)

        case .thisAndFuture:
            if repeatSettingsChanged {
                applyRepeatChangeFromThisSchedule()
                updateSchedule(for: schedule, date: date)
            } else {
                updateSchedule(for: schedule, date: date)
                updateMatchingFutureOccurrences()
            }
        }

        persistChanges(for: schedule)
    }

    private func persistChanges(for schedule: Schedule) {
        do {
            try viewContext.save()

            if alertEnabled {
                NotificationManager.shared.scheduleNotification(for: schedule)
            } else {
                NotificationManager.shared.removeNotification(for: schedule)
            }

            dismiss()
        } catch {
            print("❌ 저장 실패:", error)
        }
    }

    private func updateSchedule(for schedule: Schedule, date: Date) {
        schedule.date = date
        schedule.startTime = nil
        schedule.endTime = nil
        applyEditableFields(to: schedule, occurrenceDate: date)
    }

    private func applyEditableFields(to schedule: Schedule, occurrenceDate: Date) {
        schedule.title = title
        schedule.memo = memo
        schedule.alertEnabled = alertEnabled
        schedule.alertTime = alertEnabled ? merge(date: occurrenceDate, timeOfDay: alertTime) : nil
        schedule.category = Schedule.category(with: selectedCategoryId, in: viewContext)
    }

    private func updateMatchingFutureOccurrences() {
        guard let repeatId = schedule.repeatId else { return }

        let calendar = Calendar.current
        let baseStart = calendar.startOfDay(for: schedule.date ?? date)

        let fetch: NSFetchRequest<Schedule> = Schedule.fetchRequest()
        fetch.predicate = NSPredicate(
            format: "repeatId == %@ AND date > %@",
            repeatId as CVarArg, baseStart as NSDate
        )

        guard let targets = try? viewContext.fetch(fetch) else { return }

        for occurrence in targets {
            guard let occurrenceDate = occurrence.date else { continue }
            applyEditableFields(to: occurrence, occurrenceDate: occurrenceDate)

            if alertEnabled {
                NotificationManager.shared.scheduleNotification(for: occurrence)
            } else {
                NotificationManager.shared.removeNotification(for: occurrence)
            }
        }
    }

    private func deleteOnlyThisSchedule() {
        NotificationManager.shared.removeNotification(for: schedule)
        viewContext.delete(schedule)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("❌ 삭제 실패:", error)
        }
    }

    private func deleteThisAndFutureSchedules() {
        let calendar = Calendar.current
        let baseDate = schedule.date ?? date
        let startOfBase = calendar.startOfDay(for: baseDate)

        // repeatId가 있으면, 같은 repeatId의 baseDate 이후(포함) occurrence들을 삭제
        if let repeatId = schedule.repeatId {
            let fetch: NSFetchRequest<Schedule> = Schedule.fetchRequest()
            fetch.predicate = NSPredicate(
                format: "repeatId == %@ AND date >= %@",
                repeatId as CVarArg, startOfBase as NSDate
            )

            do {
                let targets = try viewContext.fetch(fetch)
                for s in targets {
                    NotificationManager.shared.removeNotification(for: s)
                    viewContext.delete(s)
                }
            } catch {
                print("❌ 이후 반복 일정 조회/삭제 실패:", error)
            }

            // 규칙도 전날로 종료 처리 (남아있을 수 있는 다른 occurrence와 일관성 유지)
            if let rule = schedule.repeatRule,
               let dayBefore = calendar.date(byAdding: .day, value: -1, to: startOfBase) {
                rule.repeatEndDate = dayBefore
            }
        } else {
            // repeatId가 없으면 그냥 현재 일정만 삭제
            NotificationManager.shared.removeNotification(for: schedule)
            viewContext.delete(schedule)
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("❌ 삭제 실패:", error)
        }
    }

    /// 수정 화면에서 반복 옵션을 변경했을 때:
    /// - 기존 반복이면 "해당 날짜 이후" occurrence 삭제
    /// - repeatType == 없음: 규칙 종료 처리 + 현재 일정 단일화
    /// - repeatType != 없음: 규칙 업데이트(또는 생성) 후 종료일까지 재생성
    private func applyRepeatChangeFromThisSchedule() {
        let calendar = Calendar.current
        let baseDate = schedule.date ?? date
        let baseStartOfDay = calendar.startOfDay(for: baseDate)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: baseStartOfDay) else { return }

        // 1) 기존 반복이 있으면, 이후 occurrence 삭제
        if let existingRule = schedule.repeatRule,
           let existingRepeatId = existingRule.id {
            let fetch: NSFetchRequest<Schedule> = Schedule.fetchRequest()
            fetch.predicate = NSPredicate(
                format: "repeatId == %@ AND date >= %@",
                existingRepeatId as CVarArg, nextDay as NSDate
            )
            do {
                let future = try viewContext.fetch(fetch)
                for s in future {
                    NotificationManager.shared.removeNotification(for: s)
                    viewContext.delete(s)
                }
            } catch {
                print("❌ 이후 반복 일정 조회/삭제 실패:", error)
            }
        }

        // 2) 반복 해제
        if repeatType == "없음" {
            if let rule = schedule.repeatRule {
                // 규칙 의미도 맞게 종료일을 전날로 조정
                rule.repeatEndDate = calendar.date(byAdding: .day, value: -1, to: baseStartOfDay)
            }
            schedule.isFromRepeat = false
            schedule.repeatId = nil
            schedule.repeatRule = nil
            return
        }

        // 3) 반복 설정/변경: rule 확보(기존이 있으면 재사용, 없으면 생성)
        let rule: RepeatSchedule
        if let existing = schedule.repeatRule {
            rule = existing
        } else {
            let newRule = RepeatSchedule(context: viewContext)
            newRule.id = UUID()
            rule = newRule
        }

        // rule 업데이트
        rule.title = title
        rule.anchorDate = baseDate
        rule.repeatType = repeatType
        rule.repeatEndDate = repeatEndDate

        if repeatType == "매년 (음력)" {
            if let lunar = LunarConverter.shared.solarToLunar(baseDate) {
                rule.isLunar = true
                rule.lunarMonth = Int16(lunar.month)
                rule.lunarDay = Int16(lunar.day)
                rule.isLeapMonth = lunar.isLeap
            } else {
                rule.isLunar = false
            }
        } else {
            rule.isLunar = false
        }

        // 현재 일정도 반복 소속으로 전환/연결
        schedule.isFromRepeat = true
        schedule.repeatId = rule.id
        schedule.repeatRule = rule
        rule.addToOccurrences(schedule)

        // 4) 종료일까지 재생성 (현재 일정 "이후"부터)
        if rule.isLunar {
            generateLunarOccurrencesAfterAnchorUntilEndDate(rule: rule, anchor: baseDate, endDate: repeatEndDate)
        } else {
            generateOccurrencesAfterAnchorUntilEndDate(rule: rule, anchor: baseDate, endDate: repeatEndDate)
        }
    }

    private func generateOccurrencesAfterAnchorUntilEndDate(rule: RepeatSchedule, anchor: Date, endDate: Date) {
        let calendar = Calendar.current
        if anchor > endDate { return }

        var current = nextOccurrenceDate(after: anchor, rule: rule, calendar: calendar)
        while current <= endDate {
            let s = Schedule(context: viewContext)
            s.id = UUID()
            s.date = current
            s.startTime = nil
            s.endTime = nil
            s.isFromRepeat = true
            s.repeatId = rule.id
            s.repeatRule = rule
            applyEditableFields(to: s, occurrenceDate: current)
            rule.addToOccurrences(s)

            if alertEnabled {
                NotificationManager.shared.scheduleNotification(for: s)
            }

            current = nextOccurrenceDate(after: current, rule: rule, calendar: calendar)
        }
    }

    private func generateLunarOccurrencesAfterAnchorUntilEndDate(rule: RepeatSchedule, anchor: Date, endDate: Date) {
        guard rule.isLunar else { return }
        let calendar = Calendar.current
        if anchor > endDate { return }

        let startYear = calendar.component(.year, from: anchor)
        let endYear = calendar.component(.year, from: endDate)

        for year in startYear...endYear {
            guard let solarDate = LunarConverter.shared.lunarToSolar(
                year: year,
                month: Int(rule.lunarMonth),
                day: Int(rule.lunarDay),
                isLeap: rule.isLeapMonth
            ) else { continue }

            guard solarDate > anchor, solarDate <= endDate else { continue }

            let s = Schedule(context: viewContext)
            s.id = UUID()
            s.date = solarDate
            s.startTime = nil
            s.endTime = nil
            s.isFromRepeat = true
            s.repeatId = rule.id
            s.repeatRule = rule
            applyEditableFields(to: s, occurrenceDate: solarDate)
            rule.addToOccurrences(s)

            if alertEnabled {
                NotificationManager.shared.scheduleNotification(for: s)
            }
        }
    }

    private func nextOccurrenceDate(after date: Date, rule: RepeatSchedule, calendar: Calendar) -> Date {
        switch rule.repeatType {
        case "매주":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case "매월":
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case "매년 (양력)":
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        default:
            return date
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

}
