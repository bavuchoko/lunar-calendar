import Foundation
import CoreData
import SQLite3

enum ICloudBackupError: LocalizedError {
    case iCloudUnavailable
    case storeURLNotFound
    case backupFailed
    case restoreFailed(Error? = nil)
    case backupNotFound

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud를 사용할 수 없어요. iCloud Drive가 켜져 있는지 확인해 주세요."
        case .storeURLNotFound:
            return "데이터 저장소 파일을 찾을 수 없어요."
        case .backupFailed:
            return "백업에 실패했어요."
        case .restoreFailed(let underlying):
            // 원인을 문의받았을 때 확인할 수 있도록 오류 코드를 함께 보여 줍니다.
            guard let nsError = underlying as NSError? else { return "복원에 실패했어요." }
            return "복원에 실패했어요. (\(nsError.domain) \(nsError.code))"
        case .backupNotFound:
            return "iCloud에 백업 파일이 없어요. 먼저 백업해 주세요."
        }
    }
}

final class ICloudBackupManager {
    static let shared = ICloudBackupManager()
    private init() {}

    private let backupFileName = "LunarCalBackup.sqlite"
    private let ubiquityContainerId = "iCloud.jongsu.LunarCal"

    func backupToICloud(viewContext: NSManagedObjectContext) throws {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            throw ICloudBackupError.iCloudUnavailable
        }
        guard let storeURL = persistentStoreURL(from: viewContext) else {
            throw ICloudBackupError.storeURLNotFound
        }
        guard let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityContainerId) else {
            throw ICloudBackupError.iCloudUnavailable
        }

        try viewContext.performAndWait {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        }

        let backupDir = ubiquity.appendingPathComponent("Documents", isDirectory: true)
        if !FileManager.default.fileExists(atPath: backupDir.path) {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }

        let dst = backupDir.appendingPathComponent(backupFileName)
        let tempBackup = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(backupFileName)

        do {
            try FileManager.default.createDirectory(
                at: tempBackup.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try writeStandaloneCopy(ofStoreAt: storeURL, to: tempBackup)
            try coordinatedReplace(at: dst, with: tempBackup)
            try? FileManager.default.removeItem(at: tempBackup.deletingLastPathComponent())
        } catch {
            try? FileManager.default.removeItem(at: tempBackup.deletingLastPathComponent())
            throw ICloudBackupError.backupFailed
        }
    }

    /// iCloud에서 백업 파일을 내려받아 현재 데이터를 백업 내용으로 바꿉니다.
    /// 앱을 새로 설치한 직후에는 백업 파일이 아직 기기에 내려받아지지 않았을 수 있어 백그라운드에서 실행합니다.
    func restoreFromICloud(persistence: PersistenceController = .shared) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.restoreFromICloudSync(persistence: persistence)
        }.value
    }

    private func restoreFromICloudSync(persistence: PersistenceController) throws {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            throw ICloudBackupError.iCloudUnavailable
        }
        guard let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityContainerId) else {
            throw ICloudBackupError.iCloudUnavailable
        }

        let src = ubiquity
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(backupFileName)

        // 아직 내려받지 않은 파일은 fileExists로 보이지 않으므로 iCloud 항목인지도 함께 확인합니다.
        guard FileManager.default.fileExists(atPath: src.path)
                || FileManager.default.isUbiquitousItem(at: src) else {
            throw ICloudBackupError.backupNotFound
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LunarCalRestore-\(UUID().uuidString)", isDirectory: true)
        let stagedBackup = tempDir.appendingPathComponent(backupFileName)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try? FileManager.default.startDownloadingUbiquitousItem(at: src)
            try coordinatedCopy(from: src, to: stagedBackup)
            try validateSQLiteFile(at: stagedBackup)
            try persistence.importAllObjects(fromStoreAt: stagedBackup)
        } catch let error as ICloudBackupError {
            throw error
        } catch {
            throw ICloudBackupError.restoreFailed(error)
        }
    }

    /// iCloud 파일을 읽을 때는 NSFileCoordinator를 거쳐야 기기에 없는 파일을 내려받은 뒤 복사합니다.
    private func coordinatedCopy(from source: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinatorError) { readURL in
            do {
                try FileManager.default.copyItem(at: readURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError ?? copyError {
            throw error
        }
    }

    func lastBackupDate() -> Date? {
        guard let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityContainerId) else {
            return nil
        }
        let backupURL = ubiquity
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(backupFileName)

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return nil
        }

        return (try? FileManager.default.attributesOfItem(atPath: backupURL.path)[.modificationDate]) as? Date
    }

    private func persistentStoreURL(from context: NSManagedObjectContext) -> URL? {
        guard let coordinator = context.persistentStoreCoordinator else { return nil }
        return coordinator.persistentStores.first?.url
    }

    /// 앱이 열어 둔 스토어를 SQLite 백업 API로 한 파일에 통째로 복사합니다.
    /// 최근 변경분은 -wal 파일에만 있을 수 있어 본 파일만 복사하면 일정이 빠집니다.
    /// 복사본은 저널 모드를 DELETE로 바꿔 -wal/-shm 없이도 열리게 합니다.
    private func writeStandaloneCopy(ofStoreAt source: URL, to destination: URL) throws {
        var sourceDB: OpaquePointer?
        var destinationDB: OpaquePointer?
        defer {
            sqlite3_close(sourceDB)
            sqlite3_close(destinationDB)
        }
        guard sqlite3_open_v2(source.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              sqlite3_open_v2(destination.path, &destinationDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else {
            throw ICloudBackupError.backupFailed
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE,
              sqlite3_exec(destinationDB, "PRAGMA journal_mode=DELETE;", nil, nil, nil) == SQLITE_OK else {
            throw ICloudBackupError.backupFailed
        }
    }

    /// iCloud 폴더의 파일은 NSFileCoordinator를 거쳐 교체해야 동기화 중인 파일과 충돌하지 않습니다.
    private func coordinatedReplace(at destination: URL, with source: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinatorError) { writeURL in
            do {
                if FileManager.default.fileExists(atPath: writeURL.path) {
                    try FileManager.default.removeItem(at: writeURL)
                }
                try FileManager.default.copyItem(at: source, to: writeURL)
            } catch {
                writeError = error
            }
        }
        if let error = coordinatorError ?? writeError {
            throw error
        }
    }

    /// 복원용으로 임시 폴더에 복사한 파일을 검사합니다.
    /// Core Data 스토어는 WAL 모드라서 -shm 파일 없이 읽기 전용으로 열면 항상 실패하므로 읽기·쓰기로 엽니다.
    private func validateSQLiteFile(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw ICloudBackupError.restoreFailed()
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA schema_version;", -1, &statement, nil) == SQLITE_OK else {
            throw ICloudBackupError.restoreFailed()
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw ICloudBackupError.restoreFailed()
        }
    }
}
