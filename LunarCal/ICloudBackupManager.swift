import Foundation
import CoreData
import SQLite3

enum ICloudBackupError: LocalizedError {
    case iCloudUnavailable
    case storeURLNotFound
    case backupFailed
    case restoreFailed
    case backupNotFound

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud를 사용할 수 없어요. iCloud Drive가 켜져 있는지 확인해 주세요."
        case .storeURLNotFound:
            return "데이터 저장소 파일을 찾을 수 없어요."
        case .backupFailed:
            return "백업에 실패했어요."
        case .restoreFailed:
            return "복원에 실패했어요."
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

        try checkpointWAL(at: storeURL)

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
            try copyStoreFiles(from: storeURL, to: tempBackup)

            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.copyItem(at: tempBackup, to: dst)
            try? FileManager.default.removeItem(at: tempBackup.deletingLastPathComponent())
        } catch {
            try? FileManager.default.removeItem(at: tempBackup.deletingLastPathComponent())
            throw ICloudBackupError.backupFailed
        }
    }

    func restoreFromICloud(
        viewContext: NSManagedObjectContext,
        persistence: PersistenceController = .shared
    ) throws {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            throw ICloudBackupError.iCloudUnavailable
        }
        guard persistentStoreURL(from: viewContext) != nil else {
            throw ICloudBackupError.storeURLNotFound
        }
        guard let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityContainerId) else {
            throw ICloudBackupError.iCloudUnavailable
        }

        let src = ubiquity
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(backupFileName)

        guard FileManager.default.fileExists(atPath: src.path) else {
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
            try FileManager.default.copyItem(at: src, to: stagedBackup)
            try validateSQLiteFile(at: stagedBackup)
            try persistence.replaceStoreFile(with: stagedBackup)
        } catch let error as ICloudBackupError {
            throw error
        } catch {
            throw ICloudBackupError.restoreFailed
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

    private func checkpointWAL(at storeURL: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw ICloudBackupError.backupFailed
        }
        defer { sqlite3_close(database) }

        var logFrames: Int32 = 0
        var checkpointedFrames: Int32 = 0
        let result = sqlite3_wal_checkpoint_v2(
            database,
            nil,
            SQLITE_CHECKPOINT_TRUNCATE,
            &logFrames,
            &checkpointedFrames
        )
        guard result == SQLITE_OK else {
            throw ICloudBackupError.backupFailed
        }
    }

    private func copyStoreFiles(from source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)

        let walSource = URL(fileURLWithPath: source.path + "-wal")
        let shmSource = URL(fileURLWithPath: source.path + "-shm")
        let walDestination = URL(fileURLWithPath: destination.path + "-wal")
        let shmDestination = URL(fileURLWithPath: destination.path + "-shm")

        if FileManager.default.fileExists(atPath: walSource.path) {
            try FileManager.default.copyItem(at: walSource, to: walDestination)
        }
        if FileManager.default.fileExists(atPath: shmSource.path) {
            try FileManager.default.copyItem(at: shmSource, to: shmDestination)
        }
    }

    private func removeAuxiliaryStoreFiles(at storeURL: URL) {
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
        try? FileManager.default.removeItem(at: walURL)
        try? FileManager.default.removeItem(at: shmURL)
    }

    private func validateSQLiteFile(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw ICloudBackupError.restoreFailed
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA schema_version;", -1, &statement, nil) == SQLITE_OK else {
            throw ICloudBackupError.restoreFailed
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw ICloudBackupError.restoreFailed
        }
    }
}
