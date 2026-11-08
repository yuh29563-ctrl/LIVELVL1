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
        var reservedOrdinaryIDs = Set(
            owned.filter { $0.kind == .ordinaryMature }.map(\.collectibleID)
                + pending.filter { $0.kind == .ordinaryMature }.map(\.collectibleID)
        )
        let delay = progress.level > previousLevel ? 1.6 : 0.8
        let eligibleAt = now.addingTimeInterval(delay)

        // Catalog expansion can fill levels that were reached while no cards remained.
        if collectionProgress.highestLevel > 0 {
            for level in 1...collectionProgress.highestLevel {
                guard !awardedKeys.contains("ordinary.level.\(level)") else { continue }
                guard let index = CollectionCatalog.ordinary.firstIndex(where: {
                    !reservedOrdinaryIDs.contains($0.id)
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
                reservedOrdinaryIDs.insert(collectible.id)
                awardedKeys.insert(awardKey)
            }
        }

        try stageHiddenRewards(completions: completions, in: context, now: now,
                               calendar: calendar, eligibleAt: eligibleAt)
    }

    static func activateHiddenCards(in context: ModelContext, now: Date, calendar: Calendar) throws {
        do {
            let progress = try progressWithoutSaving(in: context)
            initializeHiddenWindow(progress: progress, now: now, calendar: calendar)
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func initializeHiddenWindow(progress: CollectionProgress, now: Date, calendar: Calendar) {
        if progress.hiddenCardsEnabledAt == nil { progress.hiddenCardsEnabledAt = now }
        if progress.hiddenCardsTimeZoneIdentifier == nil {
            progress.hiddenCardsTimeZoneIdentifier = calendar.timeZone.identifier
        }
    }

    @discardableResult
    static func stageHiddenRewards(
        completions: [Completion], in context: ModelContext, now: Date,
        calendar: Calendar, eligibleAt: Date? = nil
    ) throws -> Set<String> {
        let progress = try progressWithoutSaving(in: context)
        initializeHiddenWindow(progress: progress, now: now, calendar: calendar)
        guard let enabledAt = progress.hiddenCardsEnabledAt else { return [] }
        var fixedCalendar = Calendar(identifier: .gregorian)
        fixedCalendar.timeZone = progress.hiddenCardsTimeZoneIdentifier.flatMap(TimeZone.init(identifier:))
            ?? calendar.timeZone
        let facts = completions.compactMap { completion -> CompletionFact? in
            guard completion.date >= enabledAt,
                  let dimension = completion.recordedDimension else { return nil }
            return CompletionFact(itemID: completion.itemID, date: completion.date,
                                  dimension: dimension, durationMinutes: completion.durationMinutes ?? 0)
        }
        let supportedAwards = HiddenAchievementEngine.eligibleAwards(facts: facts, calendar: fixedCalendar)
        let supportedKeys = Set(supportedAwards.map(\.awardKey))
        // Clock rollback must not erase valid evidence; only gate new awards by their trigger time.
        let awards = supportedAwards.filter { $0.triggeredAt <= now }
        let eligibleKeys = Set(awards.map(\.awardKey))
        let managedKeys = Set(HiddenAchievementEngine.rules.map(\.id))
        var existingKeys: Set<String> = []
        for pending in try context.fetch(FetchDescriptor<PendingCardReward>()) {
            if pending.kind == .hiddenDiscovery && managedKeys.contains(pending.awardKey)
                && !supportedKeys.contains(pending.awardKey) {
                context.delete(pending)
            } else { existingKeys.insert(pending.awardKey) }
        }
        for owned in try context.fetch(FetchDescriptor<OwnedCollectible>()) {
            if owned.kind == .hiddenDiscovery && managedKeys.contains(owned.awardKey)
                && !supportedKeys.contains(owned.awardKey) {
                context.delete(owned)
            } else { existingKeys.insert(owned.awardKey) }
        }
        for award in awards where !existingKeys.contains(award.awardKey)
            && CollectionCatalog.definition(id: award.collectibleID) != nil {
            context.insert(PendingCardReward(awardKey: award.awardKey, collectibleID: award.collectibleID,
                kind: .hiddenDiscovery, reason: award.reason, triggeredAt: award.triggeredAt,
                eligibleAt: eligibleAt ?? now))
        }
        return eligibleKeys
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
            if lhs.kind == .ordinaryMature {
                let lhsLevel = lhs.maturityLevel ?? Int.max
                let rhsLevel = rhs.maturityLevel ?? Int.max
                if lhsLevel != rhsLevel { return lhsLevel < rhsLevel }
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
        if reward.kind == .hiddenDiscovery,
           HiddenAchievementEngine.rules.contains(where: { $0.id == reward.awardKey }) {
            try claimHiddenReward(awardKey: reward.awardKey, in: context, now: now)
            return
        }
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
                progress.activeOrdinaryIndex = max(progress.activeOrdinaryIndex, maturedIndex + 1)
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

    private static func claimHiddenReward(awardKey: String, in context: ModelContext, now: Date) throws {
        let writer = ModelContext(context.container)
        writer.autosaveEnabled = false
        do {
            let completions = try writer.fetch(FetchDescriptor<Completion>())
            let eligible = try stageHiddenRewards(completions: completions, in: writer,
                                                  now: now, calendar: .current)
            if eligible.contains(awardKey),
               let pending = try writer.fetch(FetchDescriptor<PendingCardReward>()).first(where: {
                   $0.awardKey == awardKey && $0.eligibleAt <= now
               }) {
                if try !writer.fetch(FetchDescriptor<OwnedCollectible>()).contains(where: {
                    $0.awardKey == awardKey
                }) {
                    writer.insert(OwnedCollectible(awardKey: pending.awardKey,
                        collectibleID: pending.collectibleID, kind: .hiddenDiscovery,
                        reason: pending.reason, acquiredAt: now))
                }
                writer.delete(pending)
            }
            if writer.hasChanges { try writer.save() }
        } catch {
            writer.rollback()
            throw error
        }
        _ = try context.fetch(FetchDescriptor<OwnedCollectible>())
        _ = try context.fetch(FetchDescriptor<PendingCardReward>())
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
