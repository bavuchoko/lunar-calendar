import SwiftUI
import CoreData

struct ScheduleCategoryManageView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ScheduleCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \ScheduleCategory.name, ascending: true)
        ],
        animation: .default
    )
    private var categories: FetchedResults<ScheduleCategory>

    var body: some View {
        List {
            if categories.isEmpty {
                Text("등록된 태그가 없습니다.\n아래 + 버튼으로 태그를 추가해 주세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(categories) { category in
                    NavigationLink {
                        ScheduleCategoryEditorView(category: category)
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        categoryRow(category)
                    }
                }
                .onDelete(perform: deleteCategories)
            }
        }
        .navigationTitle("태그 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ScheduleCategoryEditorView(category: nil)
                        .environment(\.managedObjectContext, viewContext)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func categoryRow(_ category: ScheduleCategory) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ScheduleCategoryColor.color(from: category.colorHex))
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name ?? "이름 없음")
                    .font(.headline)
                    .foregroundStyle(KanbanTheme.bodyText)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func deleteCategories(at offsets: IndexSet) {
        offsets.map { categories[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}

struct ScheduleCategoryEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let category: ScheduleCategory?

    @State private var name = ""
    @State private var selectedHex = ScheduleCategoryColor.presets[4].hex
    @State private var customColor = Color.blue

    @FocusState private var focusedField: EditorField?

    private enum EditorField: Hashable {
        case name
    }

    var body: some View {
        Form {
            Section(header: Text("태그 이름")) {
                TextField("예: 업무, 개인", text: $name)
                    .focused($focusedField, equals: .name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section(header: Text("색상")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(ScheduleCategoryColor.presets, id: \.hex) { preset in
                        Button {
                            selectedHex = preset.hex
                        } label: {
                            Circle()
                                .fill(Color(hex: preset.hex) ?? .blue)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if selectedHex == preset.hex {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.name)
                    }
                }
                .padding(.vertical, 4)

                ColorPicker("직접 선택", selection: $customColor, supportsOpacity: false)
                    .onChange(of: customColor) { _, newValue in
                        selectedHex = ScheduleCategoryColor.hex(from: newValue)
                    }
            }

            Section(header: Text("미리보기")) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ScheduleCategoryColor.color(from: selectedHex))
                        .frame(width: 12, height: 12)
                    Text(name.isEmpty ? "미리보기" : name)
                        .foregroundStyle(ScheduleCategoryColor.color(from: selectedHex))
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(category == nil ? "태그 추가" : "태그 수정")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    saveCategory()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            loadCategory()
            focusedField = .name
        }
        .id(category?.objectID.uriRepresentation().absoluteString ?? "new-category")
    }

    private func loadCategory() {
        guard let category else {
            name = ""
            selectedHex = ScheduleCategoryColor.presets[4].hex
            customColor = ScheduleCategoryColor.color(from: selectedHex)
            return
        }

        name = category.name ?? ""
        selectedHex = category.colorHex ?? ScheduleCategoryColor.presets[4].hex
        customColor = ScheduleCategoryColor.color(from: selectedHex)
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let target = category ?? ScheduleCategory(context: viewContext)
        if category == nil {
            target.id = UUID()
            let fetch: NSFetchRequest<ScheduleCategory> = ScheduleCategory.fetchRequest()
            let count = (try? viewContext.count(for: fetch)) ?? 0
            target.sortOrder = Int16(count)
        }

        target.name = trimmedName
        target.colorHex = selectedHex
        try? viewContext.save()
    }
}
