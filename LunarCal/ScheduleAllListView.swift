import SwiftUI
import CoreData

struct ScheduleAllListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Schedule.date, ascending: true)
        ],
        animation: .default
    )
    private var schedules: FetchedResults<Schedule>

    private struct MonthSection: Identifiable {
        let id: String
        let title: String
        let schedules: [Schedule]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KanbanTheme.background.ignoresSafeArea()

                if schedules.isEmpty {
                    emptyState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                ForEach(buildSections()) { section in
                                    monthBlock(section: section)
                                }

                                Text("전체 일정은 날짜순입니다")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 8)
                                    .padding(.bottom, 24)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        .scrollIndicators(.visible)
                        .onAppear {
                            let currentMonthId = monthId(for: Date())
                            DispatchQueue.main.async {
                                proxy.scrollTo(currentMonthId, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("일정 목록")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KanbanTheme.titleNavy)
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .navigationBarLeading) {
                        scheduleAllDismissButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        scheduleAllDismissButton
                    }
                }
            }
            .toolbarBackground(KanbanTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var scheduleAllDismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("닫기")
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

    private func monthBlock(section: MonthSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(KanbanTheme.titleNavy)
                Spacer()
                Text("\(section.schedules.count)건")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Capsule())
            }
            .id(section.id)

            ForEach(Array(section.schedules.enumerated()), id: \.element.objectID) { index, s in
                NavigationLink(destination: ScheduleEditView(schedule: s)) {
                    ScheduleKanbanCard(
                        title: s.title ?? "제목 없음",
                        subtitle: scheduleSubtitle(s),
                        shortDate: scheduleShortDate(s),
                        primaryTag: schedulePrimaryTag(s),
                        secondaryTag: scheduleSecondaryTag(s),
                        paletteIndex: index
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func buildSections() -> [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: schedules) { (s: Schedule) -> Date in
            let d = s.date ?? Date()
            let comps = calendar.dateComponents([.year, .month], from: d)
            return calendar.date(from: comps) ?? d
        }

        let sortedMonths = grouped.keys.sorted()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"

        return sortedMonths.map { monthStart in
            let id = monthId(for: monthStart)
            let title = formatter.string(from: monthStart)
            let items = (grouped[monthStart] ?? []).sorted {
                ($0.date ?? .distantPast) < ($1.date ?? .distantPast)
            }
            return MonthSection(id: id, title: title, schedules: items)
        }
    }

    private func monthId(for date: Date) -> String {
        let calendar = Calendar.current
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
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
