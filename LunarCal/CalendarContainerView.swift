import SwiftUI

struct CalendarContainerView: View {
    var body: some View {
        VStack(spacing: 0) {
            LunarCalendarView()
            Spacer(minLength: 0)

            // 광고 영역
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    Text("AD 광고 영역")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                )
                .frame(height: 60)

            // 하단 버튼 바
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "calendar")
                    Text("달력").font(.caption2)
                }
                Spacer()
                VStack {
                    Image(systemName: "list.bullet")
                    Text("목록").font(.caption2)
                }
                Spacer()
                VStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                    Text("추가").font(.caption2)
                }
                Spacer()
                VStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유").font(.caption2)
                }
                Spacer()
                VStack {
                    Image(systemName: "sun.max")
                    Text("설정").font(.caption2)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .background(Color.white.shadow(radius: 2))
            .foregroundColor(.red)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
