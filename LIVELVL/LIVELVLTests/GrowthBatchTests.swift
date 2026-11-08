import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct GrowthBatchTests {
    @Test func fourNewThemesAppendWithoutReorderingTheFirstBatch() {
        #expect(CollectionCatalog.ordinary.prefix(15).map(\.name) == [
            "循星之涡", "织光灵树", "破晓灵杖",
            "双星蚀", "倒悬星瀑", "碎月", "无声古钟", "悬浮王冠", "无字之书",
            "无尽阶梯", "折叠迷宫", "漂浮孤岛", "织梦之茧", "游空鲸影", "晶簇蝶群"
        ])
        #expect(Set(CollectionCatalog.ordinary.prefix(15).map(\.id)).count == 15)
        #expect(CollectionCatalog.ordinary.prefix(15).map(\.ordinaryIndex) == Array(0..<15).map(Optional.some))
    }

    @Test func eightAdditionalThemesAppendInUserOrder() {
        let added = Array(CollectionCatalog.ordinary.dropFirst(15).prefix(24))
        #expect(CollectionCatalog.ordinary.prefix(39).count == 39)
        #expect(added.map(\.name) == [
            "逆行之钟", "昨日之镜", "未尽灯塔", "悬浮晶心", "空洞原石", "流动矿脉",
            "无门之塔", "回环长桥", "倒悬神殿", "凝雷之矛", "潮汐之弓", "余烬之盾",
            "断弦竖琴", "回声骨笛", "无声风铃", "寻路提灯", "渡界小舟", "归途之锚",
            "悬日之轮", "星屑天平", "逐风之帆", "眠火之卵", "负星灵兽", "浮根之莲"
        ])
        #expect(Dictionary(grouping: added, by: { $0.series }).values.allSatisfy { $0.count == 3 })
        #expect(Set(CollectionCatalog.ordinary.prefix(39).map(\.id)).count == 39)
        #expect(CollectionCatalog.ordinary.prefix(39).map(\.ordinaryIndex) == Array(0..<39).map(Optional.some))
    }

    @Test func existingThreeCardsContinueIntoTheNewBatchAtTheNextLevel() throws {
        let container = try ModelContainer(for: Schema([
            Progress.self, CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let progress = Progress(totalXP: 4_200)
        let collection = CollectionProgress(highestLevel: 3, activeOrdinaryIndex: 3,
                                           lastProcessedMaturityLevel: 3)
        context.insert(progress)
        context.insert(collection)
        for (index, card) in CollectionCatalog.ordinary.prefix(3).enumerated() {
            context.insert(OwnedCollectible(awardKey: "ordinary.level.\(index + 1)", collectibleID: card.id,
                kind: .ordinaryMature, reason: "已有成长卡"))
        }
        try context.save()
        progress.totalXP = 6_200
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try CardRewardService.processCompletion(progress: progress, previousLevel: 3, completions: [],
            in: context, now: now, calendar: .current)
        let pending = try #require(context.fetch(FetchDescriptor<PendingCardReward>()).first)
        #expect(pending.collectibleID == "growth.binary-eclipse")
        #expect(pending.awardKey == "ordinary.level.4")
        try CardRewardService.claim(pending, progress: collection, in: context, now: now.addingTimeInterval(2))
        #expect(collection.activeOrdinaryIndex == 4)
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 4)
        #expect(progress.level == 4)
    }
    @Test func existingFifteenCardsContinueIntoTheNextBatchWithoutReset() throws {
        let container = try ModelContainer(for: Schema([
            Progress.self, CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let progress = Progress(totalXP: 28_200)
        let collection = CollectionProgress(highestLevel: 15, activeOrdinaryIndex: 15,
                                           lastProcessedMaturityLevel: 15)
        context.insert(progress)
        context.insert(collection)
        for (index, card) in CollectionCatalog.ordinary.prefix(15).enumerated() {
            context.insert(OwnedCollectible(awardKey: "ordinary.level.\(index + 1)", collectibleID: card.id,
                kind: .ordinaryMature, reason: "已有成长卡"))
        }
        try context.save()
        progress.totalXP = 30_200
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try CardRewardService.processCompletion(progress: progress, previousLevel: 15, completions: [],
            in: context, now: now, calendar: .current)
        let pending = try #require(context.fetch(FetchDescriptor<PendingCardReward>()).first)
        #expect(pending.collectibleID == "growth.reverse-clock")
        #expect(pending.awardKey == "ordinary.level.16")
        try CardRewardService.claim(pending, progress: collection, in: context, now: now.addingTimeInterval(2))
        #expect(collection.activeOrdinaryIndex == 16)
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 16)
        #expect(progress.level == 16)
    }
    @Test func existingThirtyNineCardsContinueWithoutReset() throws {
        let container = try ModelContainer(for: Schema([
            Progress.self, CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let progress = Progress(totalXP: 76_200)
        let collection = CollectionProgress(highestLevel: 39, activeOrdinaryIndex: 39,
                                           lastProcessedMaturityLevel: 39)
        context.insert(progress)
        context.insert(collection)
        for (index, card) in CollectionCatalog.ordinary.prefix(39).enumerated() {
            context.insert(OwnedCollectible(awardKey: "ordinary.level.\(index + 1)", collectibleID: card.id,
                kind: .ordinaryMature, reason: "已有成长卡"))
        }
        try context.save()
        progress.totalXP = 78_200
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try CardRewardService.processCompletion(progress: progress, previousLevel: 39, completions: [],
            in: context, now: now, calendar: .current)
        let pending = try #require(context.fetch(FetchDescriptor<PendingCardReward>()).first)
        #expect(pending.collectibleID == "growth.drowned-crown")
        #expect(pending.awardKey == "ordinary.level.40")
        try CardRewardService.claim(pending, progress: collection, in: context, now: now.addingTimeInterval(2))
        #expect(collection.activeOrdinaryIndex == 40)
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 40)
        #expect(progress.level == 40)
    }
    @Test func latestTwentyFourCardsFollowTheSuppliedOrder() {
        let cards = Array(CollectionCatalog.ordinary.dropFirst(39).prefix(24))
        #expect(CollectionCatalog.ordinary.prefix(63).count == 63)
        #expect(cards.map(\.name) == [
            "沉潮之冠", "渊底明珠", "回游之礁", "破霜之芽", "藏夏之果", "渡冬之枝",
            "衔星飞鱼", "巡夜灵蛾", "曳尾彗灵", "拾光风车", "引梦纺轮", "寻隙钥匙",
            "裂空星舰", "引力风帆", "跃迁之环", "回忆之瓶", "留声海螺", "梦藏匣",
            "逆雪之云", "凝雨之环", "回旋极光", "沉眠石像", "环抱之壁", "守望之羽"
        ])
        #expect(Dictionary(grouping: cards, by: { $0.series }).count == 8)
        #expect(Dictionary(grouping: cards, by: { $0.series }).values.allSatisfy { $0.count == 3 })
        #expect(Set(CollectionCatalog.ordinary.prefix(63).map(\.id)).count == 63)
        #expect(CollectionCatalog.ordinary.prefix(63).map(\.ordinaryIndex) == Array(0..<63).map(Optional.some))
    }
    @Test func existingSixtyThreeCardsContinueWithoutReset() throws {
        let container = try ModelContainer(for: Schema([
            Progress.self, CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let progress = Progress(totalXP: 124_200)
        let collection = CollectionProgress(highestLevel: 63, activeOrdinaryIndex: 63,
                                           lastProcessedMaturityLevel: 63)
        context.insert(progress)
        context.insert(collection)
        for (index, card) in CollectionCatalog.ordinary.prefix(63).enumerated() {
            context.insert(OwnedCollectible(awardKey: "ordinary.level.\(index + 1)", collectibleID: card.id,
                kind: .ordinaryMature, reason: "已有成长卡"))
        }
        try context.save()
        progress.totalXP = 126_200
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try CardRewardService.processCompletion(progress: progress, previousLevel: 63, completions: [],
            in: context, now: now, calendar: .current)
        let pending = try #require(context.fetch(FetchDescriptor<PendingCardReward>()).first)
        #expect(pending.collectibleID == "growth.pulsar-core")
        #expect(pending.awardKey == "ordinary.level.64")
        try CardRewardService.claim(pending, progress: collection, in: context, now: now.addingTimeInterval(2))
        #expect(collection.activeOrdinaryIndex == 64)
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 64)
        #expect(progress.level == 64)
    }

    @Test func fourthBatchHasTwentyFourCardsInOrder() {
        let added = Array(CollectionCatalog.ordinary.dropFirst(63).prefix(24))
        #expect(CollectionCatalog.ordinary.prefix(87).count == 87)
        #expect(added.map(\.name) == [
            "脉冲星核", "坍缩星巢", "引力裂谷", "听风之铃兰", "逆生藤蔓", "藏雨之蕨",
            "复苏之珀", "叠纪之壳", "蜕生之骨", "双生指环", "守诺之印", "结愿之绳",
            "悬砂之丘", "折光峡谷", "回声洞庭", "踏雾灵蹄", "卷潮长鳗", "负山眠兽",
            "无锁之门", "转境之轴", "藏径之匣", "拾星背囊", "渡夜斗篷", "寻风之履"
        ])
        #expect(Dictionary(grouping: added, by: { $0.series }).count == 8)
        #expect(Dictionary(grouping: added, by: { $0.series }).values.allSatisfy { $0.count == 3 })
        #expect(Set(CollectionCatalog.ordinary.prefix(87).map(\.id)).count == 87)
        #expect(CollectionCatalog.ordinary.prefix(87).map(\.ordinaryIndex) == Array(0..<87).map(Optional.some))
    }
    @Test func missingLevelFourAndFiveRewardsAreBackfilledOnDiskAndStayIdempotent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([Progress.self, CollectionProgress.self, OwnedCollectible.self,
                             PendingCardReward.self, Completion.self])
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("cards.store"))
        let originalLevels = Array(1...3) + Array(6...65)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func seedOldStore() throws {
            let store = try ModelContainer(for: schema, configurations: configuration)
            let context = store.mainContext
            context.insert(Progress(totalXP: 128_200))
            context.insert(CollectionProgress(highestLevel: 65, activeOrdinaryIndex: 63,
                                             lastProcessedMaturityLevel: 65))
            for (index, level) in originalLevels.enumerated() {
                context.insert(OwnedCollectible(awardKey: "ordinary.level.\(level)",
                    collectibleID: CollectionCatalog.ordinary[index].id, kind: .ordinaryMature,
                    reason: "已有成长卡", acquiredAt: now, isUnseen: false))
            }
            try context.save()
        }
        func repairOldStore() throws {
            let store = try ModelContainer(for: schema, configurations: configuration)
            try CardRewardService.reconcilePersistedRewards(in: store.mainContext, now: now,
                                                            calendar: .current)
            try CardRewardService.reconcilePersistedRewards(in: store.mainContext, now: now,
                                                            calendar: .current)
        }
        try seedOldStore()
        try repairOldStore()
        let reopened = try ModelContainer(for: schema, configurations: configuration)
        let context = reopened.mainContext
        let owned = try context.fetch(FetchDescriptor<OwnedCollectible>())
        #expect(owned.count == 65)
        #expect(Set(owned.map(\.awardKey)) == Set((1...65).map { "ordinary.level.\($0)" }))
        for (index, level) in originalLevels.enumerated() {
            let card = try #require(owned.first { $0.awardKey == "ordinary.level.\(level)" })
            #expect(card.collectibleID == CollectionCatalog.ordinary[index].id)
            #expect(card.acquiredAt == now)
            #expect(!card.isUnseen)
        }
        let pending = CardRewardService.ordered(try context.fetch(FetchDescriptor<PendingCardReward>()))
        #expect(pending.map(\.awardKey) == ["ordinary.level.4", "ordinary.level.5"])
        #expect(pending.map(\.collectibleID) == ["growth.pulsar-core", "growth.collapsed-star-nest"])
        let collection = try #require(context.fetch(FetchDescriptor<CollectionProgress>()).first)
        // Acknowledging older rewards after newer ones must not move the companion backwards.
        for reward in pending.reversed() {
            try CardRewardService.claim(reward, progress: collection, in: context,
                                        now: now.addingTimeInterval(2))
        }
        #expect(collection.activeOrdinaryIndex == 65)
        #expect(collection.highestLevel == 65)
        #expect(collection.lastProcessedMaturityLevel == 65)
        #expect(try context.fetch(FetchDescriptor<LIVELVL.Progress>()).first?.totalXP == 128_200)
        try CardRewardService.reconcilePersistedRewards(in: context, now: now, calendar: .current)
        #expect(try context.fetchCount(FetchDescriptor<OwnedCollectible>()) == 65)
        #expect(try context.fetch(FetchDescriptor<PendingCardReward>()).isEmpty)
    }

    @Test func backfillReservesCardsAlreadyInLegacyPendingRewards() throws {
        let container = try ModelContainer(for: Schema([
            Progress.self, CollectionProgress.self, OwnedCollectible.self, PendingCardReward.self
        ]), configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let progress = Progress(totalXP: 2_200)
        context.insert(progress)
        context.insert(CollectionProgress(highestLevel: 2))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(PendingCardReward(awardKey: "ordinary.level.1", collectibleID: "growth.star-vortex",
            kind: .ordinaryMature, reason: "旧版待领取", maturityLevel: 1,
            triggeredAt: now, eligibleAt: now))
        try context.save()
        try CardRewardService.reconcile(progress: progress, completions: [], in: context,
                                        now: now, calendar: .current)
        let pending = CardRewardService.ordered(try context.fetch(FetchDescriptor<PendingCardReward>()))
        #expect(pending.map(\.collectibleID) == ["growth.star-vortex", "growth.light-tree"])
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).first?.awardKey == "ordinary.level.2")
    }

    @Test func fifthBatchAppendsTwentyFourCardsWithoutReorderingEarlierCards() {
        let added = Array(CollectionCatalog.ordinary.dropFirst(87))
        #expect(CollectionCatalog.ordinary.count == 111)
        #expect(added.map(\.name) == [
            "自生卷轴", "游墨之笔", "浮字石碑", "折影棱镜", "昼夜双面盘", "藏光灯罩",
            "陨星麦穗", "环轨蒲公英", "星尘松果", "穿隙灵蛇", "渡镜双翼", "踏界长足",
            "折叠帐篷", "悬眠摇篮", "归梦巢屋", "测星仪", "听潮盘", "寻脉探针",
            "协行蚁阵", "浮空菌落", "迁徙光鳐", "未寄之笺", "静潮之罐", "待醒之盒"
        ])
        #expect(added.map(\.series) == [
            "异界文字", "异界文字", "异界文字", "光影奇物", "光影奇物", "光影奇物",
            "深空植物", "深空植物", "深空植物", "边界行者", "边界行者", "边界行者",
            "梦境居所", "梦境居所", "梦境居所", "古老仪器", "古老仪器", "古老仪器",
            "异界种群", "异界种群", "异界种群", "封存之物", "封存之物", "封存之物"
        ])
        #expect(Set(CollectionCatalog.ordinary.map(\.id)).count == 111)
        #expect(CollectionCatalog.ordinary.map(\.ordinaryIndex) == Array(0..<111).map(Optional.some))
    }

}
