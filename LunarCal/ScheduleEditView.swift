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
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var repeatType: String = "없음"
    @State private var repeatYears: Int = 1
    @State private var alertEnabled: Bool = false
    @State private var alertTime: Date = Date()

    private let repeatOptions = ["없음", "매주", "매월", "매년 (양력)", "매년 (음력)"]

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

            Section(header: Text("날짜 / 시간")) {
                DatePicker("날짜", selection: $date, displayedComponents: .date)
                DatePicker("시작 시간", selection: $startTime, displayedComponents: [.hourAndMinute])
                DatePicker("종료 시간", selection: $endTime, displayedComponents: [.hourAndMinute])
            }

            Section(header: Text("반복")) {
                Picker("반복 옵션", selection: $repeatType) {
                    ForEach(repeatOptions, id: \.self) { Text($0) }
                }
                
                if repeatType.contains("매년") {
                    Stepper(value: $repeatYears, in: 1...20) {
                        Text("반복 연도 수: \(repeatYears)년")
                    }
                }
            }

            Section(header: Text("알림")) {
                Toggle("알림 사용", isOn: $alertEnabled)
                if alertEnabled {
                    DatePicker("알림 시각", selection: $alertTime, displayedComponents: [.hourAndMinute])
                }
            }
        }
        .navigationTitle("일정 수정")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)  // ⭐ 기본 Back 버튼 숨김
        .toolbar {
            // ⭐ 커스텀 뒤로 버튼
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Backa")
                    }
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") { saveSchedule() }
                    .disabled(title.isEmpty)
            }
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        title = schedule.title ?? ""
        memo = schedule.memo ?? ""
        date = schedule.date ?? Date()
        startTime = schedule.startTime ?? date
        endTime = schedule.endTime ?? date.addingTimeInterval(3600)
        repeatType = schedule.repeatType ?? "없음"
        repeatYears = 1
        alertEnabled = schedule.alertEnabled
        alertTime = schedule.alertTime ?? date
    }

    private func saveSchedule() {
        updateSchedule(for: schedule, date: date)

        switch repeatType {
        case "매년 (양력)":
            createYearlySchedules(using: Calendar.current, count: repeatYears)
        case "매년 (음력)":
            createYearlySchedules(using: Calendar(identifier: .chinese), count: repeatYears)
        default:
            break
        }

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
        schedule.title = title
        schedule.memo = memo
        schedule.date = date
        schedule.startTime = startTime
        schedule.endTime = endTime
        schedule.repeatType = repeatType
        schedule.alertEnabled = alertEnabled
        schedule.alertTime = alertTime
    }

    private func createYearlySchedules(using calendar: Calendar, count: Int) {
        let components = calendar.dateComponents([.month, .day], from: date)
        var currentYear = calendar.component(.year, from: date)

        for _ in 1...count {
            currentYear += 1
            var nextComponents = DateComponents()
            nextComponents.year = currentYear
            nextComponents.month = components.month
            nextComponents.day = components.day

            if let nextDate = calendar.date(from: nextComponents) {
                let newSchedule = Schedule(context: viewContext)
                newSchedule.id = UUID()
                newSchedule.title = title
                newSchedule.memo = memo
                newSchedule.date = nextDate
                newSchedule.startTime = startTime
                newSchedule.endTime = endTime
                newSchedule.repeatType = repeatType
                newSchedule.alertEnabled = alertEnabled
                newSchedule.alertTime = alertTime
            }
        }
    }

    private func dateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        fmt.dateFormat = "yyyy년 M월 d일 (E)"
        return fmt.string(from: date)
    }
}
