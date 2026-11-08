import Foundation
import SwiftData

struct TaskCompletionResult {
    let completion: Completion
    let wasCreated: Bool
}

@MainActor
enum TaskRewardCoordinator {
    enum Error: Swift.Error { case missingProgress, missingCompletion }

    static func preview(
        nominalXP: Int, completions: [Completion], now: Date, calendar: Calendar
    ) throws -> DailyTaskXPAllowance {
        let day = try DailyTaskXPPolicy.day(containing: now, calendar: calendar)
        let earned = completions.lazy
            .filter { $0.date >= day.start && $0.date < day.end }
            .reduce(0) { $0 + max(0, $1.xp) }
        return try DailyTaskXPPolicy.allowance(
            nominalXP: nominalXP, earnedXP: earned, now: now, calendar: calendar
        )
    }

    @discardableResult
    static func complete(
        item: Item,
        progress: Progress,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> TaskCompletionResult {
        // A failed SwiftData save can leave the saving context's registered models
        // changed even after rollback. Keep those changes out of the UI context.
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        // No suspension between reading the allowance and committing the transaction.
        let day = try DailyTaskXPPolicy.day(containing: now, calendar: calendar)
        let start = day.start
        let end = day.end
        let completions = try writer.fetch(FetchDescriptor<Completion>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\Completion.date)]
        ))
        if let existing = completions.first(where: { $0.itemID == item.id }) {
            try refreshProgress(progress, in: context)
            return TaskCompletionResult(
                completion: try completion(with: existing.persistentModelID, in: context), wasCreated: false
            )
        }
        let storedProgress = try storedProgress(for: progress, in: writer)
        let allowance = try preview(
            nominalXP: item.xp, completions: completions, now: now, calendar: calendar
        )
        let completion = Completion(
            itemID: item.id,
            xp: allowance.awardedXP,
            dimension: item.dimension,
            durationMinutes: item.minutes,
            taskTitle: item.title,
            date: now,
            nominalXP: allowance.nominalXP
        )
        do {
            let priorCompletions = try writer.fetch(FetchDescriptor<Completion>())
            writer.insert(completion)
            storedProgress.totalXP += completion.xp
            try CoinLedgerService.insertTaskAward(completion: completion, in: writer, now: now)
            try CardRewardService.stageCompletion(
                progress: storedProgress,
                previousLevel: GrowthEngine.level(for: storedProgress.totalXP - completion.xp),
                completions: priorCompletions + [completion],
                in: writer,
                now: now,
                calendar: calendar
            )
            try writer.save()
        } catch {
            writer.rollback()
            throw error
        }
        try refreshProgress(progress, in: context)
        return TaskCompletionResult(
            completion: try Self.completion(with: completion.persistentModelID, in: context), wasCreated: true
        )
    }

    @discardableResult
    static func revoke(
        completion: Completion,
        progress: Progress,
        in context: ModelContext,
        now: Date = .now
    ) throws -> Bool {
        // Only the persistent identity is read from the argument: it may already be deleted.
        let identity = completion.persistentModelID
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        guard let persisted = try writer.fetch(FetchDescriptor<Completion>()).first(where: {
            $0.persistentModelID == identity
        }) else { return false }
        let storedProgress = try storedProgress(for: progress, in: writer)

        do {
            try CoinLedgerService.insertTaskReversal(completion: persisted, in: writer, now: now)
            storedProgress.totalXP = max(0, storedProgress.totalXP - max(0, persisted.xp))
            writer.delete(persisted)
            let remaining = try writer.fetch(FetchDescriptor<Completion>()).filter {
                $0.persistentModelID != identity
            }
            try CardRewardService.stageHiddenRewards(completions: remaining, in: writer,
                                                    now: now, calendar: .current)
            try writer.save()
        } catch {
            writer.rollback()
            throw error
        }
        try refreshProgress(progress, in: context)
        // Refetch committed records so the caller never needs the writer's model instances.
        _ = try context.fetch(FetchDescriptor<Completion>())
        _ = try context.fetch(FetchDescriptor<OwnedCollectible>())
        _ = try context.fetch(FetchDescriptor<PendingCardReward>())
        return true
    }

#if DEBUG
    static func debugAdvanceOneLevel(
        progress: Progress,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        let stored = try storedProgress(for: progress, in: writer)
        let previousLevel = stored.level
        do {
            stored.totalXP += GrowthEngine.xpNeededForNextLevel(for: stored.totalXP)
                - GrowthEngine.xpInCurrentLevel(for: stored.totalXP)
            try CardRewardService.stageCompletion(
                progress: stored,
                previousLevel: previousLevel,
                completions: try writer.fetch(FetchDescriptor<Completion>()),
                in: writer,
                now: now,
                calendar: .current
            )
            try writer.save()
        } catch {
            writer.rollback()
            throw error
        }
        try refreshProgress(progress, in: context)
    }
#endif

    private static func storedProgress(for progress: Progress, in context: ModelContext) throws -> Progress {
        guard let stored = try context.fetch(FetchDescriptor<Progress>()).first(where: {
            $0.persistentModelID == progress.persistentModelID
        }) else { throw Error.missingProgress }
        return stored
    }

    private static func refreshProgress(_ progress: Progress, in context: ModelContext) throws {
        // Fetch refreshes the registered instance from the successful store transaction.
        _ = try storedProgress(for: progress, in: context)
    }

    private static func completion(with identity: PersistentIdentifier, in context: ModelContext) throws -> Completion {
        guard let stored = try context.fetch(FetchDescriptor<Completion>()).first(where: {
            $0.persistentModelID == identity
        }) else { throw Error.missingCompletion }
        return stored
    }
}
