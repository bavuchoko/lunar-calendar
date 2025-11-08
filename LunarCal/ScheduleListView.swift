import SwiftUI
import CoreData

struct ScheduleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false
    
    var selectedDate: Date
    
    @FetchRequest var schedules: FetchedResults<Schedule>
    
    private let colors: [Color] = [.purple, .green, .red, .orange, .blue, .pink, .yellow]
    
    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<Schedule> = Schedule.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Schedule.date, ascending: true)]
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        _schedules = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        ScrollView {
            if schedules.isEmpty {
        
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("일정이 없습니다.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 150)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(schedules.enumerated()), id: \.element.id) { index, schedule in
                        SwipeableScheduleRow(
                            schedule: schedule,
                            color: colors[index % colors.count],
                            onDelete: { deleteSchedule(schedule) }
                        )
                        
                        if index < schedules.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 50)  // ⭐ 상단 패딩 50 추가
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(dateString(from: selectedDate))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet.toggle()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ScheduleAddView(selectedDate: selectedDate)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    
    private func deleteSchedule(_ schedule: Schedule) {
        withAnimation {
            viewContext.delete(schedule)
            do {
                try viewContext.save()
            } catch {
                print("삭제 실패: \(error.localizedDescription)")
            }
        }
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
}

// 스와이프 가능한 행 뷰
struct SwipeableScheduleRow: View {
    let schedule: Schedule
    let color: Color
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    private let deleteButtonWidth: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 삭제 버튼 배경
            HStack {
                Spacer()
                Button(action: {
                    onDelete()
                }) {
                    VStack {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                        Text("삭제")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: deleteButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                }
            }
            
            // 일정 내용
            NavigationLink(destination: ScheduleEditView(schedule: schedule)) {
                ScheduleRowView(schedule: schedule, color: color)
            }
            .buttonStyle(.plain)
            .background(Color.white)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        if translation < 0 {
                            offset = max(translation, -deleteButtonWidth)
                        } else if offset < 0 {
                            offset = min(0, offset + translation)
                        }
                        isSwiping = true
                    }
                    .onEnded { gesture in
                        isSwiping = false
                        if offset < -deleteButtonWidth / 2 {
                            withAnimation(.spring()) {
                                offset = -deleteButtonWidth
                            }
                        } else {
                            withAnimation(.spring()) {
                                offset = 0
                            }
                        }
                    }
            )
        }
    }
}

struct ScheduleRowView: View {
    let schedule: Schedule
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(schedule.title ?? "제목 없음")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.3))
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let schedule1 = Schedule(context: context)
    schedule1.id = UUID()
    schedule1.title = "Family"
    schedule1.date = Date()
    
    let schedule2 = Schedule(context: context)
    schedule2.id = UUID()
    schedule2.title = "Personal"
    schedule2.date = Date()
    
    let schedule3 = Schedule(context: context)
    schedule3.id = UUID()
    schedule3.title = "Hiking Club"
    schedule3.date = Date()
    
    let schedule4 = Schedule(context: context)
    schedule4.id = UUID()
    schedule4.title = "Work"
    schedule4.date = Date()
    
    return NavigationStack {
        ScheduleListView(selectedDate: Date())
            .environment(\.managedObjectContext, context)
    }
}
