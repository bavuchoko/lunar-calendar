import SwiftUI
import CoreData

struct RepeatScheduleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \RepeatSchedule.title, ascending: true)
        ],
        animation: .default
    )
    private var repeatRules: FetchedResults<RepeatSchedule>

    var body: some View {
        NavigationStack {
            List {
                if repeatRules.isEmpty {
                    Text("등록된 반복 일정이 없습니다.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(repeatRules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.title ?? "제목 없음")
                                    .font(.headline)

                                Text(repeatDescription(for: rule))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // 삭제 버튼
                            Button(role: .destructive) {
                                delete(rule)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("반복 일정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    /// 화면용 간단한 설명 문자열
    private func repeatDescription(for rule: RepeatSchedule) -> String {
        let type = rule.repeatType ?? "반복 없음"
        if let end = rule.repeatEndDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = "yyyy.MM.dd"
            return "\(type) · 종료 \(f.string(from: end))"
        } else {
            return type
        }
    }

    /// 규칙만 삭제 (이미 생성된 일정은 남김)
    private func delete(_ rule: RepeatSchedule) {
        viewContext.delete(rule)

        do {
            try viewContext.save()
        } catch {
            print("RepeatSchedule 삭제 실패: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    RepeatScheduleListView()
        .environment(\.managedObjectContext, context)
}
