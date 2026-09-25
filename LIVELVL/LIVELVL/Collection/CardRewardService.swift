import Foundation
import SwiftData

struct CompletionRewardFlowState: Equatable, Sendable {
    private(set) var requiresRetry = false
    private(set) var allowsSuccessFeedback = false

    mutating func rewardProcessingFailed() {
        requiresRetry = true
        allowsSuccessFeedback = false
    }

    mutating func rewardProcessingSucceeded() {
        requiresRetry = false
        allowsSuccessFeedback = true
    }
}

@MainActor
enum CardRewardService {
    static func ensureProgress(in context: ModelContext) throws -> CollectionProgress {
        if let existing = try context.fetch(FetchDescriptor<CollectionProgress>()).first {
            return existing
        }

        let progress = CollectionProgress()
        context.insert(progress)
        do {
            try context.save()
            return progress
        } catch {
            context.rollback()
            throw error
        }
    }

    static func processCompletion(
        progress: Progress,
        previousLevel: Int,
        completions: [Completion],
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws {
        do {
            try stageCompletion(
                progress: progress,
                previousLevel: previousLevel,
                completions: completions,
                in: context,
                now: now,
                calendar: calendar
            )
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }

    static func stageCompletion(
        progress: Progress,
        previousLevel: Int,
        completions: [Completion],
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws {
        let collectionProgress = try progressWithoutSaving(in: context)
        let previousHighestLevel = collectionProgress.highestLevel
        if progress.level > previousHighestLevel {
            collectionProgress.highestLevel = progress.level
        }

        let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        var awardedKeys = Set(pending.map(\.awardKey) + owned.map(\.awardKey))
        var ownedOrdinaryIDs = Set(owned.filter { $0.kind == .ordinaryMature }.map(\.collectibleID))
        let delay = progress.level > previousLevel ? 1.6 : 0.8
        let eligibleAt = now.addingTimeInterval(delay)

        if collectionProgress.highestLevel > previousHighestLevel {
            for level in (previousHighestLevel + 1)...collectionProgress.highestLevel {
                guard let index = CollectionCatalog.ordinary.firstIndex(where: {
                    !ownedOrdinaryIDs.contains($0.id)
                }), let collectible = CollectionCatalog.ordinary(at: index) else { continue }
                guard case let .matured(_, _, maturityLevel) = CompanionProgressionEngine.event(
                    forReachedLevel: level, nextOrdinaryIndex: index
                ) else { continue }
                let awardKey = "ordinary.level.\(maturityLevel)"
                guard !awardedKeys.contains(awardKey) else { continue }
                let reason = "达到 Lv.\(maturityLevel)，陪伴成熟"
                context.insert(OwnedCollectible(
                    awardKey: awardKey,
                    collectibleID: collectible.id,
                    kind: .ordinaryMature,
                    reason: reason,
                    acquiredAt: now
                ))
                context.insert(PendingCardReward(
                    awardKey: awardKey,
                    collectibleID: collectible.id,
                    kind: .ordinaryMature,
                    reason: reason,
                    maturityLevel: maturityLevel,
                    triggeredAt: now,
                    eligibleAt: eligibleAt
                ))
                ownedOrdinaryIDs.insert(collectible.id)
                awardedKeys.insert(awardKey)
            }
        }

        let facts = completions.compactMap { completion -> CompletionFact? in
            guard let dimension = completion.recordedDimension,
                  let durationMinutes = completion.durationMinutes else {
                return nil
            }
            return CompletionFact(
                itemID: completion.itemID,
                date: completion.date,
                dimension: dimension,
                durationMinutes: durationMinutes
            )
        }

        let hiddenAwards = HiddenAchievementEngine.newAwards(
            facts: facts,
            alreadyAwardedKeys: Array(awardedKeys),
            calendar: calendar
        )
        for award in hiddenAwards where !awardedKeys.contains(award.awardKey) {
            context.insert(PendingCardReward(
                awardKey: award.awardKey,
                collectibleID: award.collectibleID,
                kind: .hiddenDiscovery,
                reason: award.reason,
                triggeredAt: award.triggeredAt,
                eligibleAt: eligibleAt
            ))
            awardedKeys.insert(award.awardKey)
        }

    }

    static func reconcile(
        progress: Progress,
        completions: [Completion],
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws {
        let previousLevel = try progressWithoutSaving(in: context).highestLevel
        try processCompletion(
            progress: progress,
            previousLevel: previousLevel,
            completions: completions,
            in: context,
            now: now,
            calendar: calendar
        )
    }

    static func reconcilePersistedRewards(
        in context: ModelContext,
        now: Date,
        calendar: Calendar,
        previousLevel: Int? = nil
    ) throws {
        // Read committed task facts in a fresh context. A failed save must not
        // leave phantom rewards in the UI context or suppress the next retry.
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        guard let progress = try writer.fetch(FetchDescriptor<Progress>()).first else {
            return
        }
        let completions = try writer.fetch(FetchDescriptor<Completion>())
        let reachedLevel = try progressWithoutSaving(in: writer).highestLevel
        try processCompletion(
            progress: progress,
            previousLevel: previousLevel ?? reachedLevel,
            completions: completions,
            in: writer,
            now: now,
            calendar: calendar
        )
        _ = try context.fetch(FetchDescriptor<CollectionProgress>())
        _ = try context.fetch(FetchDescriptor<PendingCardReward>())
    }

    static func ordered(_ rewards: [PendingCardReward]) -> [PendingCardReward] {
        rewards.sorted { lhs, rhs in
            let lhsPriority = lhs.kind == .ordinaryMature ? 0 : 1
            let rhsPriority = rhs.kind == .ordinaryMature ? 0 : 1
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            if lhs.triggeredAt != rhs.triggeredAt {
                return lhs.triggeredAt < rhs.triggeredAt
            }
            return lhs.awardKey < rhs.awardKey
        }
    }

    static func acknowledgeAlreadyOwnedOrdinaryRewards(
        in context: ModelContext,
        now: Date
    ) throws -> Set<String> {
        let ownedKeys = Set(
            try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey)
        )
        let rewards = ordered(try context.fetch(FetchDescriptor<PendingCardReward>()))
            .filter { $0.kind == .ordinaryMature && ownedKeys.contains($0.awardKey) }
        guard !rewards.isEmpty else { return [] }
        let progress = try ensureProgress(in: context)
        var acknowledged: Set<String> = []
        for reward in rewards {
            try claim(reward, progress: progress, in: context, now: now)
            acknowledged.insert(reward.awardKey)
        }
        return acknowledged
    }

    static func claim(
        _ reward: PendingCardReward,
        progress: CollectionProgress,
        in context: ModelContext,
        now: Date
    ) throws {
        let ownedKeys = Set(
            try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey)
        )
        guard reward.eligibleAt <= now ||
              (reward.kind == .ordinaryMature && ownedKeys.contains(reward.awardKey)) else { return }
        if !ownedKeys.contains(reward.awardKey) {
            context.insert(OwnedCollectible(
                awardKey: reward.awardKey,
                collectibleID: reward.collectibleID,
                kind: reward.kind,
                reason: reward.reason,
                acquiredAt: now
            ))
        }

        context.delete(reward)
        if reward.kind == .ordinaryMature, let maturityLevel = reward.maturityLevel {
            progress.lastProcessedMaturityLevel = max(
                progress.lastProcessedMaturityLevel,
                maturityLevel
            )
            if let maturedIndex = CollectionCatalog.ordinary.firstIndex(where: {
                $0.id == reward.collectibleID
            }) {
                progress.activeOrdinaryIndex = maturedIndex + 1
                progress.activeStage = .juvenile
            }
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func markAllSeen(in context: ModelContext) throws {
        let awardKeys = Set(
            try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey)
        )
        try markSeen(awardKeys: awardKeys, in: context)
    }

    static func markSeen(
        awardKeys: Set<String>,
        in context: ModelContext
    ) throws {
        guard !awardKeys.isEmpty else { return }
        for collectible in try context.fetch(FetchDescriptor<OwnedCollectible>())
        where awardKeys.contains(collectible.awardKey) {
            collectible.isUnseen = false
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func progressWithoutSaving(in context: ModelContext) throws -> CollectionProgress {
        if let existing = try context.fetch(FetchDescriptor<CollectionProgress>()).first {
            return existing
        }
        let progress = CollectionProgress()
        context.insert(progress)
        return progress
    }

}
