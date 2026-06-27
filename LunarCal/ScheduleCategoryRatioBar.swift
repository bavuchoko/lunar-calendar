import SwiftUI

struct ScheduleCategoryRatioItem: Identifiable {
    let id: String
    let name: String
    let color: Color
    let count: Int
    let fraction: Double
}

struct ScheduleCategoryRatioBar: View {
    let items: [ScheduleCategoryRatioItem]
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ratioBar

            FlowLayout(spacing: 10, rowSpacing: 6) {
                ForEach(items) { item in
                    legendItem(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var ratioBar: some View {
        HStack(spacing: 10) {
            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))

                    HStack(spacing: 1) {
                        ForEach(items) { item in
                            item.color
                                .frame(width: segmentWidth(for: item, totalWidth: width))
                        }
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 10)

            Text(verbatim: "\(totalCount)건")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    private func segmentWidth(for item: ScheduleCategoryRatioItem, totalWidth: CGFloat) -> CGFloat {
        guard item.fraction > 0 else { return 0 }
        return totalWidth * item.fraction
    }

    private func legendItem(_ item: ScheduleCategoryRatioItem) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(item.color)
                .frame(width: 8, height: 8)

            Text(item.name)
                .font(.caption)
                .foregroundStyle(KanbanTheme.bodyText)
                .lineLimit(1)

            Text(verbatim: "\(item.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = computeLayout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = layout.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
        }

        return (CGSize(width: totalWidth, height: y + rowHeight), positions)
    }
}

enum ScheduleCategoryRatioBuilder {
    static func items(
        from schedules: [Schedule],
        categories: [ScheduleCategory]
    ) -> [ScheduleCategoryRatioItem] {
        guard !schedules.isEmpty else { return [] }

        let total = schedules.count
        var countByCategoryId: [UUID: Int] = [:]
        var untaggedCount = 0

        for schedule in schedules {
            if let categoryId = schedule.category?.id {
                countByCategoryId[categoryId, default: 0] += 1
            } else {
                untaggedCount += 1
            }
        }

        var result: [ScheduleCategoryRatioItem] = []

        for category in categories {
            guard let categoryId = category.id,
                  let count = countByCategoryId[categoryId],
                  count > 0 else { continue }

            result.append(
                ScheduleCategoryRatioItem(
                    id: categoryId.uuidString,
                    name: category.name ?? "이름 없음",
                    color: ScheduleCategoryColor.color(from: category.colorHex),
                    count: count,
                    fraction: Double(count) / Double(total)
                )
            )
        }

        if untaggedCount > 0 {
            result.append(
                ScheduleCategoryRatioItem(
                    id: "untagged",
                    name: "태그 없음",
                    color: Color(.systemGray3),
                    count: untaggedCount,
                    fraction: Double(untaggedCount) / Double(total)
                )
            )
        }

        return result
    }
}
