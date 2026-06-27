import SwiftUI

/// 일정용 칸반 카드 (공휴일 목록 카드와 동일한 톤)
struct ScheduleKanbanCard: View {
    let title: String
    let shortDate: String
    let primaryTag: String
    let secondaryTag: String?
    var tagHex: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    tagPill(text: primaryTag, hex: tagHex)
                    if let secondary = secondaryTag {
                        tagPill(text: secondary, hex: nil)
                    }
                }

                Spacer(minLength: 0)

                Text(shortDate)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(KanbanTheme.bodyText)
                .lineLimit(2)
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

    @ViewBuilder
    private func tagPill(
        text: String,
        hex: String?
    ) -> some View {
        if let style = ScheduleCategoryColor.tagStyle(hex: hex) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(style.foreground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(style.background)
                .clipShape(Capsule())
        } else {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
        }
    }
}
