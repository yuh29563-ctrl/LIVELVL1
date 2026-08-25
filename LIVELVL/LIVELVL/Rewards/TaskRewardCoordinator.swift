import Foundation
import SwiftData

@MainActor
enum TaskRewardCoordinator {
    @discardableResult
    static func complete(
        item: Item,
        progress: Progress,
        in context: ModelContext,
        now: Date = .now
    ) throws -> Completion {
        let completion = Completion(
            itemID: item.id,
            xp: item.xp,
            dimension: item.dimension,
            durationMinutes: item.minutes,
            taskTitle: item.title,
            date: now
        )
        context.insert(completion)
        progress.totalXP += item.xp

        do {
            try CoinLedgerService.awardTask(
                completion: completion,
                in: context,
                now: now
            )
            return completion
        } catch {
            context.rollback()
            throw error
        }
    }

    static func revoke(
        completion: Completion,
        progress: Progress,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        context.delete(completion)
        progress.totalXP = max(0, progress.totalXP - completion.xp)

        do {
            try CoinLedgerService.reverseTask(
                completion: completion,
                in: context,
                now: now
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}
