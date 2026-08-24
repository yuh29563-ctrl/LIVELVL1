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
        let collectionProgress = try progressWithoutSaving(in: context)
        let previousHighestLevel = collectionProgress.highestLevel
        collectionProgress.highestLevel = max(previousHighestLevel, progress.level)

        let pending = try context.fetch(FetchDescriptor<PendingCardReward>())
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        var awardedKeys = Set(pending.map(\.awardKey) + owned.map(\.awardKey))
        let delay = progress.level > previousLevel ? 1.6 : 0.8
        let eligibleAt = now.addingTimeInterval(delay)

        if collectionProgress.highestLevel > previousHighestLevel {
            for level in (previousHighestLevel + 1)...collectionProgress.highestLevel {
                switch CompanionProgressionEngine.event(forReachedLevel: level) {
                case let .active(index, stage):
                    if collectionProgress.activeOrdinaryIndex == index {
                        collectionProgress.activeStage = stage
                    }

                case let .matured(index, _, maturityLevel):
                    let awardKey = "ordinary.level.\(maturityLevel)"
                    guard !awardedKeys.contains(awardKey),
                          let collectible = CollectionCatalog.ordinary(at: index) else {
                        continue
                    }
                    context.insert(PendingCardReward(
                        awardKey: awardKey,
                        collectibleID: collectible.id,
                        kind: .ordinaryMature,
                        reason: "达到 Lv.\(maturityLevel)，陪伴成熟",
                        maturityLevel: maturityLevel,
                        triggeredAt: now,
                        eligibleAt: eligibleAt
                    ))
                    awardedKeys.insert(awardKey)
                }
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

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
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
        calendar: Calendar
    ) throws {
        guard let progress = try context.fetch(FetchDescriptor<Progress>()).first else {
            return
        }
        let completions = try context.fetch(FetchDescriptor<Completion>())
        try reconcile(
            progress: progress,
            completions: completions,
            in: context,
            now: now,
            calendar: calendar
        )
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

    static func claim(
        _ reward: PendingCardReward,
        progress: CollectionProgress,
        in context: ModelContext,
        now: Date
    ) throws {
        guard reward.eligibleAt <= now else { return }

        let ownedKeys = Set(
            try context.fetch(FetchDescriptor<OwnedCollectible>()).map(\.awardKey)
        )
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
            if case let .matured(maturedIndex, nextIndex, _) =
                CompanionProgressionEngine.event(forReachedLevel: maturityLevel) {
                if CollectionCatalog.ordinary(at: nextIndex) != nil {
                    progress.activeOrdinaryIndex = nextIndex
                    progress.activeStage = .juvenile
                    reconcileStage(
                        for: nextIndex,
                        after: maturityLevel,
                        through: progress.highestLevel,
                        progress: progress
                    )
                } else {
                    progress.activeOrdinaryIndex = min(
                        maturedIndex,
                        CollectionCatalog.ordinary.count - 1
                    )
                    progress.activeStage = .mature
                }
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

    private static func reconcileStage(
        for ordinaryIndex: Int,
        after maturityLevel: Int,
        through highestLevel: Int,
        progress: CollectionProgress
    ) {
        guard highestLevel > maturityLevel else { return }

        for level in (maturityLevel + 1)...highestLevel {
            switch CompanionProgressionEngine.event(forReachedLevel: level) {
            case let .active(index, stage) where index == ordinaryIndex:
                progress.activeStage = stage
            case let .matured(index, _, _) where index == ordinaryIndex:
                return
            case let .active(index, _) where index > ordinaryIndex,
                 let .matured(index, _, _) where index > ordinaryIndex:
                return
            default:
                continue
            }
        }
    }
}
