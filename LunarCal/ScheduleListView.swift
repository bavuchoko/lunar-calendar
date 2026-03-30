import SwiftUI
import CoreData

struct ScheduleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false

    var selectedDate: Date

    @FetchRequest var schedules: FetchedResults<Schedule>

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
        ZStack {
            KanbanTheme.background.ignoresSafeArea()

            if schedules.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(schedules.enumerated()), id: \.element.objectID) { index, schedule in
                            SwipeableScheduleRow(
                                schedule: schedule,
                                paletteIndex: index,
                                onDelete: { deleteSchedule(schedule) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.visible)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(dateString(from: selectedDate))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(KanbanTheme.titleNavy)
            }
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .navigationBarLeading) {
                    scheduleListBackButton
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .primaryAction) {
                    scheduleListAddButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    scheduleListBackButton
                }
                ToolbarItem(placement: .primaryAction) {
                    scheduleListAddButton
                }
            }
        }
        .toolbarBackground(KanbanTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingAddSheet) {
            ScheduleAddView(selectedDate: selectedDate)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    @ViewBuilder
    private var scheduleListBackButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(KanbanTheme.titleNavy)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var scheduleListAddButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("등록된 일정이 없습니다")
                .font(.headline)
                .foregroundStyle(KanbanTheme.titleNavy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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

// MARK: - 스와이프 + 칸반 카드

struct SwipeableScheduleRow: View {
    let schedule: Schedule
    let paletteIndex: Int
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false

    private let deleteButtonWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .trailing) {
            // 스와이프하지 않을 때는 빨간 삭제 영역을 그리지 않음 — 카드 모서리 안티앨리어싱 뒤로 빨강이 비치는 현상 방지
            KanbanTheme.background
                .allowsHitTesting(false)

            HStack {
                Spacer()
                Button(action: onDelete) {
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
            .opacity(offset < -0.5 ? 1 : 0)
            .allowsHitTesting(offset < -0.5)
            .animation(.easeOut(duration: 0.15), value: offset)

            NavigationLink(destination: ScheduleEditView(schedule: schedule)) {
                ScheduleKanbanCard(
                    title: schedule.title ?? "제목 없음",
                    subtitle: scheduleSubtitle(schedule),
                    shortDate: scheduleShortDate(schedule),
                    primaryTag: schedulePrimaryTag(schedule),
                    secondaryTag: scheduleSecondaryTag(schedule),
                    paletteIndex: paletteIndex
                )
            }
            .buttonStyle(.plain)
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
                    .onEnded { _ in
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

    private func scheduleSubtitle(_ s: Schedule) -> String {
        guard let d = s.date else { return "" }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ko_KR")
        dayFormatter.dateFormat = "yyyy년 M월 d일 (E)"
        let base = dayFormatter.string(from: d)
        if s.alertEnabled, let at = s.alertTime {
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "ko_KR")
            timeFormatter.dateFormat = "a h:mm"
            return "\(base) · 알림 \(timeFormatter.string(from: at))"
        }
        return base
    }

    private func scheduleShortDate(_ s: Schedule) -> String {
        guard let d = s.date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d"
        return f.string(from: d)
    }

    private func schedulePrimaryTag(_ s: Schedule) -> String {
        if s.repeatRule != nil || s.repeatId != nil { return "반복" }
        return "일정"
    }

    private func scheduleSecondaryTag(_ s: Schedule) -> String? {
        s.alertEnabled ? "알림" : nil
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    return NavigationStack {
        ScheduleListView(selectedDate: Date())
            .environment(\.managedObjectContext, context)
    }
}
