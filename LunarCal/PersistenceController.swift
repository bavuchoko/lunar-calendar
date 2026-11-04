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

    /// 백업 스토어의 데이터로 현재 데이터를 바꿉니다.
    /// 스토어 파일을 통째로 교체하면 iCloud 동기화(CloudKit)가 쓰는 스토어와 충돌하므로,
    /// 백업 파일을 별도로 열어 객체 단위로 복사합니다. 변경 내용은 iCloud에도 그대로 동기화됩니다.
    func importAllObjects(fromStoreAt backupURL: URL) throws {
        let model = container.managedObjectModel
        let backupCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let backupStore = try backupCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: backupURL,
            options: [
                // 백업은 iCloud 동기화 스토어를 복사한 것이라 기록 추적을 켜야 정상적으로 열립니다.
                NSPersistentHistoryTrackingKey: true as NSNumber,
                NSMigratePersistentStoresAutomaticallyOption: true as NSNumber,
                NSInferMappingModelAutomaticallyOption: true as NSNumber
            ]
        )
        defer { try? backupCoordinator.remove(backupStore) }

        let entities = model.entities.filter { !$0.isAbstract && $0.name != nil }

        // 1. 백업에서 값만 읽어 둡니다.
        let sourceContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = backupCoordinator
        var snapshots: [ObjectSnapshot] = []
        var readError: Error?
        sourceContext.performAndWait {
            do {
                for entity in entities {
                    let request = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
                    request.includesSubentities = false
                    for object in try sourceContext.fetch(request) {
                        snapshots.append(ObjectSnapshot(object: object))
                    }
                }
            } catch {
                readError = error
            }
        }
        if let readError {
            throw readError
        }

        // 2. 현재 데이터를 지우고 백업 내용으로 다시 만든 뒤 한 번에 저장합니다.
        let targetContext = container.newBackgroundContext()
        var writeError: Error?
        targetContext.performAndWait {
            do {
                for entity in entities {
                    let request = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
                    request.includesSubentities = false
                    for object in try targetContext.fetch(request) {
                        targetContext.delete(object)
                    }
                }

                var created: [URL: NSManagedObject] = [:]
                for snapshot in snapshots {
                    let object = NSManagedObject(entity: snapshot.entity, insertInto: targetContext)
                    for (key, value) in snapshot.attributes {
                        object.setValue(value, forKey: key)
                    }
                    created[snapshot.uri] = object
                }

                for snapshot in snapshots {
                    guard let object = created[snapshot.uri] else { continue }
                    for (key, uris) in snapshot.toOne {
                        object.setValue(uris.flatMap { created[$0] }, forKey: key)
                    }
                    for (key, uris) in snapshot.toMany {
                        object.setValue(NSSet(array: uris.compactMap { created[$0] }), forKey: key)
                    }
                }

                try targetContext.save()
            } catch {
                targetContext.rollback()
                writeError = error
            }
        }
        if let writeError {
            throw writeError
        }
    }
}

/// 컨텍스트 사이에서 객체를 옮기기 위해 값만 담아 두는 사본
private struct ObjectSnapshot {
    let entity: NSEntityDescription
    let uri: URL
    let attributes: [String: Any]
    let toOne: [String: URL?]
    let toMany: [String: [URL]]

    init(object: NSManagedObject) {
        entity = object.entity
        uri = object.objectID.uriRepresentation()

        var attributes: [String: Any] = [:]
        for name in object.entity.attributesByName.keys {
            if let value = object.value(forKey: name) {
                attributes[name] = value
            }
        }
        self.attributes = attributes

        var toOne: [String: URL?] = [:]
        var toMany: [String: [URL]] = [:]
        for (name, relationship) in object.entity.relationshipsByName {
            if relationship.isToMany {
                let related = (object.value(forKey: name) as? Set<NSManagedObject>) ?? []
                toMany[name] = related.map { $0.objectID.uriRepresentation() }
            } else {
                toOne[name] = (object.value(forKey: name) as? NSManagedObject)?.objectID.uriRepresentation()
            }
        }
        self.toOne = toOne
        self.toMany = toMany
    }
}
