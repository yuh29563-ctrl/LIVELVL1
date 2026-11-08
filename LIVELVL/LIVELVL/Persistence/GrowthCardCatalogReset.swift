import SwiftData

@MainActor
enum GrowthCardCatalogReset {
    static func applyIfNeeded(in context: ModelContext) throws {
        let collections = try context.fetch(FetchDescriptor<CollectionProgress>())
        guard !collections.contains(where: { $0.growthCatalogRevision >= 1 }) else { return }
        let retiredIDs: Set<String> = [
            "ordinary.sprout", "ordinary.hare", "ordinary.tortoise",
            "hidden.study-streak", "hidden.long-workout"
        ]
        do {
            for progress in try context.fetch(FetchDescriptor<Progress>()) {
                progress.totalXP = 0
            }
            for card in try context.fetch(FetchDescriptor<OwnedCollectible>())
                where retiredIDs.contains(card.collectibleID) {
                context.delete(card)
            }
            for reward in try context.fetch(FetchDescriptor<PendingCardReward>())
                where retiredIDs.contains(reward.collectibleID) {
                context.delete(reward)
            }
            let collection = collections.first ?? CollectionProgress()
            if collections.isEmpty { context.insert(collection) }
            collection.highestLevel = 0
            collection.activeOrdinaryIndex = 0
            collection.activeStage = .juvenile
            collection.lastProcessedMaturityLevel = -1
            collection.growthCatalogRevision = 1
            for duplicate in collections.dropFirst() { context.delete(duplicate) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
