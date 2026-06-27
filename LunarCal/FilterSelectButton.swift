import SwiftUI

struct FilterSelectButton<Content: View>: View {
    let title: String
    var color: Color? = nil
    var isActive: Bool = false
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                }
                Text(title)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isActive ? Color.blue : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? Color.blue.opacity(0.35) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            content()
                .presentationCompactAdaptation(.popover)
        }
    }
}

struct FilterOptionList<Row: View>: View {
    var scrollToID: AnyHashable? = nil
    var isOpen: Bool = true
    let rows: Row

    init(@ViewBuilder rows: () -> Row) {
        self.scrollToID = nil
        self.isOpen = true
        self.rows = rows()
    }

    init(
        scrollToID: some Hashable,
        isOpen: Bool = true,
        @ViewBuilder rows: () -> Row
    ) {
        self.scrollToID = AnyHashable(scrollToID)
        self.isOpen = isOpen
        self.rows = rows()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    rows
                }
                .frame(minWidth: 180)
            }
            .frame(maxHeight: 280)
            .padding(.vertical, 8)
            .onAppear {
                scrollToSelection(using: proxy)
            }
            .onChange(of: isOpen) { _, open in
                if open {
                    scrollToSelection(using: proxy)
                }
            }
        }
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard let scrollToID else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(scrollToID, anchor: .center)
        }
    }
}

struct FilterOptionRow: View {
    let title: String
    var color: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark" : "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.clear)
                    .frame(width: 16)

                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        .frame(width: 12, height: 12)
                }

                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
