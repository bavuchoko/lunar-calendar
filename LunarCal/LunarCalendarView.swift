import SwiftUI
import CoreData

struct LunarCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Schedule.date, ascending: true)],
        animation: .default
    ) private var schedules: FetchedResults<Schedule>
    
    @State private var currentDate = Date()
    @Binding var showLunar: Bool
    @ObservedObject var holidayManager: HolidayManager
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            MonthView(
                currentDate: $currentDate,
                schedules: schedules,
                showLunar: showLunar,
                holidayManager: holidayManager
            )
            .simultaneousGesture(  // ⭐ simultaneousGesture로 변경
                DragGesture(minimumDistance: 30)  // ⭐ minimumDistance 증가
                    .onEnded { value in
                        withAnimation(.easeInOut) {
                            // 세로 스와이프만 감지 (가로 스와이프 무시)
                            if abs(value.translation.height) > abs(value.translation.width) {
                                if value.translation.height < -50 {
                                    // 위로 스와이프 → 다음 달
                                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
                                } else if value.translation.height > 50 {
                                    // 아래로 스와이프 → 이전 달
                                    currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate)!
                                }
                            }
                        }
                    }
            )
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    return NavigationStack {
        LunarCalendarView(
            showLunar: .constant(false),
            holidayManager: HolidayManager()
        )
        .environment(\.managedObjectContext, context)
    }
}
