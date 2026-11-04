# main consolidation — 2026-11-04

用户要求先提交当前进度以便回溯，然后合并，只留下 main；本轮仅本地操作，不推送。

## 回溯点

- 原 main：aafea2c。
- two-stage-cards 的未提交每日 XP 工作已保存为 07eccf5，再通过 93083b9 合入 main；重复部分保留 main 较新的自测与 0 XP 六维反馈行为。
- 两阶段实现来源：c3785b3。合并时同时保留 main 的自测完成跳转和分支的启动／退后台奖励确认，以及 main 的首页六维展开与卡片随后展开逻辑。
- 清理前完整 Git bundle、本地文件归档及逐文件哈希：`/Users/fy/Desktop/LIVELVL-backups/20261104-162618`。
- 主工作区 Xcode 本地状态、.tmp/、output/、tmp/ 和原未跟踪交接文档不纳入提交，原地保留。

## 当前规则与后续

- Today 仅展示幼年体；每次升级在任务事务内保存成熟普通卡及奖励队列，领取确认推进下一张；退后台／重开可确认已经拥有的普通奖励。
- 奖励身份继续采用 ordinary.level.<level>；已拥有卡保留未查看状态。每日任务 XP 上限仍为 400，塔罗继续独立。
- 原 CompanionStage raw 值与资源暂时保留兼容；本次没有删除或重制图片、卡库或用户存档，没有导入正式素材。
- 四份旧交接中关于“main 尚未合并两阶段”的描述从本次合并起属于历史记录。
- 已有磁盘测试包含旧 Completion schema 升级、存档重开、普通卡确认、幂等和保存失败回滚；旧四阶段卡片状态转换后继续升级、领取、再重开的完整兼容链路仍待样本阶段补验。
- 素材及映射确认后再接少量样本；完整测试、统一 Debug 和 iPhone 17 Pro 人工交互验收继续延后。

## 本次验证

合并结果：93 tests / 7 suites 全部通过，xcodebuild test 返回 0。

覆盖 CardGrowthLifecycleTests、CardRewardServiceTests、CompanionProgressionEngineTests、DailyTaskXPPersistenceTests、TodayCompanionLevelCardTests、DailyTaskXPTests、LifeFieldPresentationTests。

按既有登记排除 CompanionPointCloudRepositoryTests.swift 编译 isolation 问题，以及 LifeFieldPresentationTests/accessibilityDetailProvidesAScrollContainerForLongSources()。未宣称全量测试通过。

结果：`/Users/fy/Desktop/LIVELVL-backups/20261104-162618/consolidation-tests.xcresult`。
