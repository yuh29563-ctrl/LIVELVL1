import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct LocalDataResetServiceTests {
    @Test func resetDeletesEveryBusinessModelAndOnlyRewardProductImages() throws {
        let schema = Schema([
            PendingCardReward.self,
            OwnedCollectible.self,
            CollectionProgress.self,
            Completion.self,
            Item.self,
            Progress.self,
            StateSnapshot.self,
            DimensionProfile.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let item = Item(
            title: "测试行动",
            dimension: .learning,
            minutes: 30,
            difficulty: 2,
            xp: 25,
            recurrence: .once
        )
        context.insert(PendingCardReward(
            awardKey: "pending",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "测试",
            maturityLevel: 1,
            triggeredAt: timestamp,
            eligibleAt: timestamp
        ))
        context.insert(OwnedCollectible(
            awardKey: "owned",
            collectibleID: "ordinary.sprout",
            kind: .ordinaryMature,
            reason: "测试",
            acquiredAt: timestamp
        ))
        context.insert(CollectionProgress())
        context.insert(Completion(
            itemID: item.id,
            xp: 25,
            dimension: .learning,
            durationMinutes: 30,
            taskTitle: "测试行动",
            date: timestamp
        ))
        context.insert(item)
        context.insert(Progress(totalXP: 25))
        context.insert(StateSnapshot(
            scores: LifeStateValues(repeating: 6),
            actionScores: LifeStateValues(repeating: 5),
            assessedAt: timestamp
        ))
        context.insert(DimensionProfile(
            dimension: .learning,
            selfRating: 6,
            weeklyTarget: 3,
            lastAssessedAt: timestamp
        ))
        try context.save()

        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let rewardProductImagesURL = applicationSupportURL
            .appending(path: "RewardProductImages", directoryHint: .isDirectory)
        let unrelatedURL = applicationSupportURL.appending(path: "keep.bin")
        try fileManager.createDirectory(
            at: rewardProductImagesURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(to: rewardProductImagesURL.appending(path: "sample.bin"))
        try Data([0x02]).write(to: unrelatedURL)
        defer { try? fileManager.removeItem(at: applicationSupportURL) }

        try LocalDataResetService.reset(
            context: context,
            fileManager: fileManager,
            applicationSupportURL: applicationSupportURL
        )

        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionProgress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Completion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StateSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DimensionProfile>()).isEmpty)
        #expect(!fileManager.fileExists(atPath: rewardProductImagesURL.path))
        #expect(fileManager.fileExists(atPath: unrelatedURL.path))
    }
}
