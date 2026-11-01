import SwiftUI

@main
struct LunarCalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    @State private var didScheduleNotifications = false

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                             persistenceController.container.viewContext)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    // 추적 허용 팝업은 앱이 활성 상태일 때만 표시됩니다.
                    guard phase == .active else { return }
                    Task { await handleBecameActive() }
                }
        }
    }

    /// 시스템 팝업이 겹치면 추적 허용 팝업이 표시되지 않으므로,
    /// 추적 허용을 먼저 묻고 그다음에 알림 권한 요청·일정 알림 예약을 실행합니다.
    @MainActor
    private func handleBecameActive() async {
        await AdsManager.shared.prepareIfNeeded()
        // Google Mobile Ads가 알림 델리게이트를 덮어쓸 수 있어 다시 연결합니다.
        appDelegate.bindNotificationDelegate()

        guard !didScheduleNotifications else { return }
        didScheduleNotifications = true
        NotificationManager.shared.rescheduleAll(in: persistenceController.container.viewContext)
    }
}
