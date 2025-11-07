import SwiftUI
import CoreData

struct LunarCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Schedule.date, ascending: true)],
        animation: .default
    ) private var schedules: FetchedResults<Schedule>
    
    @State private var currentDate = Date()
    @Binding var showLunar: Bool  // 추가
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 전체 스와이프 감지용 투명 레이어
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                withAnimation(.easeInOut) {
                                    if value.translation.height < -50 {
                                        // 위로 스와이프 → 다음 달
                                        currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
                                    } else if value.translation.height > 50 {
                                        // 아래로 스와이프 → 이전 달
                                        currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate)!
                                    }
                                }
                            }
                    )
                // 실제 MonthView
                MonthView(currentDate: $currentDate, schedules: schedules, showLunar: showLunar)
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    return LunarCalendarView(showLunar: .constant(true))
        .environment(\.managedObjectContext, context)
}
