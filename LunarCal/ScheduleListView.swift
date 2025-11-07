import SwiftUI
import CoreData

struct ScheduleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddSheet = false
    
    var selectedDate: Date
    
    // 해당 날짜의 일정만 필터링
    @FetchRequest var schedules: FetchedResults<Schedule>
    
    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        
        // 날짜 범위 (해당 날짜 00:00 ~ 23:59)
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<Schedule> = Schedule.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Schedule.date, ascending: true)]
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        _schedules = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        VStack {
            if schedules.isEmpty {
                Text("일정이 없습니다.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(schedules) { schedule in
                        NavigationLink(destination: ScheduleEditView(schedule: schedule)) {
                            VStack(alignment: .leading) {
                                Text(schedule.title ?? "제목 없음")
                                    .font(.headline)
                                if let memo = schedule.memo, !memo.isEmpty {
                                    Text(memo)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSchedule)
                }
            }
        }
        .navigationTitle(selectedDate.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet.toggle()
                } label: {
                    Label("추가", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ScheduleAddView(selectedDate: selectedDate)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private func deleteSchedule(offsets: IndexSet) {
        withAnimation {
            offsets.map { schedules[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print("삭제 실패: \(error.localizedDescription)")
            }
        }
    }
}
