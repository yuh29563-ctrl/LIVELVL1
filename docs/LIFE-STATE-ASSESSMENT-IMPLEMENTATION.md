# 十五日六维自测：实现与验证

日期：2026-10-27。分支：codex/life-state-assessment。基于 main 1602449，工作区 /Users/fy/.codex/worktrees/life-state-assessment/LIVELVL。

## 已实现规则

- 六维各十题，共六十题。事业包括工作、学业、家务和照护；健康第六题为训练状态评价，第七题为饮食状况评价。题库稳定 ID 为 dimension.01...dimension.10，版本 1。
- 七档同意程度对应 0...6，无默认答案；不适用/无法判断单独排除。每题均需选择，每维至少一个有效答案才能提交，平均后转换为 0–100。
- 内部继续使用 0–10 的既有数值比例，界面乘 10 显示。原始答案和未叠加行动的基线保留完整精度，界面再取整/保留一位。
- 以设备当前日历和时区计算，提交日期之后第十五个自然日零点开放下一次自测；UI 和保存入口均检查资格。不是固定 360 小时。
- 首页显示“十五天过去了，是否更新您的状态？”，可更新或这次跳过。跳过只保存 reminderSkippedAt，不改自测日期、答案或资格；十五日后重新提示，期间也可从首页或“我的”补测。
- 每维最近十五个自然日期（含今天，截止当前时间），一天有至少一条有效完成即记一个行动日。不同任务、同日多次完成不重复增加行动日；0 XP 有效，撤销最后一条该日完成才移除该日。未来记录排除，时区改变后按当前时区重分组。
- 十五日目标 = ceil(clamp(每周目标, 1...7) × 15 / 7)。默认每周三天对应七天。
- 当前状态 = min(100, 最新自测基线 + min(10, 行动天数/目标天数 × 10))。同日追加行动、超过目标和总分满分均不伪造上涨。行动过期后回到基线，不扣到基线以下，不逐期复利。
- 首页主节点直接显示当前值。节点详情说明基线、行动加成、行动天数和来源；首页说明图的意义并显示上次自测日期。
- 完成任务后即时显示行动进度和实际分值前后变化，并提供 VoiceOver 公告。0 XP 仍高亮对应维度，但不播放 XP 飞行、不进入成长核心或升级阶段。

## 持久化与迁移

StateSnapshot 新增可选字段 assessmentVersion、selfRatingsData、assessmentAnswersData、reminderSkippedAt。旧快照及旧 actionScores 原值不改；在第一次新问卷前，当前自测基线优先读取 DimensionProfile.selfRating，缺失则回退旧快照对应值。新快照同时保存当时总状态和独立基线，动态计算只使用独立基线，避免重复叠加。

保存使用独立、禁用自动保存的 ModelContext。保存前读取最新提交、任务与完成事实，在同一次保存中写六维资料和新快照。失败不污染 UI 上下文，不吞掉错误；成功后刷新调用方查询。重复/提前提交不能生成新快照。跳过使用同样的隔离写入。

真实磁盘测试冻结 main 旧 StateSnapshot 实体布局，创建 SQLite，再用新模型升级、写入新答案、重新打开，验证历史、XP、金币、收藏进度、待领取与未查看标记完整保留。另一套已有每日 XP 磁盘迁移测试也在本轮回归运行。

## 验证记录

最终聚焦测试 **116 项，14 组通过**。包括 LifeStateEngineTests、AssessmentQuestionnaireTests、AssessmentSettlementTests、LifeStateSummaryTests、LifeStatePersistenceTests、LifeStateActionFeedbackTests、LifeStateLiveQueryTests、DailyTaskXPTests、DailyTaskXPPersistenceTests、DailyTaskXPPresentationTests、LifeFieldPresentationTests（排除下面的既有失败项）、TaskRewardFeedbackTests、TodayCompanionLevelCardTests、RadarGeometryTests。

日志：/tmp/livelvl-state.LZCQVt/focused-final.log

结果：/tmp/livelvl-state.LZCQVt/focused-final.xcresult

独立静态复核覆盖核心计分、数据边界和界面接线。已修复两项发现：节点 VoiceOver 增加行动日进度（有先失败后通过的回归测试）；冷却期说明页面增加滚动以适应超大字体。没有未处理的本轮复核发现。

本轮专用测试设备：LIVELVL State Assessment Tests，8E224CA4-E265-4683-92AC-D61F41A3BF85，iOS 26.5。首次复用旧测试设备出现 SpringBoard Busy 启动错误，随后创建独立测试设备，未修改其他工作区或清除用户模拟器存档。

未执行完整测试、独立 Debug 构建或 iPhone 17 Pro 人工交互验收；聚焦测试包含其必要的编译与测试宿主运行。未宣称已完成人工 VoiceOver、Dynamic Type、Reduce Motion 或真机验收。

## 最终统一 Debug 待办

1. CompanionPointCloudRepositoryTests.swift 的既有 actor/protocol isolation 问题，本轮通过 EXCLUDED_SOURCE_FILE_NAMES 隔离，未改文件。
2. LifeFieldPresentationTests.accessibilityDetailProvidesAScrollContainerForLongSources() 无法从 SwiftUI UIView 树查到滚动标识。使用 main 的三个原始展示文件在同一专用设备复跑，25 项中这一个同样失败，证据为 /tmp/livelvl-state.LZCQVt/baseline-display.log 与 baseline-display.xcresult。聚焦最终运行仅排除该项，保留测试原样待统一 Debug。
3. 每日 XP 阶段已经登记的 CardRewardPresentationTests.collectionTargetResolvesByStableIdentityAfterReordering() 仍待最终 Debug，非本轮改动。
4. 正式卡样本阶段后，统一验收六十题作答/返回/保存、每十五日开放/跳过/跨日、0 XP 维度反馈、图解说明、超大字体、VoiceOver 和 Reduce Motion，以及收藏/塔罗端到端回归。

## 来源与交付边界

题目是用户确认的 LIVELVL 产品改写版，参考 OECD 主观幸福感领域、WHO 健康测量与 CFPB 财务福祉主题，统一七档后不沿用原量表的验证声明或标准分。不是诊断工具。

- OECD：https://www.oecd.org/en/publications/oecd-guidelines-on-measuring-subjective-well-being-2025-update_9203632a-en/full-report/core-and-extended-survey-modules_37f842ef.html
- WHO：https://www.who.int/publications/m/item/WHO-UCN-MSD-MHE-2024.01
- CFPB：https://www.consumerfinance.gov/data-research/research-reports/financial-well-being-scale/

本轮不接正式图片，不修改 XP/金币结算、卡片成长、awardKey、收藏/塔罗存档语义。未合并 main、未推送、未删除 worktree。主工作区中的 Xcode 状态、.tmp、两份用户交接文档及其他已有文件保持原样。
