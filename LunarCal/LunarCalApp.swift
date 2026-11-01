import SwiftUI

@main
struct LunarCalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                             persistenceController.container.viewContext)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    // 추적 허용 팝업은 앱이 활성 상태일 때만 표시됩니다.
                    guard phase == .active else { return }
                    Task { await AdsManager.shared.prepareIfNeeded() }
                }
        }
    }
}
