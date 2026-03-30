import SwiftUI

/// 일정용 칸반 카드 (공휴일 목록 카드와 동일한 톤)
struct ScheduleKanbanCard: View {
    let title: String
    let subtitle: String
    let shortDate: String
    let primaryTag: String
    let secondaryTag: String?
    let paletteIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                tagPill(
                    text: primaryTag,
                    fill: KanbanTheme.tagPalette[paletteIndex % KanbanTheme.tagPalette.count]
                )
                if let secondary = secondaryTag {
                    tagPill(
                        text: secondary,
                        fill: KanbanTheme.secondaryTagFill,
                        foreground: KanbanTheme.secondaryTagForeground
                    )
                }
            }

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(KanbanTheme.bodyText)
                .lineLimit(2)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label(shortDate, systemImage: "calendar")
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
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
}
