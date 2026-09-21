# LIVELVL 收集、今日塔罗与正式卡片接入交接

更新时间：2026-09-21

## 交接目的

收集页视觉升级和“今日塔罗”第一阶段已经完成。下一阶段准备正式接入收藏卡图片，但在批量导入素材之前，可能先调整两个会直接影响收藏系统的底层规则：

1. 每个本地自然日可获得的 XP 是否设上限，以及达到上限后的任务反馈、撤销和历史记录语义。
2. 普通陪伴卡的成长阶段、成熟发卡和切换下一张卡的规则。

这两项应先定规则、再改引擎、最后接正式卡面。不要让约 200 张正式图片的文件名反过来决定收藏 ID、成长阶段或奖励规则。

## Git 基线

- 仓库：`/Users/fy/Desktop/LIVELVL`
- 已使用的隔离工作区：`/Users/fy/Desktop/LIVELVL/.worktrees/today-visual-upgrade`
- 功能分支：`codex/today-visual-upgrade`
- 今日塔罗实现提交：`abb579b feat: add daily tarot to Collection`
- 本分支已经包含合并前 `main` 的最新提交 `32e9c13 feat: add daily journal experience`。
- 本次只进行本地合并，不推送远端。
- 为便于下一阶段继续工作，隔离工作区和功能分支暂时保留，不清理。

主工作区存在用户文件和 Xcode 本地状态。后续操作不得暂存、覆盖、还原、移动或删除：

- `LIVELVL/LIVELVL.xcodeproj/project.pbxproj`
- `LIVELVL/LIVELVL.xcodeproj/project.xcworkspace/xcuserdata/fy.xcuserdatad/UserInterfaceState.xcuserstate`
- `.tmp/`
- `docs/CARD-IMAGE-FINALIZATION-HANDOFF.md`
- `docs/JOURNAL-MODULE-HANDOFF.md`

不要清理其他已有 worktree。

## 当前已经完成

### 收集页

- 保留单卡轮播的稳定居中和相邻卡切换。
- 保留奖励卡到达、未查看标记和飞向底部“收集”Tab 中心的动画终点。
- 保留卡片放大、正反面翻转、点击外部关闭，以及关闭后的滚动位置与 VoiceOver 焦点恢复。
- 保留图鉴、锁定卡的信息保护、重试状态、Reduce Motion 和 Dynamic Type 行为。
- 重排首屏信息密度，在卡片主体下方加入独立的“今日塔罗”入口。
- 收藏为空或重置数据后，“今日塔罗”入口仍可显示，不再依赖已有收藏卡。

### 今日塔罗

- 每个设备本地自然日免费抽取一次；不要求完成任务，机会不累积。
- 使用 22 张 Rider–Waite–Smith 大阿卡纳和原版牌背，支持正位与逆位。
- 首次进入当天页面时生成三张互不重复的候选牌；离开并重新进入仍保持同一牌阵。
- 选牌后立即锁定当天结果；跨日可以重复抽到同一张牌。
- 当天再次进入直接查看结果；到本地午夜、时区或系统时钟变化后可恢复新一天状态。
- 揭晓页支持点击卡面进行有弹性的正反面 3D 翻转；翻到正面后立即恢复亮度。
- Reduce Motion 下不使用空间洗牌或 3D 翻转；VoiceOver 在揭晓前不会泄露隐藏牌名。
- 解析固定为“今日主题、需要留意、行动建议”，全部本地提供，不联网、不调用 AI。
- 塔罗不进入 Archive、不创建 `OwnedCollectible`、不改变收藏进度，也不参与普通奖励队列。
- 重置本地数据会同时删除 `TarotDailyState`，但空收藏页面仍保留塔罗入口。

塔罗图片来源及公共领域记录见 `docs/TAROT-ASSET-SOURCES.md`。这些资源只属于今日塔罗，不代表正式收藏卡素材已经接入。

## 现有 XP 与升级规则实况

当前代码没有每日 XP 上限。

- `GrowthEngine.recommendedXP` 根据时长和难度推荐单次任务 XP，并按 5 XP 取整。
- 总 XP 小于 200 时为 Lv.0；达到 200 XP 后为 Lv.1。
- Lv.1 之后每 2,000 XP 升一级。
- `TaskRewardCoordinator.complete` 直接把任务的完整 `item.xp` 加到 `Progress.totalXP`，并把同样数值写入 `Completion.xp`。
- 撤销完成时，从总 XP 中减去该条 `Completion.xp`。
- “我的”页图表默认 0–600 XP 只是显示范围，不是每日获取上限；超过 600 时纵轴会扩展。

当前普通卡成长完全由全局等级驱动：

- Lv.0：第 1 个普通陪伴处于幼体。
- Lv.1：第 1 个陪伴成熟并产生 `ordinary.level.1` 奖励，领取后切换到第 2 个陪伴幼体。
- 之后每个普通陪伴占用三个等级节点：二阶段、三阶段、成熟。
- 成熟奖励的幂等身份是 `awardKey = ordinary.level.<成熟等级>`。
- `CollectionProgress.highestLevel` 用于防止已到达的等级被重复处理。
- `activeOrdinaryIndex` 和 `activeStage` 表示 Today 当前显示的陪伴及阶段。
- `lastProcessedMaturityLevel` 记录最近已领取的成熟奖励。

核心实现位置：

- `LIVELVL/LIVELVL/Item.swift`
- `LIVELVL/LIVELVL/Rewards/TaskRewardCoordinator.swift`
- `LIVELVL/LIVELVL/Collection/CompanionProgressionEngine.swift`
- `LIVELVL/LIVELVL/Collection/CardRewardService.swift`
- `LIVELVL/LIVELVL/Persistence/CollectionModels.swift`
- `LIVELVL/LIVELVL/Collection/CollectibleDefinition.swift`

## 修改每日 XP 上限前必须决定

不要先在界面里简单截断数字。应先确认完整业务语义：

1. 上限只限制任务 XP，还是也限制其他未来 XP 来源？金币是否仍完整发放？
2. 当天剩余额度小于任务 XP 时，是部分发放，还是整项不发 XP？
3. 达到上限后，任务是否仍可完成、写入活动历史并触发隐藏成就？
4. `Completion.xp` 应记录任务标称 XP，还是本次实际发放 XP？建议记录实际发放值；若还要展示标称值，应新增独立字段，不能混用。
5. 撤销一项任务后，是否立即释放当天额度；重新完成时如何避免重复奖励？
6. 每日边界是否继续采用设备当前时区自然日；修改系统时间不做防作弊，还是需要额外策略？
7. 历史数据是否保持原值，不追溯套用新上限？
8. Today 的奖励动画、提示文字、“我的”页统计和活动记录必须展示实际获得值，不能继续假定 `item.xp` 等于到账 XP。

建议把“计算本次实际可发 XP”做成独立、可注入日期和日历的纯规则层，再由 `TaskRewardCoordinator` 原子地写入完成记录、总 XP 和金币流水。不要在多个 View 中各自计算上限。

## 修改卡片升级规则前必须决定

1. 卡片成长继续绑定全局等级，还是改为独立的成长 XP／成长点？
2. 一张普通卡包含几个阶段，每阶段阈值是多少，成熟后是否自动切换下一张？
3. 用户在成熟奖励尚未领取时继续升级，后续阶段如何补算与排队？
4. 约 200 张图片对应“物种 × 阶段 × 正反面”的哪一种结构？一张收藏记录对应一个成熟物种，还是每个阶段都可收藏？
5. 普通卡、隐藏卡和未来特殊卡是否共用一套 ID，还是分目录但共享稳定资源解析接口？
6. 已有 `OwnedCollectible`、`PendingCardReward` 和 `CollectionProgress` 如何迁移；不能通过重置用户数据来代替迁移。
7. `awardKey` 仍必须保持稳定和幂等。不要把可变的图片文件名、展示名称或数组下标作为奖励身份。
8. 锁定卡在解锁前不得通过图片文件名、无障碍文本、预加载日志或占位图泄露信息。

如果改变等级到成熟的映射，应先为旧模型写兼容读取和迁移测试，再替换 `CompanionProgressionEngine`。需要特别覆盖“用户已跨过多个等级但奖励未领取”和“正式卡数量不足”两类状态。

## 正式收藏卡图片接入边界

正式卡片任务的源交接仍是主工作区中的 `docs/CARD-IMAGE-FINALIZATION-HANDOFF.md`。它目前是用户保留的未跟踪文档，本次没有编辑或纳入提交。

在底层规则和素材清单确认前：

- 不批量裁切、改名、复制或导入约 200 张图片。
- 不根据现有程序化占位卡猜测物种、阶段、稀有度、正反面或隐藏条件。
- 不把 `.tmp`、Word、PDF、Quick Look 或预览产物加入 App bundle。
- 不直接在 SwiftUI View 中拼接资源名。

正式接入时建议先建立一份可审阅的 manifest。每行至少明确：稳定 `collectibleID`、卡片类别、物种、阶段、正／背面资源、显示名称、排序、解锁规则 ID 和来源文件。通过统一资源解析层把 manifest 映射到卡面，收藏数据继续只保存稳定 ID。

## 推荐的下一阶段顺序

1. 与产品规则一起确定每日 XP 上限的完整语义。
2. 确定普通卡成长、成熟、发卡和下一张卡切换规则。
3. 为新规则写纯逻辑测试与 SwiftData 迁移测试。
4. 修改 XP 发放和卡片进度引擎，保持塔罗完全独立。
5. 用少量明确映射的正式卡面做端到端样本，确认尺寸、裁切、正反面和锁定保护。
6. 审阅 manifest 后，再批量导入正式图片。
7. 最后统一执行完整测试、构建、iPhone 17 Pro 交互验收和数据迁移验收。

## 本阶段验证记录与已知阻塞

在用户决定把统一 debug 延后之前，已经完成以下验证：

- iPhone 17 Pro 模拟器 Debug 构建并运行成功。
- 实机坐标交互检查了 Collection 入口、三牌选择、揭晓、卡面正反翻转、完成后返回以及底部 Tab 立即显示。
- 67 项相关单元／状态测试通过。
- 2 项 Collection 塔罗界面呈现测试分别运行通过。
- 重置数据后空 Archive 仍显示塔罗入口。
- 当前日期刷新和跨午夜观察逻辑已覆盖测试。

完整测试套件仍有一个与本阶段无关的既有编译阻塞：`CompanionPointCloudRepositoryTests.swift` 的 actor／protocol isolation 不匹配。按用户要求，本次不继续统一 debug；后续最终验收时需单独修复或隔离该测试，不能误判为塔罗回归。

## 下一位开发者优先阅读

1. `docs/COLLECTION-TAROT-FORMAL-CARDS-HANDOFF.md`
2. `docs/CARD-IMAGE-FINALIZATION-HANDOFF.md`
3. `docs/TAROT-ASSET-SOURCES.md`
4. `LIVELVL/LIVELVL/Item.swift`
5. `LIVELVL/LIVELVL/Rewards/TaskRewardCoordinator.swift`
6. `LIVELVL/LIVELVL/Collection/CompanionProgressionEngine.swift`
7. `LIVELVL/LIVELVL/Collection/CardRewardService.swift`
8. `LIVELVL/LIVELVL/Persistence/CollectionModels.swift`
9. `LIVELVL/LIVELVL/Collection/CollectibleDefinition.swift`
10. `LIVELVL/LIVELVL/Collection/CollectionView.swift`
11. `LIVELVL/LIVELVL/Tarot/TarotDailyState.swift`
12. `LIVELVL/LIVELVL/Tarot/TarotDailyView.swift`

## 不可回退的产品约束

- 保留现有收藏数据、奖励队列和 `awardKey` 幂等语义。
- 保留轮播居中、奖励到达／未查看、放大翻面、关闭后位置与焦点恢复。
- 保留 Reduce Motion、Dynamic Type、VoiceOver 和隐藏卡信息保护。
- 保留奖励卡飞向“收集”Tab 中心的动画终点。
- 今日塔罗继续保持每日一次、本地解析、允许跨日重复，并与任务 XP、普通收藏和正式卡库解耦。
- 未经明确要求，不推送远端，不删除 worktree，不清理主工作区用户文件。
