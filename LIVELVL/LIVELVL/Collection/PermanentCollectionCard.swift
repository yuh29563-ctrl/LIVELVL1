import SwiftUI

nonisolated struct PermanentCollectionCard: Identifiable, Equatable, Sendable {
    let id: String
    let number: Int
    let title: String
    let series: String
    let artworkName: String
    let story: String
    let paragraphs: [String]

    var numberedTitle: String { String(format: "%02d｜%@", number, title) }
}

nonisolated enum PermanentCollectionCatalog {
    // This order is independent of earned-card dates, levels, and reward identity.
    static let cards: [PermanentCollectionCard] = [
        .init(
            id: "permanent.journey.awareness", number: 1,
            title: "异界水母 · 感知此刻", series: "旅途指引", artworkName: "JourneyGuide01",
            story: "它在没有昼夜的海中漂浮，以身体的起伏辨认潮汐。每当迷失方向，它便安静下来，等待自己与水流重新相遇。",
            paragraphs: [
                "第一次进入 LIVELVL，先完成六维状态自测，了解自己在**健康、学习、财务、关系、事业与兴趣**上的当前状态。",
                "「今天」页的六维图是你的起点。点击节点，可以查看分数依据；之后完成相应维度的任务，会为状态积累行动加分。每十五天可重新自测，调整目标，看看自己发生了什么变化。"
            ]
        ),
        .init(
            id: "permanent.journey.action", number: 2,
            title: "星环之门 · 从一步开始", series: "旅途指引", artworkName: "JourneyGuide02",
            story: "这道门没有钥匙。旅人每向它走近一步，环上的微粒便连接一点。直到某天回望，他才发现，门早已在那些微小行动中打开。",
            paragraphs: [
                "在「今天」页点击右上角 **＋**，创建一个准备完成的任务，选择所属维度、预计时长、难度和重复方式。完成后，点击任务并确认，获得经验值与金币。",
                "累计 **200 XP** 达到 Lv.1，此后每累计 **2,000 XP** 升一级。每日任务最多获得 **400 XP**；达到上限后仍可完成任务，金币照常获得，行动也会留下记录。误点完成时，可以撤销。"
            ]
        ),
        .init(
            id: "permanent.journey.memory", number: 3,
            title: "时空沙漏 · 留下经过", series: "旅途指引", artworkName: "JourneyGuide03",
            story: "沙漏里落下的并非沙粒，而是被认真度过的片刻。有些当时微不足道，许久以后，却连成了指向来路的星图。",
            paragraphs: [
                "在「今天」页打开**日记本**，写下今天的经历、感受，或一件不想忘记的小事。文字会自动保存，离开前请确认显示“已自动保存”；通过日记历史入口，可以回看过去。",
                "在「我的」页，查看活动记录与 XP 趋势，回顾哪些日子采取了行动、哪些方向正在积累。日记记录你的感受，活动表与趋势记录你的行动，让变化有迹可循。"
            ]
        ),
        .init(
            id: "permanent.journey.rewards", number: 4,
            title: "共生双核 · 让付出有所回应", series: "旅途指引", artworkName: "JourneyGuide04",
            story: "双核之间始终流动着细小的颗粒。一端向外输送力量，另一端将温度送回。它们因此能够长久前行，而不必耗尽自己。",
            paragraphs: [
                "完成任务会获得金币。打开「奖励」页，点击 **＋**，为自己创建值得期待的现实奖励，并设置金币价格，例如一次出游、一本书，或一段专属于自己的休息时间。",
                "金币足够后即可兑换。兑换会扣除金币，并生成一条“待兑现”记录；在现实中享用奖励后，再标记为**已兑现**。经验推动等级成长，金币帮助你兑现对自己的约定。"
            ]
        ),
        .init(
            id: "permanent.journey.growth", number: 5,
            title: "裂隙之花 · 看见自己的成长", series: "旅途指引", artworkName: "JourneyGuide05",
            story: "它最初只从裂隙中探出一点。后来，每一次向外伸展都留下新的纹路。花终于开放时，曾经狭窄的缝隙，也成了它独有的形状。",
            paragraphs: [
                "「今天」页的伙伴以幼年体陪伴你；升级时，会获得成熟卡奖励。**领取后，下一位幼年伙伴接续成长**，获得的成熟卡则留在「收集」页。",
                "在「收集」中切换卡片，点击放大，再轻点翻面，查看它的故事与获得信息。这里也有「今日塔罗」：每天可免费选择一次，阅读今日主题与行动建议；抽牌不消耗金币，也不影响 XP 和成长进度。",
                "这五张指引卡会一直留在这里。忘记如何使用时，随时回来翻阅。"
            ]
        )
    ]
}

struct PermanentCollectionCardFront: View {
    let card: PermanentCollectionCard

    var body: some View {
        Image(card.artworkName)
            .resizable()
            .scaledToFit()
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius)
                    .fill(LinearGradient(colors: [.white.opacity(0.9), LivingOSTheme.mist.opacity(0.52)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .clipShape(RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LivingOSMetrics.archiveCardCornerRadius)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(card.numberedTitle)，\(card.series)，永久卡片")
            .accessibilityIdentifier("permanent-card-\(card.id)")
    }
}

struct PermanentCollectionCardBack: View {
    let card: PermanentCollectionCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(card.series)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LivingOSTheme.graphite)
                Text(card.numberedTitle)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(card.story)
                    .font(.body.italic())
                    .foregroundStyle(LivingOSTheme.graphite)
                Divider()
                ForEach(Array(card.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(.init(paragraph))
                        .font(.body)
                }
                Text("轻点返回正面")
                    .font(.caption)
                    .foregroundStyle(LivingOSTheme.graphite)
            }
            .foregroundStyle(LivingOSTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .scrollIndicators(.visible)
        .accessibilityIdentifier("permanent-card-back-\(card.id)")
        .accessibilityElement(children: .contain)
    }
}
