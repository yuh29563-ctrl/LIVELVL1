import Foundation

struct TarotReading: Equatable, Sendable {
    let theme: String
    let attention: String
    let action: String
}

struct TarotCardDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let number: Int
    let romanNumeral: String
    let name: String
    let englishName: String
    let upright: TarotReading
    let reversed: TarotReading

    var artworkAssetName: String {
        String(format: "TarotRWS%02d", number)
    }

    func reading(for orientation: TarotOrientation) -> TarotReading {
        switch orientation {
        case .upright: upright
        case .reversed: reversed
        }
    }
}

extension TarotCatalog {
    static let cards: [TarotCardDefinition] = [
        card(
            0, "0", "fool", "愚者", "THE FOOL",
            upright: reading(
                "新的开始、自由与信任。今天适合用开放心态接近未知。",
                "轻盈不等于毫无准备，别把冲动误认为勇气。",
                "为想尝试的方向迈出一个足够小、可以收回的第一步。"
            ),
            reversed: reading(
                "迟疑或冒进正在拉扯你，新的起点因此显得不稳定。",
                "先分清你是在尊重风险，还是被恐惧或冲动推动。",
                "写下最坏结果与可承受边界，再决定今天是否行动。"
            )
        ),
        card(
            1, "I", "magician", "魔术师", "THE MAGICIAN",
            upright: reading(
                "意志、资源与行动正在汇合，你拥有启动事情的条件。",
                "不要只展示能力，也别把注意力分散到太多目标。",
                "选择一个意图，立即使用手边最成熟的资源推进它。"
            ),
            reversed: reading(
                "能量分散、信心不足，或表达与真实能力之间出现落差。",
                "警惕过度承诺、操控局面或等待完美工具。",
                "找出当前最关键的一项能力缺口，今天只补这一处。"
            )
        ),
        card(
            2, "II", "high-priestess", "女祭司", "THE HIGH PRIESTESS",
            upright: reading(
                "直觉、安静与尚未显露的信息值得被认真聆听。",
                "沉默可以保护洞察，也可能掩盖你不愿面对的事实。",
                "在回应之前留十分钟安静，记录第一层真实感受。"
            ),
            reversed: reading(
                "外界噪音或自我怀疑，让你暂时听不清内在判断。",
                "猜测不是直觉，秘密也不一定意味着更深的真相。",
                "暂停征求更多意见，回到已经掌握的事实重新判断。"
            )
        ),
        card(
            3, "III", "empress", "皇后", "THE EMPRESS",
            upright: reading(
                "滋养、创造与丰盛正在生长，温柔也能产生实际成果。",
                "照顾他人时别忽略自己的身体、节奏与边界。",
                "为一件正在成长的事提供具体资源、时间或关怀。"
            ),
            reversed: reading(
                "过度付出、创造受阻，或对安全感的需求正在上升。",
                "不要用照顾别人来回避自己的匮乏和疲惫。",
                "收回一小部分精力，先满足一个被忽略的基本需要。"
            )
        ),
        card(
            4, "IV", "emperor", "皇帝", "THE EMPEROR",
            upright: reading(
                "结构、责任与稳定边界能帮助你掌握当前局面。",
                "秩序若失去弹性，容易变成控制或不必要的强硬。",
                "为最重要的目标明确一条规则、期限或责任归属。"
            ),
            reversed: reading(
                "控制失衡、规则僵化，或缺乏明确结构让事情停滞。",
                "别用权威压过沟通，也不要逃避本应承担的责任。",
                "检查一条已经失效的规则，今天将它调整得更可执行。"
            )
        ),
        card(
            5, "V", "hierophant", "教皇", "THE HIEROPHANT",
            upright: reading(
                "传统、学习与共同规范能提供可靠的参照和支持。",
                "尊重经验不等于放弃独立思考，也别为了合群压抑疑问。",
                "向可信赖的导师、方法或成熟流程求证一个问题。"
            ),
            reversed: reading(
                "旧规则与你的真实经验产生冲突，需要重新理解权威。",
                "反叛本身不是答案，盲从也不会带来真正的认同。",
                "说清你不同意的具体部分，并提出一个可验证的替代方案。"
            )
        ),
        card(
            6, "VI", "lovers", "恋人", "THE LOVERS",
            upright: reading(
                "关系、价值一致与真诚选择成为今天的核心。",
                "吸引力不能替代承诺，选择也意味着放下其他可能。",
                "用一句坦诚的话确认你与重要的人或目标是否同向。"
            ),
            reversed: reading(
                "价值冲突、沟通失衡，或回避选择正在消耗关系。",
                "不要只追求表面和谐，也别把责任全部归给对方。",
                "列出彼此真正不同的需求，再决定可协商与不可退让之处。"
            )
        ),
        card(
            7, "VII", "chariot", "战车", "THE CHARIOT",
            upright: reading(
                "方向、意志与自我掌控让你能够穿过阻力前进。",
                "速度不是唯一指标，失去方向的推进只会增加消耗。",
                "明确今天的终点，并把精力集中到最直接的一条路径。"
            ),
            reversed: reading(
                "方向混乱、推进受阻，或不同欲望正在互相拉扯。",
                "用力过猛可能扩大失控感，暂缓不等于失败。",
                "先停止一项无效推进，重新校准目标和可控范围。"
            )
        ),
        card(
            8, "VIII", "strength", "力量", "STRENGTH",
            upright: reading(
                "勇气、耐心与温和的自制力比强硬更有力量。",
                "真正的克制不是压抑情绪，而是理解它再选择回应。",
                "面对一件让你紧张的事，用更慢、更柔和的方式处理。"
            ),
            reversed: reading(
                "自我怀疑、精力下降，或压抑太久的情绪正在反弹。",
                "别因暂时脆弱否定全部能力，也不要逞强掩盖需要。",
                "承认一个具体困难，并向可信赖的人提出明确支持请求。"
            )
        ),
        card(
            9, "IX", "hermit", "隐者", "THE HERMIT",
            upright: reading(
                "独处、反思与内在指引能帮助你看清真正重要的事。",
                "抽离是为了理解，不是无限期逃开关系与现实。",
                "留出一段无干扰时间，写下你已经知道却未承认的答案。"
            ),
            reversed: reading(
                "孤立、过度内省，或害怕独处都可能让视野变窄。",
                "别把封闭误认为清醒，也别依赖外界替你做决定。",
                "选择一位可靠的人交流，同时保留自己的最终判断。"
            )
        ),
        card(
            10, "X", "wheel-of-fortune", "命运之轮", "WHEEL OF FORTUNE",
            upright: reading(
                "周期正在转动，变化与新机会可能打破原有节奏。",
                "好运并非完全可控，别把偶然结果当作永久保证。",
                "识别正在打开的窗口，完成一个顺势而为的动作。"
            ),
            reversed: reading(
                "延迟、反复或失控感提醒你正在经历周期的低点。",
                "抵抗所有变化只会增加摩擦，但也无需把一切归咎命运。",
                "区分可控与不可控事项，只修正今天能够影响的一环。"
            )
        ),
        card(
            11, "XI", "justice", "正义", "JUSTICE",
            upright: reading(
                "事实、责任与公平选择需要你保持清晰和诚实。",
                "公正不是冷漠，也不要只挑选支持自己立场的证据。",
                "核对关键事实，并为自己的决定承担一个明确后果。"
            ),
            reversed: reading(
                "偏见、逃避责任或信息失衡正在影响你的判断。",
                "先停止自我辩护，看看自己是否忽略了不方便的事实。",
                "修正一项不公平安排，或承认一个需要补偿的错误。"
            )
        ),
        card(
            12, "XII", "hanged-man", "倒吊人", "THE HANGED MAN",
            upright: reading(
                "暂停、换位与主动放下，会带来不同于推进的洞察。",
                "等待需要目的，长期停滞不应被美化为顺其自然。",
                "暂时放下一个固有结论，从相反角度重新描述问题。"
            ),
            reversed: reading(
                "无效等待、拖延或不愿放下，让牺牲失去意义。",
                "别继续投入只为证明过去没有浪费，也别等待完美时机。",
                "为停滞设定期限，到点后明确选择继续或退出。"
            )
        ),
        card(
            13, "XIII", "death", "死神", "DEATH",
            upright: reading(
                "结束、转化与清理正在为新的阶段腾出空间。",
                "告别可能伴随失落，但抓紧旧状态会延长消耗。",
                "完成一个明确的结束动作，整理、删除或正式道别。"
            ),
            reversed: reading(
                "抗拒结束、旧模式反复，或对变化的恐惧让转化停住。",
                "不要把熟悉误认为安全，也别强迫自己立刻释怀。",
                "指出最难放下的具体部分，先减少一次对它的依赖。"
            )
        ),
        card(
            14, "XIV", "temperance", "节制", "TEMPERANCE",
            upright: reading(
                "平衡、调和与适度推进，有助于不同需求共存。",
                "折中不等于没有立场，平静也不代表问题已经消失。",
                "把两种看似冲突的资源组合成一个可持续的小方案。"
            ),
            reversed: reading(
                "失衡、过量或节奏紊乱提醒你重新校准日常。",
                "短期补偿可能掩盖长期问题，避免在极端之间摆动。",
                "减少一个过量输入，并为今天恢复清晰的开始与结束。"
            )
        ),
        card(
            15, "XV", "devil", "恶魔", "THE DEVIL",
            upright: reading(
                "欲望、依附与自我设限正在显露它们对你的影响。",
                "享受本身不是错误，关键是你是否仍保有选择。",
                "指出一个反复控制你的习惯，并中断它一次。"
            ),
            reversed: reading(
                "你开始看见束缚的结构，并有机会恢复自主权。",
                "摆脱依附需要持续行动，单次醒悟不会自动解除模式。",
                "移除一个触发条件，或向外界公开你的改变承诺。"
            )
        ),
        card(
            16, "XVI", "tower", "高塔", "THE TOWER",
            upright: reading(
                "突发变化或真相揭露，正在动摇原本不稳固的结构。",
                "先保证安全，不必在混乱中立刻解释所有意义。",
                "处理最紧急且可控的一件事，再评估哪些结构需要重建。"
            ),
            reversed: reading(
                "你可能正在避免必要的改变，或经历较内在的震荡。",
                "压住裂缝只能延后问题，恐惧也可能夸大真实风险。",
                "主动拆除一个已失效的小部分，避免它积累成更大崩塌。"
            )
        ),
        card(
            17, "XVII", "star", "星星", "THE STAR",
            upright: reading(
                "希望、恢复与灵感让你重新看见值得相信的方向。",
                "愿景需要现实承接，不要因为期待结果忽略眼前资源。",
                "为最想靠近的方向，完成一个十分钟内能开始的动作。"
            ),
            reversed: reading(
                "信心低落、希望变远，或你暂时看不见自己的恢复力。",
                "失望不是最终结论，别用一次受挫否定所有可能。",
                "回顾一件曾经熬过的事，找出当时真正帮助你的因素。"
            )
        ),
        card(
            18, "XVIII", "moon", "月亮", "THE MOON",
            upright: reading(
                "不确定、梦境与深层情绪让今天的感受比事实更强烈。",
                "恐惧会填补信息空白，暂时不要把猜测当成结论。",
                "记录事实与想象各有哪些，等待更多信息后再做决定。"
            ),
            reversed: reading(
                "迷雾开始散开，被压住的情绪或误解逐渐浮现。",
                "真相出现时仍可能令人不适，不要急着再次否认。",
                "确认一项此前模糊的信息，并据此修正一个小决定。"
            )
        ),
        card(
            19, "XIX", "sun", "太阳", "THE SUN",
            upright: reading(
                "清晰、活力与喜悦让成果更容易被看见和分享。",
                "乐观不应忽略他人的处境，也别因顺利而过度承诺。",
                "公开肯定一个真实进展，并把这份能量投入下一步。"
            ),
            reversed: reading(
                "喜悦被延迟、自信打折，或你难以接纳已经拥有的成果。",
                "小挫折不等于失败，强装积极也会遮住真实需要。",
                "列出今天已经成立的三件好事，只选择一件继续扩大。"
            )
        ),
        card(
            20, "XX", "judgement", "审判", "JUDGEMENT",
            upright: reading(
                "觉醒、回顾与回应召唤，要求你做出更诚实的选择。",
                "反思不是反复惩罚自己，真正重要的是承担与更新。",
                "确认一个不能再拖延的决定，并写下今天的回应。"
            ),
            reversed: reading(
                "自我怀疑、逃避召唤，或过度批判让你难以前进。",
                "别等待所有人认可，也不要让过去永久定义自己。",
                "把一项内疚转化为可补救的具体行动并开始执行。"
            )
        ),
        card(
            21, "XXI", "world", "世界", "THE WORLD",
            upright: reading(
                "完成、整合与阶段圆满，让经历形成更完整的意义。",
                "完成值得庆祝，也别急着用下一个目标覆盖当下成果。",
                "正式收尾一件事，记录你获得的能力与经验。"
            ),
            reversed: reading(
                "未完成感、收尾拖延，或最后一步迟迟没有落地。",
                "追求完美可能阻止真正结束，遗漏也需要被具体识别。",
                "列出完成所缺的最后一步，并为它安排明确时间。"
            )
        ),
    ]

    static func definition(id: String) -> TarotCardDefinition? {
        cards.first { $0.id == id }
    }

    private static func card(
        _ number: Int,
        _ romanNumeral: String,
        _ slug: String,
        _ name: String,
        _ englishName: String,
        upright: TarotReading,
        reversed: TarotReading
    ) -> TarotCardDefinition {
        TarotCardDefinition(
            id: String(format: "major.%02d.%@", number, slug),
            number: number,
            romanNumeral: romanNumeral,
            name: name,
            englishName: englishName,
            upright: upright,
            reversed: reversed
        )
    }

    private static func reading(
        _ theme: String,
        _ attention: String,
        _ action: String
    ) -> TarotReading {
        TarotReading(theme: theme, attention: attention, action: action)
    }
}
