import SwiftUI
import CoreData

struct ScheduleAddView: View {
    let selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title: String = ""
    @State private var memo: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var repeatType: String = "없음"
    @State private var repeatYears: Int = 1        // 반복 연도 수
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

                Section(header: Text("시간")) {
                    DatePicker("시작", selection: $startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("종료", selection: $endTime, displayedComponents: [.hourAndMinute])
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
                        DatePicker("알림 시간", selection: $alertTime, displayedComponents: [.hourAndMinute])
                    }
                }
            }
            .navigationTitle("일정 등록")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveSchedule()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }

    func saveSchedule() {
        // 기준 일정 저장
        createSchedule(for: selectedDate)

        // 반복 일정 처리
        switch repeatType {
        case "매년 (양력)":
            createYearlySchedules(using: Calendar.current, count: repeatYears)
        case "매년 (음력)":
            createYearlySchedules(using: Calendar(identifier: .chinese), count: repeatYears)
        default:
            break
        }

        // 저장
        do {
            try viewContext.save()
            print(" 일정 및 반복 저장 완료")
        } catch {
            print(" Core Data 저장 실패:", error.localizedDescription)
        }
    }

    private func createSchedule(for date: Date) {
        let newSchedule = Schedule(context: viewContext)
        newSchedule.id = UUID()
        newSchedule.title = title
        newSchedule.memo = memo
        newSchedule.date = date
        newSchedule.startTime = startTime
        newSchedule.endTime = endTime
        newSchedule.repeatType = repeatType
        newSchedule.alertEnabled = alertEnabled
        newSchedule.alertTime = alertTime
        print("저장 일정:", dateString(from: date))
    }

    private func createYearlySchedules(using calendar: Calendar, count: Int) {
        let components = calendar.dateComponents([.month, .day], from: selectedDate)
        var currentYear = calendar.component(.year, from: selectedDate)

        for _ in 1...count {
            currentYear += 1
            var nextComponents = DateComponents()
            nextComponents.year = currentYear
            nextComponents.month = components.month
            nextComponents.day = components.day

            if let nextDate = calendar.date(from: nextComponents) {
                createSchedule(for: nextDate)
            }
        }
    }
}
#Preview {
    ScheduleAddView(selectedDate: Date())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
