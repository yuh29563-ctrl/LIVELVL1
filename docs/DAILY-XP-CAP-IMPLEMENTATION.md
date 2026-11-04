# 每日 400 XP：实现与验证记录

更新时间：2026-09-23

本阶段只实现每日任务 XP 规则。分支 `codex/daily-xp-cap`，工作区 `.worktrees/daily-xp-cap`，基于 `main` 的 `2db7726`。未合并、未推送；收藏卡成长规则和正式图片接入仍待下一阶段确认。

## 已实现行为

- 按完成时设备当前日历、时区的自然日，汇总所有有效完成记录的实际 XP；每日最多新增至 400 XP。
- 剩余额度不足时部分到账。达到上限仍完成任务、保存行为事实、完整发金币，也可触发行为型隐藏奖励。
- 同一任务同一天重复提交返回原完成记录，不重复增加 XP、金币或重播完成反馈。
- 撤销只扣实际 XP；释放原日期额度，不给今天额外额度，不补发其他已完成任务的差额，不结转次日。重复撤销无副作用。
- 金币沿用每 1 标称 XP 对应 1 最小单位（显示为 0.1 金币）。撤销优先读原发放流水；余额不足时最多扣至零，保留请求扣回额与实际扣回额。
- 旧 XP、等级、流水与收藏记录不追溯重算。升级当天已有旧记录计入额度，即使旧记录超过 400 也保留原值。
- 时区变化后重新按当前时区归类原始时间戳，不重写历史，不增加系统时间防作弊。

## 数据接口与保存边界

- `DailyTaskXPPolicy` 为纯规则层；使用日历生成半开日期区间 `[start, end)`，支持 23/25 小时夏令时日。
- `TaskRewardCoordinator.preview` 与正式结算共用规则；确认时重新读取最新已保存记录，预览不预占额度。
- `complete` 新增可注入 `calendar`，返回 `TaskCompletionResult(completion, wasCreated)`。
- `revoke` 返回是否实际撤销；先验证持久化身份，避免重复扣减。
- 新完成的 `Completion.xp` 是实际到账，新增可选 `nominalXP` 保存当时标称值。`recordedNominalXP` 对旧记录回退到原 `xp`，任务编辑不改历史快照。
- 调用方先保存任务和 Progress。结算在同一容器的独立、禁用自动保存的上下文内处理完成记录、总 XP 和金币，以一次保存提交；成功后刷新调用方上下文。失败时调用方数据不受影响。
- 采用独立上下文是实测需要：当前 SwiftData 运行环境的保存失败后，直接 `rollback()` 仍可能留下注册对象的乐观改动。真实只读磁盘存档测试覆盖了这一边界。
- 任务提交和卡片处理为两个提交阶段。`CardRewardService.reconcilePersistedRewards` 也隔离保存，避免失败后留下虚假的待领取记录；新增可选 `previousLevel` 保留原奖励延迟语义。重试只处理已保存事实，不重发任务 XP、金币。
- 原有卡片成长映射、`awardKey`、CollectionProgress/PendingCardReward/OwnedCollectible 模型与素材均未改变。

## 界面

- Today 显示今日已获得 XP、400 上限和剩余额度，支持文字换行。
- 确认弹窗显示预计实际到账和完整金币，最终以保存时额度为准。
- 已完成行及 VoiceOver 文案读取实际到账；部分到账同时说明标称 XP。重启后仍读取保存快照。
- 0 XP 保留完成反馈，跳过 XP 空间流动和升级路径。撤销提示使用“扣回实际 XP”。
- 0 XP 记录仍计入活动次数，不再被活动页误判为没有记录；XP 图表继续展示真实历史，包括超过 400 的旧记录。
- 午夜定时、进入前台、日期/时区/系统时钟通知刷新 Today。刷新不依赖今日塔罗状态。

## 验证结果

限定范围最终通过 **123 项测试、13 个测试组**；不是完整测试或完整模拟器验收。

新增测试覆盖额度不足/封顶、重复完成与撤销、跨日、时区、夏令时、确认时重算、原金币流水扣回、0 XP 行为奖励、展示文案和活动次数，以及 SwiftUI 实时查询刷新。

磁盘测试使用冻结的旧 Completion 实体（无 nominalXP），实际创建旧 SQLite 存档，再升级、保存并重新打开。验证 XP、标称回退、旧 UUID 缺失记录、金币、收藏进度、待领取卡、获取原因和已查看/未查看状态保留。还验证部分到账记录重开、重复撤销与重新完成。

失败测试使用真实只读存档使保存抛错，验证完成/撤销失败不污染界面上下文；卡片失败后恢复存档重试只产生一个 awardKey，不重发任务奖励。测试日志中的只读写入错误（513）是这些预期场景。

本轮结果文件：`/tmp/livelvl-daily-xp.hDYljc/verified.xcresult`；日志：`/tmp/livelvl-daily-xp.hDYljc/verified.log`。临时测试产物未加入仓库。

复跑时在本工作区执行（将 destination 和输出路径替换为可用的测试设备及新路径）：

```sh
xcodebuild test \
  -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL \
  -destination 'platform=iOS Simulator,id=F5BAE1AC-AAF1-43C7-8811-4AEDEAFE99C3' \
  -derivedDataPath /tmp/livelvl-daily-xp-review \
  -only-testing:LIVELVLTests/DailyTaskXPTests \
  -only-testing:LIVELVLTests/DailyTaskXPPersistenceTests \
  -only-testing:LIVELVLTests/DailyTaskXPPresentationTests \
  -only-testing:LIVELVLTests/TaskRewardCoordinatorTests \
  -only-testing:LIVELVLTests/CoinLedgerTests \
  -only-testing:LIVELVLTests/TaskRewardFeedbackTests \
  -only-testing:LIVELVLTests/TodayCompanionLevelCardTests \
  -only-testing:LIVELVLTests/YouActivityHistoryTests \
  -only-testing:LIVELVLTests/GrowthEngineTests \
  -only-testing:LIVELVLTests/CardRewardServiceTests \
  -only-testing:LIVELVLTests/HiddenAchievementEngineTests \
  -only-testing:LIVELVLTests/CardRewardPresentationTests \
  -only-testing:LIVELVLTests/CollectionPersistenceTests \
  '-skip-testing:LIVELVLTests/CardRewardPresentationTests/collectionTargetResolvesByStableIdentityAfterReordering()' \
  -parallel-testing-enabled NO \
  EXCLUDED_SOURCE_FILE_NAMES=CompanionPointCloudRepositoryTests.swift \
  CODE_SIGNING_ALLOWED=NO
```

## 最终统一 Debug 待办

1. 已知 `CompanionPointCloudRepositoryTests.swift` actor/protocol isolation 编译问题，本阶段仅通过命令参数隔离，没有修改文件。
2. `CardRewardPresentationTests.collectionTargetResolvesByStableIdentityAfterReordering()` 在本轮环境失败。已在临时目录使用未修改的 `2db7726` 重跑复现：20 项该组测试中其余 19 项通过。基线日志 `/tmp/livelvl-xp-baseline.DyEss3/baseline.log`。该测试依赖系统符号图片的 accessibilityIdentifier 解析；本次未改 Tab 解析器或飞行动画，最终统一 Debug 单独调查。
3. 正式素材样本接入后，再做完整测试、构建和 iPhone 17 Pro 人工交互验收，包括实际 VoiceOver、Dynamic Type、Reduce Motion、奖励动画及收藏/塔罗回归。本轮验证了展示模型文案与实时数据查询，不宣称完成上述人工验收。

主工作区的 Xcode 状态、`.tmp/`、两份未跟踪交接文档及其他既有 worktree 保持原样。未批量处理或导入图片。
