# LIVELVL “我的”模块开发交接

更新时间：2026-09-04

## 给下一位开发者 / AI 的直接指令

下一阶段只负责完成 LIVELVL 的“我的”（You）页面。开始前完整阅读：

- `docs/YOU-MODULE-HANDOFF.md`
- `docs/HANDOFF.md`（历史背景，Git 与测试数据可能已经过期）
- `docs/design-assets/living-os-v1/README.md`
- `LIVELVL/LIVELVL/Profile/ProfileView.swift`
- `LIVELVL/LIVELVL/Profile/YouViewComponents.swift`
- `LIVELVL/LIVELVL/Profile/WeeklyStateTimeline.swift`
- `LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift`
- `LIVELVL/LIVELVL/LifeState/LifeStateSummary.swift`
- `LIVELVL/LIVELVL/Persistence/LifeStateModels.swift`
- `LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift`

先核对 Git 和测试状态，再讨论并确认视觉目标。不要因为现有页面已经有六维图，就默认必须保留该图；用户明确表示后续可能删除或替换它。

在用户批准具体设计前，不要大规模改写页面。不要顺手修改 Today、Archive、Rewards，也不要提前开发日记。

## 当前可靠检查点

- 仓库：`/Users/fy/Desktop/LIVELVL`
- 产品代码检查点：本地 `main@fed4fc9`
- 本地标签：`checkpoint-v0.7`
- `fed4fc9` 已包含当前 Today、Archive 和 Rewards 改动。
- 最近完整 Debug 测试：270 tests / 0 failures / 0 skipped。
- 测试设备：iPhone 17 Pro / iOS 26.5 模拟器。
- 测试结果包：`~/Library/Developer/XcodeBuildMCP/workspaces/LIVELVL-a174ddeb78e1/result-bundles/test_sim_2026-09-03T09-04-23-640Z_pid90095_a8996068.xcresult`
- 测试存在 9 条 Swift 6 actor-isolation 警告，当前没有导致测试失败；不要在 You UI 工作中顺手扩大范围处理。
- 当前 `main` 只完成本地合并，未推送；检查时它相对 `origin/main` 领先 107 个提交。

新任务必须确认 `main` 包含 `fed4fc9` 或其后继提交，不能只按文档里的哈希盲目工作。

## 当前工作区保护

主工作区已有用户本地状态：

- `LIVELVL/LIVELVL.xcodeproj/project.pbxproj`
- `LIVELVL/LIVELVL.xcodeproj/project.xcworkspace/xcuserdata/fy.xcuserdatad/UserInterfaceState.xcuserstate`
- `.tmp/`

除非用户对某一文件给出新的明确授权，否则不要修改、覆盖、暂存或提交这些路径。不要通过 reset、checkout、clean 或 stash 处理它们。

Archive 与 Rewards 的工作树和分支目前仍保留。不要为了开始 You 页面而删除它们。

## 推荐的新阶段 Git 方式

从包含 `fed4fc9` 的最新本地 `main` 创建：

- 分支：`codex/you-mvp`
- 隔离工作区：`/Users/fy/Desktop/LIVELVL/.worktrees/you-mvp`

开始前应确认目标分支和工作树不存在。未经用户授权，不要 merge、rebase、push 或清理旧工作树。

## 产品总体状态

用户认为当前产品约完成 70%。前三个主要页面已经接近目标：

### Today

- 展示任务、完成状态、XP、等级和六维人生状态。
- 当前伙伴与成长卡、成熟奖励及隐藏奖励流程已经建立。
- 任务撤销可以影响 XP，但不得追回已经领取的收藏卡或回退伙伴历史。
- 后续可能加入日记入口，但本阶段不开发日记。

### Archive / 收集

- 已实现空间卡组、中心与侧卡透视、底部锚点、投影和说明文字。
- 保留点击展开、滑动、VoiceOver adjustable、Reduce Motion 和新卡落入流程。
- 已知遗留：滑动时仍可能出现视觉频闪。用户已决定稍后单独处理，不要在 You 页面工作中顺手修改。

### Rewards / 奖励

- 已实现整数 `coinUnit` 账本、商品、兑换、历史、退款和记录删除。
- `10 coinUnit = 1.0 金币`；当前点阵中 `100 coinUnit = 1 个完整点`，即每点 10 金币。
- 兑换原子扣币并创建快照；取消兑换退币并让商品返回主界面；删除历史不退币。
- 已兑换商品从主列表隐藏，进入历史；兑换成功反馈为“兑换成功”。
- 商品编辑已改为单击进入；确认气泡锚定到对应控件。
- 不得把现实奖励业务与 `PendingCardReward`、`OwnedCollectible` 或 `CardRewardService` 混合。

## “我的”页面当前实现

主入口是 `ProfileView`，当前页面由以下部分组成：

1. `YouIdentityHeader`
   - 显示 LIVELVL 品牌、YOU 和当前等级。
2. `YouPageTitle`
   - 显示大标题 “You”。
3. 状态文案
   - 当前副标题为“个人操作系统 · 诊断中”。
   - `YouStateHeadline` 根据总分显示“重整 / 调整 / 稳定 / 高能”。
4. `YouStateField`
   - 当前使用粒子云、连线、六边形、人物轮廓和六维节点。
   - 这部分视觉不是必须保留项，用户可能删除或替换整张六维图。
5. `WeeklyStateTimelineView`
   - 固定以周一为一周开始。
   - 展示七天任务完成数与 XP 聚合。
   - Accessibility Dynamic Type 下改为横向滚动。
6. 设置入口
   - 每周评估。
   - 数据与隐私。
   - 设置。
7. Debug 本地重置
   - 仅 Debug 构建显示。
   - 使用两次确认，清除 SwiftData 数据及本地奖励/卡片媒体。

## You 页面数据来源

`ProfileView` 当前读取：

- `[Item]`
- `[Completion]`
- `[Progress]`
- `[DimensionProfile]`
- `[StateSnapshot]`

状态摘要由 `LifeStateSummaryBuilder` 生成，周时间轴由 `WeeklyStateTimelineBuilder` 生成。

真实六维领域名称为：

- 健康 `health`
- 学习 `learning`
- 事业 `career`
- 财务 `finance`
- 关系 `relationships`
- 兴趣 `interests`

## 六维图的边界

必须区分“数据模型”与“当前可视化”：

- 用户允许删除、替换或大幅重做 You 页面上的六维图、粒子人物、六边形和节点布局。
- 不得仅因为删除六维图，就删除或重定义 `LifeDimension`、`DimensionProfile`、`StateSnapshot`、评估结算或 Today 页面依赖的状态摘要。
- 如果新设计不直接显示六维数据，可以继续在后台保留这些模型和评估结果。
- 如果用户最终决定连评估功能也删除，必须另行讨论数据迁移、Today 依赖和历史数据兼容，不能在视觉改造中附带完成。

## 视觉参考的使用方式

已有参考图：

- `docs/design-assets/living-os-v1/you-final.png`

它只代表 Living OS 的排版、留白、灰阶、层级和空间语言，不是必须逐像素复制的最终方案。

参考图中的“身体、专注、秩序、连接、成长、恢复”不是现有领域的真实六维名称。若页面仍展示六维数据，应使用现有 `LifeDimension` 语义；不要为了贴合参考图而静默改写业务含义。

不要把参考 PNG 作为整屏背景或遮罩实现页面。

## 本阶段目标与非目标

### 目标

- 与用户共同确定 You 页面真正承担的信息与操作。
- 建立清晰、克制、可扩展的个人主页层级。
- 保留仍被用户需要的状态、周记录、评估、隐私和设置入口。
- 在不同字体尺寸和设备宽度下完整显示内容。
- 保持本地数据和跨模块领域逻辑稳定。

### 尚未批准，不得自行假设

- 六维图最终保留、删除还是替换为何种摘要。
- 页面是否显示头像、姓名、连续天数、累计 XP、金币或收藏统计。
- 周时间轴是否保留及其最终交互。
- 每周评估是否继续作为一级入口。
- 设置与隐私是否合并、折叠或迁移。
- 页面是否提供日记入口。
- “个人操作系统 · 诊断中”等现有文案是否保留。

### 非目标

- 本阶段不新增日记模型、编辑器、附件、搜索或同步。
- 不改造 Today、Archive、Rewards 的视觉。
- 不调整 XP、金币、收藏奖励或人生状态算法。
- 不接入账户、网络、云同步、分析 SDK 或真实支付。
- 不做 App Store 发布配置或 Release 构建，除非用户另行授权。

## 未来日记功能的预留原则

用户计划最后考虑在 Today 页面加入日记本功能。当前只记录边界，不实现占位功能：

- 日记应作为独立领域和独立开发阶段处理。
- 在明确数据模型前，不复用 `Completion.note`、Reward 备注或卡片媒体存储。
- 必须单独确定日期语义、草稿、编辑历史、删除、搜索、媒体、导出、隐私和数据迁移。
- 如果未来从 You 页面提供日记历史入口，应由正式规格决定；当前 You 布局不要硬编码一个空入口。
- 日记属于敏感长期数据，上线前必须明确本地备份、导出和删除语义。

## 不能破坏的行为

- `StateAssessmentView` 仍能完成六个维度的初始/每周评估并保存 `DimensionProfile` 与 `StateSnapshot`。
- `LifeStateSummaryBuilder` 与 Today 的状态展示继续使用同一份领域数据。
- 周时间轴仍按日聚合真实 `Completion`，不能用演示数据替代。
- “数据与隐私”页面陈述必须与实际本地存储行为一致。
- Debug 全量重置继续覆盖任务、完成记录、进度、状态、收藏、金币、奖励商品、兑换记录及本地媒体。
- Release 构建不得暴露 Debug 重置入口。
- Dynamic Type、VoiceOver 与 Reduce Motion 下功能结果保持一致。
- 四个 Tab 的身份和顺序保持稳定，除非用户明确批准导航重构。

## 建议的设计流程

1. 在真实 iPhone 17 Pro 模拟器打开当前 You 页面并截图。
2. 请用户给出第一项明确目标或参考图，先讨论内容层级再讨论装饰。
3. 明确哪些现有区域保留、删除、合并或替换，特别是六维图和周时间轴。
4. 写一份简短设计规格并取得用户确认。
5. 再写实施计划，列出文件、测试和模拟器验收步骤。
6. 严格 TDD：可测试的布局/展示状态先写失败测试，再实现。
7. 每次只解决一个视觉或交互问题，保存可比较截图供用户人工审查。

## 测试与验收建议

开始时至少运行：

- `WeeklyStateTimelineTests`
- `AssessmentSettlementTests`
- 与 `LifeStateSummaryBuilder`、`LifeStateDisplayScale` 和本地重置相关的测试。

完成后运行一次完整 Debug 测试。当前参考基线为 270 tests / 0 failures。

模拟器至少检查：

- 有评估数据与无评估数据。
- 一周内有完成记录与无完成记录。
- 小屏和 iPhone 17 Pro。
- 最大 Dynamic Type 下无裁切和控件重叠。
- VoiceOver 顺序、标题、数值和按钮名称。
- Reduce Motion 下粒子或其他运动效果停止，但信息不消失。
- 每周评估可进入、保存并返回。
- 数据与隐私、设置、Debug 重置入口工作正常。
- 切换 Tab 后返回 You 页面状态稳定。

## 已知上线前事项

以下事项不应混入 You 页面设计提交，但必须进入发布前清单：

- Archive 滑动视觉频闪。
- 9 条 Swift 6 actor-isolation 测试警告。
- 建立可靠的私有远端或离线备份；当前大量提交只存在本地。
- 验证 SwiftData schema 升级与已有用户数据迁移。
- 完成真实设备冷启动、内存、耗电、后台恢复和长时间使用测试。
- 核对隐私说明、数据删除、备份/导出策略和商店发布素材。
- 发布前运行 Release 构建与最终回归；这不属于本阶段默认工作。

## 完成条件

You 阶段只有在以下条件都满足后才结束：

- 用户确认最终视觉与信息层级。
- 已批准的所有入口和状态均可用。
- 没有修改其他三个页面或跨模块领域逻辑。
- 聚焦测试和完整 Debug 测试为零失败。
- iPhone 17 Pro 上完成常规、Dynamic Type、VoiceOver 和 Reduce Motion 验收。
- 受保护路径未进入提交。
- 用户批准后只提交允许的 Profile / LifeState / 测试文件。
- 未经授权不 merge、不 push。

## 新对话可直接使用的开场提示词

```text
继续开发 LIVELVL，本阶段只完成“我的”（You）页面。

仓库：/Users/fy/Desktop/LIVELVL
先完整阅读 docs/YOU-MODULE-HANDOFF.md，并以其中记录的事实状态和保护规则为准。

开始前：
1. 确认当前本地 main 包含 fed4fc9 或其后继提交。
2. 确认 codex/you-mvp 与 .worktrees/you-mvp 不存在。
3. 从最新本地 main 创建 codex/you-mvp 和隔离工作树 .worktrees/you-mvp。
4. 不要 reset、rebase、merge 或 push。
5. 不要修改、暂存或提交 project.pbxproj、UserInterfaceState.xcuserstate 或 .tmp/。
6. 先运行 You / LifeState 聚焦基线测试。

用户可能删除或替换 You 页面现有六维图；六维可视化不是保护项，但 LifeDimension、状态评估、历史数据和 Today 共用的数据语义不能因视觉调整而被破坏。

日记功能留到以后独立设计，本阶段不要实现日记模型或占位入口。先打开当前 You 页面、审查现状并与用户确认页面目标；设计获批前不要修改代码。
```
