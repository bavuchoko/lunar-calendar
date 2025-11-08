import SwiftUI

struct CalendarContainerView: View {
    @State private var showLunar = false
    @StateObject private var holidayManager = HolidayManager()
    @State private var showCalendarMenu = false
    @State private var showHolidayList = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LunarCalendarView(showLunar: $showLunar, holidayManager: holidayManager)
                
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
                    
                    // 달력 버튼 (팝업 메뉴)
                    Button(action: {
                        withAnimation {
                            showCalendarMenu.toggle()
                        }
                    }) {
                        VStack {
                            Image(systemName: "calendar")
                            Text("달력").font(.caption2)
                        }
                    }
                    
                    Spacer()
                    
                    // 음력 토글 버튼
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
            // ⭐ .ignoresSafeArea(edges: .top) 제거
            
            // 팝업 메뉴
            if showCalendarMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showCalendarMenu = false
                        }
                    }
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // 공휴일 갱신
                        Button(action: {
                            Task {
                                await holidayManager.manualRefresh()
                            }
                            withAnimation {
                                showCalendarMenu = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .frame(width: 24)
                                Text("공휴일 갱신")
                                Spacer()
                                if holidayManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                        }
                        .foregroundColor(.primary)
                        
                        Divider()
                        
                        // 공휴일 목록보기
                        Button(action: {
                            withAnimation {
                                showCalendarMenu = false
                            }
                            showHolidayList = true
                        }) {
                            HStack {
                                Image(systemName: "list.bullet.calendar")
                                    .frame(width: 24)
                                Text("공휴일 목록보기")
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                        }
                        .foregroundColor(.primary)
                    }
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 100)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showHolidayList) {
            HolidayListView(holidayManager: holidayManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
        }
    }
}

#Preview {
    CalendarContainerView()
}
