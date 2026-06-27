import SwiftUI
import CoreData

struct LunarCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Schedule.date, ascending: true)],
        animation: .default
    ) private var schedules: FetchedResults<Schedule>

    // 🔹 바깥에서 넘겨받는 현재 기준 날짜
    @Binding var currentDate: Date

    @Binding var showLunar: Bool
    @ObservedObject var holidayManager: HolidayManager
    @Binding var selectedDate: Date
    @Binding var scheduleNavigationDay: ScheduleDayNavigation?

    private let calendar = Calendar.current
    @State private var transitionDirection: Int = 0 // 1: next month (swipe up), -1: prev month (swipe down)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                MonthView(
                    currentDate: $currentDate,
                    scheduleNavigationDay: $scheduleNavigationDay,
                    schedules: schedules,
                    showLunar: showLunar,
                    holidayManager: holidayManager
                )
                .id(monthKey(for: currentDate))
                .transition(monthTransition)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        // 세로 스와이프만 감지 (가로 스와이프 무시)
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }

                        if value.translation.height < -50 {
                            // 위로 스와이프 → 다음 달
                            transitionDirection = 1
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                            }
                        } else if value.translation.height > 50 {
                            // 아래로 스와이프 → 이전 달
                            transitionDirection = -1
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
                            }
                        }
                    }
            )
            .clipped()
        }
    }

    private var monthTransition: AnyTransition {
        if transitionDirection >= 0 {
            // 다음 달: 새 달이 아래에서 올라오고, 기존 달은 위로 사라짐
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        } else {
            // 이전 달: 새 달이 위에서 내려오고, 기존 달은 아래로 사라짐
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }

    private func monthKey(for date: Date) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    NavigationStack {
        LunarCalendarView(
            currentDate: .constant(Date()),
            showLunar: .constant(false),
            holidayManager: HolidayManager(),
            selectedDate: .constant(Date()),
            scheduleNavigationDay: .constant(nil)
        )
        .environment(\.managedObjectContext, context)
    }
}
