import Foundation
import CoreData

enum ICloudBackupError: LocalizedError {
    case iCloudUnavailable
    case storeURLNotFound
    case backupFailed
    case restoreFailed

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

        let backupDir = ubiquity.appendingPathComponent("Documents", isDirectory: true)
        if !FileManager.default.fileExists(atPath: backupDir.path) {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }

        let dst = backupDir.appendingPathComponent(backupFileName)
        do {
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.copyItem(at: storeURL, to: dst)
        } catch {
            throw ICloudBackupError.backupFailed
        }
    }

    func restoreFromICloud(viewContext: NSManagedObjectContext) throws {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            throw ICloudBackupError.iCloudUnavailable
        }
        guard let storeURL = persistentStoreURL(from: viewContext) else {
            throw ICloudBackupError.storeURLNotFound
        }
        guard let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityContainerId) else {
            throw ICloudBackupError.iCloudUnavailable
        }

        let src = ubiquity
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(backupFileName)

        guard FileManager.default.fileExists(atPath: src.path) else {
            throw ICloudBackupError.restoreFailed
        }

        // CoreData가 파일을 잡고 있을 수 있으니, 우선 저장 후 reset
        viewContext.performAndWait {
            if viewContext.hasChanges {
                try? viewContext.save()
            }
            viewContext.reset()
        }

        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(at: storeURL)
            }
            try FileManager.default.copyItem(at: src, to: storeURL)
        } catch {
            throw ICloudBackupError.restoreFailed
        }
    }

    private func persistentStoreURL(from context: NSManagedObjectContext) -> URL? {
        guard let coordinator = context.persistentStoreCoordinator else { return nil }
        return coordinator.persistentStores.first?.url
    }
}

