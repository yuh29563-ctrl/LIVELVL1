import Foundation

enum CollectibleKind: String, Codable, Sendable {
    case ordinary
    case hidden
}

enum CompanionStage: Int, Codable, CaseIterable, Sendable {
    case juvenile
    case stageTwo
    case stageThree
    case mature
}

struct CollectibleDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: CollectibleKind
    let ordinaryIndex: Int?
    let symbolName: String
    let silhouetteSymbolName: String
    let summary: String
    let details: String
    let hiddenRuleID: String?
}

enum CollectionCatalog {
    static let ordinary: [CollectibleDefinition] = [
        CollectibleDefinition(
            id: "ordinary.sprout",
            name: "小芽",
            kind: .ordinary,
            ordinaryIndex: 0,
            symbolName: "leaf.fill",
            silhouetteSymbolName: "leaf.fill",
            summary: "从今天开始，陪你一点点成长。",
            details: "小芽在每一次坚持里长出新的叶片。",
            hiddenRuleID: nil
        ),
        CollectibleDefinition(
            id: "ordinary.hare",
            name: "月兔",
            kind: .ordinary,
            ordinaryIndex: 1,
            symbolName: "hare.fill",
            silhouetteSymbolName: "hare.fill",
            summary: "在规律的节奏中轻盈前进。",
            details: "月兔把每一步稳稳地连成一条路。",
            hiddenRuleID: nil
        ),
        CollectibleDefinition(
            id: "ordinary.tortoise",
            name: "慢慢",
            kind: .ordinary,
            ordinaryIndex: 2,
            symbolName: "tortoise.fill",
            silhouetteSymbolName: "tortoise.fill",
            summary: "不急，持续向前就是答案。",
            details: "慢慢相信，耐心会把微小行动带到远方。",
            hiddenRuleID: nil
        )
    ]

    static let hidden: [CollectibleDefinition] = [
        CollectibleDefinition(
            id: "hidden.study-streak",
            name: "书页鸟",
            kind: .hidden,
            ordinaryIndex: nil,
            symbolName: "bird.fill",
            silhouetteSymbolName: "bird.fill",
            summary: "一页一页，留下持续学习的轨迹。",
            details: "当学习成为连续几天的习惯，书页鸟会悄悄出现。",
            hiddenRuleID: "study.three-day-streak"
        ),
        CollectibleDefinition(
            id: "hidden.long-workout",
            name: "长跑鱼",
            kind: .hidden,
            ordinaryIndex: nil,
            symbolName: "fish.fill",
            silhouetteSymbolName: "fish.fill",
            summary: "把耐力写进每一次行动。",
            details: "当一次健康行动达到足够时长，长跑鱼会跃出水面。",
            hiddenRuleID: "health.first-sixty-minutes"
        )
    ]

    static let all: [CollectibleDefinition] = ordinary + hidden

    static func definition(id: String) -> CollectibleDefinition? {
        all.first { $0.id == id }
    }

    static func ordinary(at index: Int) -> CollectibleDefinition? {
        guard ordinary.indices.contains(index) else { return nil }
        return ordinary[index]
    }
}
