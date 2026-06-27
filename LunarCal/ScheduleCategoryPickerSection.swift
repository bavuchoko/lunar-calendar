import SwiftUI
import CoreData

struct ScheduleCategoryPickerSection: View {
    @Binding var selectedCategoryId: UUID?

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ScheduleCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \ScheduleCategory.name, ascending: true)
        ],
        animation: .default
    )
    private var categories: FetchedResults<ScheduleCategory>

    @State private var isPickerPresented = false

    private var selectedCategory: ScheduleCategory? {
        categories.first { $0.id == selectedCategoryId }
    }

    var body: some View {
        Section {
            Button {
                isPickerPresented = true
            } label: {
                HStack {
                    Text("태그")
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if let selectedCategory, let hex = selectedCategory.colorHex {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(ScheduleCategoryColor.color(from: hex))
                                .frame(width: 10, height: 10)
                            Text(selectedCategory.name ?? "이름 없음")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPickerPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                tagPickerContent
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var tagPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("태그")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            if categories.isEmpty {
                Text("등록된 태그가 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                ForEach(categories, id: \.objectID) { category in
                    if let id = category.id {
                        Button {
                            toggleCategory(id)
                        } label: {
                            tagPickerRow(
                                name: category.name ?? "이름 없음",
                                hex: category.colorHex,
                                isSelected: selectedCategoryId == id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(minWidth: 220)
        .padding(.bottom, 10)
    }

    private func toggleCategory(_ id: UUID) {
        if selectedCategoryId == id {
            selectedCategoryId = nil
        } else {
            selectedCategoryId = id
        }
        isPickerPresented = false
    }

    @ViewBuilder
    private func tagPickerRow(name: String, hex: String?, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .opacity(isSelected ? 1 : 0)
                .frame(width: 18, alignment: .center)

            Circle()
                .fill(tagDotColor(hex: hex))
                .frame(width: 12, height: 12)

            Text(name)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func tagDotColor(hex: String?) -> Color {
        guard let hex, !hex.isEmpty else {
            return Color.secondary.opacity(0.45)
        }
        return ScheduleCategoryColor.color(from: hex)
    }
}
