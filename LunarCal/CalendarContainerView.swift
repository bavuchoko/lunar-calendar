import SwiftUI

struct CalendarContainerView: View {
    @State private var showLunar = false  // 음력 표시 상태
    
    var body: some View {
        VStack(spacing: 0) {
            LunarCalendarView(showLunar: $showLunar)
            
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
                
                // 음력 토글 버튼 (달 아이콘)
                Button(action: {
                    withAnimation {
                        showLunar.toggle()
                    }
                }) {
                    VStack {
                        Image(systemName: showLunar ? "moon.fill" : "moon")
                            .font(.system(size: 22))
                        Text("음력").font(.caption2)
                    }
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
