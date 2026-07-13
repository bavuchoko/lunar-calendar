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
        newSchedule.createdAt = Date()

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
        backfillCreatedAtIfNeeded(in: container.viewContext)
    }

    /// 기존 일정에 createdAt이 없으면 등록순 정렬용으로 채웁니다.
    private func backfillCreatedAtIfNeeded(in context: NSManagedObjectContext) {
        context.performAndWait {
            let request: NSFetchRequest<Schedule> = Schedule.fetchRequest()
            request.predicate = NSPredicate(format: "createdAt == nil")
            guard let schedules = try? context.fetch(request), !schedules.isEmpty else { return }

            let ordered = schedules.sorted {
                $0.objectID.uriRepresentation().absoluteString
                    < $1.objectID.uriRepresentation().absoluteString
            }
            let base = Date(timeIntervalSince1970: 0)
            for (index, schedule) in ordered.enumerated() {
                schedule.createdAt = base.addingTimeInterval(TimeInterval(index))
            }
            try? context.save()
        }
    }

    /// 스토어 파일을 교체한 뒤 Core Data를 다시 로드합니다.
    func replaceStoreFile(with replacementURL: URL) throws {
        let coordinator = container.persistentStoreCoordinator
        guard let storeURL = coordinator.persistentStores.first?.url else {
            throw ICloudBackupError.storeURLNotFound
        }

        container.viewContext.performAndWait {
            if container.viewContext.hasChanges {
                try? container.viewContext.save()
            }
            container.viewContext.reset()
        }

        if coordinator.persistentStores.first != nil {
            try coordinator.destroyPersistentStore(
                at: storeURL,
                ofType: NSSQLiteStoreType,
                options: nil
            )
        }

        Self.removeAuxiliaryStoreFiles(at: storeURL)
        try FileManager.default.copyItem(at: replacementURL, to: storeURL)
        Self.removeAuxiliaryStoreFiles(at: storeURL)

        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let loadError {
            throw loadError
        }

        container.viewContext.reset()
    }

    private static func removeAuxiliaryStoreFiles(at storeURL: URL) {
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
        try? FileManager.default.removeItem(at: walURL)
        try? FileManager.default.removeItem(at: shmURL)
    }
}
