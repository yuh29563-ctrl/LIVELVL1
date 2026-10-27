import Foundation

enum AssessmentAnswer: Int, CaseIterable, Codable, Identifiable, Sendable {
    case stronglyDisagree = 0, disagree, slightlyDisagree, neutral
    case slightlyAgree, agree, stronglyAgree, notApplicable

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .stronglyDisagree: "完全不同意"
        case .disagree: "比较不同意"
        case .slightlyDisagree: "稍微不同意"
        case .neutral: "既不同意也不反对"
        case .slightlyAgree: "稍微同意"
        case .agree: "比较同意"
        case .stronglyAgree: "完全同意"
        case .notApplicable: "不适用／无法判断"
        }
    }
}

struct AssessmentQuestion: Identifiable, Equatable, Sendable {
    let id: String
    let dimension: LifeDimension
    let statement: String
}

enum AssessmentValidationError: LocalizedError {
    case unanswered(LifeDimension), noApplicableAnswers(LifeDimension), notDue

    var errorDescription: String? {
        switch self {
        case let .unanswered(dimension): "请完成\(dimension.title)的十道题，也可以选择“不适用／无法判断”。"
        case let .noApplicableAnswers(dimension): "\(dimension.title)至少需要一个可判断的答案，才能计算状态。"
        case .notDue: "距离上次自测尚未满十五个自然日，请到期后再更新。"
        }
    }
}

enum AssessmentQuestionnaire {
    static let version = 1
    // Product-adapted statements informed by OECD/WHO/CFPB measurement themes.
    // The combined seven-choice questionnaire has no validated clinical standard score.
    static let questions: [AssessmentQuestion] = LifeDimension.allCases.flatMap { dimension in
        statements(for: dimension).enumerated().map { index, statement in
            AssessmentQuestion(id: "\(dimension.rawValue).\(String(format: "%02d", index + 1))",
                               dimension: dimension, statement: statement)
        }
    }

    static func questions(for dimension: LifeDimension) -> [AssessmentQuestion] {
        questions.filter { $0.dimension == dimension }
    }

    static func rating(for dimension: LifeDimension, answers: [String: AssessmentAnswer]) throws -> Double {
        let group = questions(for: dimension)
        guard group.allSatisfy({ answers[$0.id] != nil }) else {
            throw AssessmentValidationError.unanswered(dimension)
        }
        let values = group.compactMap { answers[$0.id] }.filter { $0 != .notApplicable }
        guard !values.isEmpty else { throw AssessmentValidationError.noApplicableAnswers(dimension) }
        // Keep full precision on the existing 0–10 storage scale; round only for display.
        return Double(values.reduce(0) { $0 + $1.rawValue }) / Double(values.count) * 10 / 6
    }

    static func entries(
        answers: [String: AssessmentAnswer], weeklyTargets: [LifeDimension: Int]
    ) throws -> [AssessmentEntry] {
        try LifeDimension.allCases.map {
            AssessmentEntry(dimension: $0, rating: try rating(for: $0, answers: answers),
                            weeklyTarget: min(7, max(1, weeklyTargets[$0] ?? 3)))
        }
    }

    private static func statements(for dimension: LifeDimension) -> [String] {
        switch dimension {
        case .health: [
            "我对自己目前的整体健康状况感到满意。",
            "我的身体状态能支持我完成日常生活。",
            "我的心理状态总体令我满意。",
            "我通常有足够的精力处理重要的事。",
            "我早晨醒来时，通常觉得自己得到了充分休息。",
            "我对自己近两周的训练状态感到满意。",
            "我对自己近两周的饮食状况感到满意。",
            "身体疼痛或不适很少妨碍我的日常生活。",
            "我的身体状态允许我完成想做的日常活动。",
            "情绪压力很少妨碍我的日常生活。"
        ]
        case .learning: [
            "我感到自己在持续学习、改变和成长。",
            "我正在学习的内容对自己有价值。",
            "我有机会学习自己想学的内容。",
            "我为学习留出了符合自己期望的时间。",
            "我清楚自己下一步想学什么。",
            "我能把学到的新东西用到现实生活中。",
            "遇到不懂的内容时，我知道怎样继续寻找答案。",
            "我能感受到自己近期的学习进展。",
            "我拥有持续学习所需的资源和条件。",
            "我对自己目前的学习进展感到满意。"
        ]
        case .career: [
            "我对自己目前的主要活动感到满意。",
            "我认为这项活动对自己有意义。",
            "我能从这项活动中获得成就感。",
            "我能在一定程度上自主决定如何完成这项活动。",
            "我清楚这个阶段想在这项活动中达成什么。",
            "我感到自己正在朝这个目标前进。",
            "这项活动对我的要求总体在可承受范围内。",
            "需要帮助时，我能获得开展这项活动所需的支持。",
            "我在这项活动中的付出能够被看见和尊重。",
            "我对这项活动与其他生活责任之间的平衡感到满意。"
        ]
        case .finance: [
            "我对家庭目前的财务状况感到满意。",
            "我能够比较从容地应对日常必要开支。",
            "如果出现意外的大额支出，我有能力应对。",
            "一个月结束时，我通常还能留下可自由安排的钱。",
            "我感到自己正逐步为未来建立财务保障。",
            "我对现有的钱或储蓄能否满足未来需要感到安心。",
            "我能按计划处理欠款或其他财务承诺。",
            "我的财务状况允许我在重要的事情上作出选择。",
            "财务问题很少持续干扰我的日常生活。",
            "我对自己的财务安排有掌控感。"
        ]
        case .relationships: [
            "我对自己目前的人际关系感到满意。",
            "我有能够信任并倾诉的人。",
            "真正需要帮助时，我能找到愿意支持我的人。",
            "我有机会支持自己在意的人。",
            "在重要关系中，我感到自己被理解。",
            "在重要关系中，我感到自己被尊重。",
            "我与在意的人有令自己满意的交流。",
            "我很少感到孤独或被排除在外。",
            "与他人发生分歧时，我能尝试好好沟通。",
            "我能在关系中表达自己的需要和边界。"
        ]
        case .interests: [
            "我对自己拥有多少时间做喜欢的事感到满意。",
            "我对自己目前使用时间的方式感到满意。",
            "我觉得自己喜欢的活动对我有意义。",
            "近两周，我有机会实际参与喜欢的活动。",
            "做喜欢的事时，我通常感到愉快。",
            "我能自主选择自己想参与的兴趣活动。",
            "做完喜欢的事后，我通常感到放松或恢复了精力。",
            "我有机会探索新的兴趣或体验。",
            "即使有其他责任，我仍能为喜欢的事留出一些空间。",
            "我对自己目前的兴趣生活感到满意。"
        ]
        }
    }
}
