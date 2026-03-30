import SwiftUI

struct HolidayListView: View {
    @ObservedObject var holidayManager: HolidayManager
    @Environment(\.dismiss) private var dismiss
    @State private var showRateLimitAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                KanbanTheme.background.ignoresSafeArea()

                if holidayManager.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.1)
                        Text("공휴일 데이터 로딩 중...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if holidayManager.holidayList.isEmpty {
                    emptyStateView
                } else {
                    holidayScrollContent
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("공휴일")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KanbanTheme.titleNavy)
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .navigationBarLeading) {
                        holidayDismissButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        holidayRefreshButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        holidayDismissButton
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        holidayRefreshButton
                    }
                }
            }
            .toolbarBackground(KanbanTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("알림", isPresented: $showRateLimitAlert) {
                Button("확인", role: .cancel) {
                    holidayManager.refreshRateLimitMessage = nil
                }
            } message: {
                Text(holidayManager.refreshRateLimitMessage ?? "")
            }
            .onChange(of: holidayManager.refreshRateLimitMessage) { _, newValue in
                if newValue != nil { showRateLimitAlert = true }
            }
        }
    }

    @ViewBuilder
    private var holidayDismissButton: some View {
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

    @ViewBuilder
    private var holidayRefreshButton: some View {
        Button {
            Task { await holidayManager.manualRefresh() }
        } label: {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(holidayManager.isLoading)
        .accessibilityLabel("새로고침")
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
                Text("공휴일 데이터가 없습니다")
                .font(.headline)
                .foregroundStyle(KanbanTheme.titleNavy)
            Button {
                Task { await holidayManager.fetchHolidays(recordManualRefresh: true) }
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .foregroundStyle(KanbanTheme.titleNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
        }
        .padding(32)
    }

    private var holidayScrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                ForEach(groupedHolidays()) { group in
                    monthSection(group: group)
                }

                Text("올해 기준 공휴일입니다")
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
    }

    private func monthSection(group: MonthGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monthHeaderText(group.month))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(KanbanTheme.titleNavy)
                Spacer()
                Text("\(group.holidays.count)일")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Capsule())
            }

            ForEach(Array(group.holidays.enumerated()), id: \.element.id) { index, holiday in
                HolidayKanbanCard(
                    holiday: holiday,
                    colorIndex: index,
                    weekdayTag: weekdayTagText(for: holiday.date)
                )
            }
        }
    }

    // MARK: - 월별 그룹핑

    struct MonthGroup: Identifiable {
        let month: String
        let holidays: [HolidayItem]

        var id: String { month }
    }

    private func groupedHolidays() -> [MonthGroup] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        let currentYearHolidays = holidayManager.holidayList.filter { item in
            item.date.starts(with: "\(currentYear)")
        }

        let grouped = Dictionary(grouping: currentYearHolidays) { holiday -> String in
            String(holiday.date.prefix(7))
        }

        return grouped.keys.sorted().map { month in
            MonthGroup(
                month: month,
                holidays: grouped[month]?.sorted { $0.date < $1.date } ?? []
            )
        }
    }

    private func weekdayTagText(for dateString: String) -> String {
        let w = getDayOfWeek(from: dateString)
        switch w {
        case "(일)": return "일요일"
        case "(토)": return "토요일"
        default: return "평일"
        }
    }

    private func monthHeaderText(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        if components.count == 2 {
            let month = String(components[1])
            return "\(month)월"
        }
        return monthString
    }

    private func getDayOfWeek(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let weekdays = ["(일)", "(월)", "(화)", "(수)", "(목)", "(금)", "(토)"]
        return weekdays[weekday - 1]
    }
}

// MARK: - Kanban 카드

private struct HolidayKanbanCard: View {
    let holiday: HolidayItem
    let colorIndex: Int
    let weekdayTag: String

    private var formattedLine: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: holiday.date) else { return holiday.date }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ko_KR")
        out.dateFormat = "yyyy년 M월 d일"
        return out.string(from: date) + " " + getDayOfWeekShort(from: date)
    }

    private var shortLine: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: holiday.date) else { return "" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ko_KR")
        out.dateFormat = "M/d"
        return out.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                tagPill(text: weekdayTag, fill: KanbanTheme.tagPalette[colorIndex % KanbanTheme.tagPalette.count])
                tagPill(text: "공휴일", fill: KanbanTheme.secondaryTagFill, foreground: KanbanTheme.secondaryTagForeground)
            }

            Text(holiday.name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(KanbanTheme.bodyText)
                .lineLimit(2)

            Text(formattedLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label(shortLine, systemImage: "calendar")
                Spacer(minLength: 0)
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 3)
    }

    private func tagPill(text: String, fill: Color, foreground: Color = Color(red: 0.12, green: 0.14, blue: 0.2)) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fill.opacity(0.92))
            .clipShape(Capsule())
    }

    private func getDayOfWeekShort(from date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        return "(\(weekdays[weekday - 1]))"
    }
}

#Preview {
    HolidayListView(holidayManager: HolidayManager())
}
