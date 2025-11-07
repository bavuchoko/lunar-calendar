import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    // 미리보기용 in-memory 저장소
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // 샘플 데이터
        let newSchedule = Schedule(context: viewContext)
        newSchedule.id = UUID()
        newSchedule.title = "테스트 일정"
        newSchedule.memo = "이건 미리보기용입니다."
        newSchedule.date = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("미리보기 저장 실패 \(nsError), \(nsError.userInfo)")
        }
        return controller
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ScheduleModel")

        // iCloud 사용 설정 (CloudKit 통합)
        // 개발자 등록 전까지 우선 주석처리
//        if let description = container.persistentStoreDescriptions.first {
//            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
//            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.yourname.LunarCal")
//        }

        // in-memory 모드 설정 (미리보기용)
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data 로드 실패: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
