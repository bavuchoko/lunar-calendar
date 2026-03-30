import SwiftUI

struct AddScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    var selectedDate: Date
    
    @State private var title = ""
    @State private var memo = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("제목 입력", text: $title)
                }
                Section("메모") {
                    TextField("메모 입력", text: $memo)
                }
            }
            .navigationTitle("새 일정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func save() {
        let newSchedule = Schedule(context: viewContext)
        newSchedule.id = UUID()
        newSchedule.title = title
        newSchedule.memo = memo
        newSchedule.date = selectedDate
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("저장 실패: \(error.localizedDescription)")
        }
    }
}
