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
            for model in try context.fetch(FetchDescriptor<JournalEntry>()) {
                context.delete(model)
            }
            if let mediaModels = try? context.fetch(FetchDescriptor<UserCardMedia>()) {
                for model in mediaModels {
                    context.delete(model)
                }
            }
            for model in try context.fetch(FetchDescriptor<CoinTransaction>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<RewardProduct>()) {
                context.delete(model)
            }
            for model in try context.fetch(FetchDescriptor<RewardRedemption>()) {
                context.delete(model)
            }
            try save(context)
        } catch {
            context.rollback()
            throw error
        }

        let cleanupTargets: [(url: URL, error: (Error) -> LocalDataResetError)] = [
            (
                applicationSupportURL.appending(
                    path: "RewardProductImages",
                    directoryHint: .isDirectory
                ),
                { LocalDataResetError.imageCleanupFailed(underlying: $0) }
            ),
            (
                applicationSupportURL.appending(
                    path: "UserCardMedia",
                    directoryHint: .isDirectory
                ),
                { LocalDataResetError.mediaCleanupFailed(underlying: $0) }
            )
        ]

        for target in cleanupTargets where fileManager.fileExists(atPath: target.url.path) {
            do {
                try removeItem(fileManager, target.url)
            } catch {
                throw target.error(error)
            }
        }
    }
}

private enum LocalDataResetError: LocalizedError {
    case imageCleanupFailed(underlying: Error)
    case mediaCleanupFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .imageCleanupFailed(underlying):
            "数据记录已清除，但奖励图片清理失败：\(underlying.localizedDescription)"
        case let .mediaCleanupFailed(underlying):
            "数据记录已清除，但陪伴卡背景清理失败：\(underlying.localizedDescription)"
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
