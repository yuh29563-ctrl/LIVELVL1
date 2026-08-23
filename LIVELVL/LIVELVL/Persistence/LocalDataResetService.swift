import Foundation
import SwiftData

enum LocalDataResetService {
    static func reset(
        context: ModelContext,
        fileManager: FileManager,
        applicationSupportURL: URL
    ) throws {
        do {
            try context.delete(model: PendingCardReward.self)
            try context.delete(model: OwnedCollectible.self)
            try context.delete(model: CollectionProgress.self)
            try context.delete(model: Completion.self)
            try context.delete(model: Item.self)
            try context.delete(model: Progress.self)
            try context.delete(model: StateSnapshot.self)
            try context.delete(model: DimensionProfile.self)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        let imageDirectoryURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: imageDirectoryURL.path) else { return }

        do {
            try fileManager.removeItem(at: imageDirectoryURL)
        } catch {
            throw LocalDataResetError.imageCleanupFailed(underlying: error)
        }
    }
}

private enum LocalDataResetError: LocalizedError {
    case imageCleanupFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .imageCleanupFailed(underlying):
            "数据记录已清除，但奖励图片清理失败：\(underlying.localizedDescription)"
        }
    }
}
