import Foundation
import SwiftData

enum LocalDataResetService {
    static func reset(
        context: ModelContext,
        fileManager: FileManager,
        applicationSupportURL: URL,
        save: (ModelContext) throws -> Void = { try $0.save() },
        removeItem: (FileManager, URL) throws -> Void = { try $0.removeItem(at: $1) }
    ) throws {
        context.rollback()

        do {
            for model in try context.fetch(FetchDescriptor<PendingCardReward>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<OwnedCollectible>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<CollectionProgress>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<Completion>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<Item>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<Progress>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<StateSnapshot>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<DimensionProfile>()) {
                context.delete(model)
            }
            try save(context)
        } catch {
            context.rollback()
            throw error
        }

        let imageDirectoryURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: imageDirectoryURL.path) else { return }

        do {
            try removeItem(fileManager, imageDirectoryURL)
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

#if DEBUG
struct LocalDataResetFailure: Identifiable, Equatable {
    let id = UUID()
    let title = "重置未完成"
    let message: String

    init(error: Error) {
        message = error.localizedDescription
    }
}

enum LocalDataResetAction {
    static func perform(
        context: ModelContext,
        fileManager: FileManager,
        applicationSupportURL: URL,
        save: (ModelContext) throws -> Void = { try $0.save() },
        removeItem: (FileManager, URL) throws -> Void = { try $0.removeItem(at: $1) },
        reportFailure: (LocalDataResetFailure) -> Void
    ) {
        do {
            try LocalDataResetService.reset(
                context: context,
                fileManager: fileManager,
                applicationSupportURL: applicationSupportURL,
                save: save,
                removeItem: removeItem
            )
        } catch {
            reportFailure(LocalDataResetFailure(error: error))
        }
    }
}
#endif
