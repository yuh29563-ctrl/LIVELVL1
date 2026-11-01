# LIVELVL 升级卡片图片接入交接

更新时间：2026-11-01。下一次对话从本文档开始。本轮只交接和合并自测／首页动画，不导入图片。

## 1. 当前基线与本轮范围

- 主仓库：`/Users/fy/Desktop/LIVELVL`；主分支：`main`。
- 本轮合并来源：`codex/assessment-intro-integration`，代码完成点 `acd5450`，原 main 基线 `7e2a270`。本文档随同该分支本地合并；下一轮重新读取实际 HEAD，不能依赖旧文档中的提交号。
- 本轮包含真实自测引导接入、完成六组后保存六维状态并进入 Today、节点从中心展开、卡片随后展开，以及切回首页时六维图突然下移的修复。
- 每次进入 Today：先收起成长卡，等待 120ms，六维节点用 1.0s 从中心展开；实际动画完成后，成长卡用约 0.5s 弹簧动画展开。中途手动操作优先，旧动画回调不能影响新一次进入。Reduce Motion 有独立处理。
- 每组十题、六组、纵向下滑、程度性选项、中间圆最小且两侧逐渐变大、十五日周期和正式评分已实现。本轮合并不改变这些规则。
- 每日任务 XP 400 上限此前已在 main。额度不足部分到账；0 XP 仍可完成、获得按标称 XP 计算的金币并参与行为成就；撤销按实际到账 XP 处理，旧数据不重算。
- 所有改动只在本地；没有推送远端。原功能分支和 worktree 保留。

## 2. 新对话首先做什么

依次阅读：

1. 本文档（最新事实与约束）。
2. `docs/COLLECTION-TAROT-FORMAL-CARDS-HANDOFF.md`。
3. 主工作区的 `docs/CARD-IMAGE-FINALIZATION-HANDOFF.md`（用户保留的未跟踪文件，只读）。
4. `docs/TAROT-ASSET-SOURCES.md`。
5. `docs/superpowers/plans/2026-10-28-assessment-intro-integration.md`（近期实现与验证记录）。

旧图片交接中的“四阶段／50×4／4×4 合成图”和“无每日 XP 上限”描述属于旧基线，不能当作当前已确认的产品规则。不要覆盖旧交接来消除差异，应以最新代码与用户确认分别核对。

先执行只读 Git 检查：

```bash
git -C /Users/fy/Desktop/LIVELVL status --short --branch
git -C /Users/fy/Desktop/LIVELVL log -6 --oneline
git -C /Users/fy/Desktop/LIVELVL worktree list --porcelain
git -C /Users/fy/Desktop/LIVELVL merge-base --is-ancestor acd5450 main
```

接入前从最新 main 创建新的隔离分支／worktree，例如 `codex/level-up-card-images`；先检查名称是否被占用。不要复用或改动其他既有 worktree，也不要现在就批量裁切、复制或改名。

## 3. 已确认的展示方向与尚未合并的差异

用户已明确：

- 正式成长视觉只有幼年体和成熟体，没有中间形态。
- 今天页的伙伴只显示幼年体；奖励卡和已经获得的收藏卡显示成熟体。
- 图片内容、物种、名称、稀有度、阶段、正反面和隐藏条件必须来自用户的原图及明确内容表，不能根据程序占位图推断。

**重要：本次 main 合并并不包含另一个卡片成长分支。**

- 当前 Git 中仍保留 `codex/two-stage-cards-implementation`，检查时提交为 `c3785b3`；另有 `codex/two-stage-cards`。本轮未合并、未改动这些分支／worktree。
- 当前 main 的 `CompanionStage` 仍含 `juvenile / stageTwo / stageThree / mature`，`CompanionProgressionEngine` 仍是旧四阶段映射。
- 对话中曾讨论“升级时奖励归属即已确定”“领取后才衔接下一张”“退出后的自动领取／恢复”。这些边界不能仅靠图片替换实现；下一轮需只读核对卡片分支的实际实现、既有确认和迁移测试，明确与 main 的接入方式。
- 当前 main 实际是在升级结算后创建 `PendingCardReward`，点击领取才保存 `OwnedCollectible` 并推进下一张；不能把这个旧实现描述成已满足上述全部语义。
- 本轮不擅自合并卡片分支，不重新发明成长规则。可先清点用户图片；涉及阶段映射和存档的实现应在上述差异明确后进行。

## 4. 当前 main 的成长与图片代码实况

### 等级与奖励身份

`LIVELVL/LIVELVL/Item.swift`：累计 200 XP 达到 Lv.1，之后每 2,000 XP 升一级；等级取决于全局 `Progress.totalXP`。

下面仅记录**旧代码实况**，不要求按此制作正式图片：

| 等级事件 | 当前旧实现 |
| --- | --- |
| Lv.0 | 第一个普通伙伴幼体 |
| Lv.1 | 第一个伙伴成熟奖励；领取后进入第二个伙伴 |
| Lv.2、Lv.3 | 第二个伙伴二阶段、三阶段 |
| Lv.4 | 第二个伙伴成熟奖励；领取后进入第三个伙伴 |
| 后续 | 每三个等级产生下一个成熟节点 |

普通成熟奖励使用 `ordinary.level.<成熟等级>` 作为 `awardKey`。奖励处理同时读取待领取与已拥有集合做去重。更换美术时保持既有 key，不用文件名、展示名或新数组下标替代；如调整成长映射，需显式制定旧 key 的兼容策略。

### 已有资源管线

- `LIVELVL/LIVELVL/Today/CompanionArtwork.swift`：以 `collectibleID + stage` 定位资源；manifest 版本 1，支持 `pointCloud` 与 `transparentRaster`。
- `LIVELVL/LIVELVL/Resources/CompanionArtwork/manifest.json`：当前 8 条映射、5 张实际图片；小芽四阶段试验图，月兔幼体 PNG；月兔后三阶段仍引用小芽图。这是占位关系，不能当作正式映射。
- `CompanionPointCloudExtractor.swift`、`CompanionPointCloudRepository.swift`、`CompanionPointCloudView.swift` 均在 `Today/` 下。缓存键包含源图 SHA-256，描述符缓存最多 2 项；不要启动时解码全部图片。
- `Today/LifeCoreWidget.swift`：今天页卡片、展开与收起布局、资源请求、六维动画后的自动展开。`ContentView.swift` 中 Today 的当前定义和阶段来自 `CollectionProgress`。
- `Collection/CollectibleDefinition.swift`：当前普通 ID 是 `ordinary.sprout / ordinary.hare / ordinary.tortoise`，隐藏 ID 是 `hidden.study-streak / hidden.long-workout`。这些是已有存档身份，不是正式图片的物种依据；替换或扩展必须保持旧身份兼容。

### 尚未统一的入口

- `Collection/CompanionCardView.swift` 中 `PixelSpeciesArtwork` 仍使用占位视觉。
- `Collection/CollectibleCardView.swift`、`Collection/CardRewardOverlay.swift` 仍使用该占位绘制。
- `Collection/ArchiveCardView.swift` 中 `ArchiveOrganismArtwork` 是程序化点阵。
- 只替换 Today 的 manifest 不会自动替换奖励、收藏轮播、放大正反面和图鉴。正式接入应有共享的稳定解析层，各展示入口按确认的幼年／成熟角色取图。
- `UserCardMedia` 是用户自选媒体／背景数据，不能当作正式卡库覆盖或清空。

## 5. 图片接入顺序

1. 收到用户图片、文件夹路径和内容表后，只读清点数量、格式、像素尺寸、Alpha、方向、可解码性、SHA-256 重复项及来源。原文件保持原样。
2. 建立可审阅映射表。含糊归属列为“待确认”，不能填入猜测值。先明确图片是角色透明图、完整卡面还是合成图，以及幼年、成熟、正面、背面的对应关系。
3. 核对两阶段成长分支与 main 差异，确定接入及旧数据兼容方案。图片清点可以先行；不能凭旧枚举要求用户额外提供中间形态。
4. 选择少量已明确映射的正式卡片做样本，优先完整覆盖一个普通伙伴的已确认视觉角色及正反面；隐藏卡仅在素材与条件都明确时加入样本。
5. 先写规则／资源／迁移失败测试，再接样本。裁切结果写新目录，保留来源、坐标和变换记录。不要先处理约 200 张。
6. 展示 Today、升级奖励、领取、收藏轮播与放大翻面效果，确认构图、裁切、透明度／点云表现、锁定保护和旧存档重开。
7. 样本获确认后再生成其余资源和 manifest；最终统一测试、构建及 iPhone 17 Pro 验收。

## 6. 正式 manifest 的稳定字段

现有版本 1 只有 `collectibleID / stage / resourceName / fileExtension / renderMode`，不包含完整卡面的正反面、文案及来源。不要假定往现有 JSON 加字段即可让所有界面支持正式卡片。

建议导入映射至少记录以下字段；字段名称和升级后的 schema 应在样本阶段确定：

- `schemaVersion`、稳定 `collectibleID`、`artworkID`，已有 ID 的兼容别名（确有迁移才添加）。
- `kind`、稳定普通卡排序／原 `ordinaryIndex`、已确认的 `presentationStage`（幼年／成熟）、`role`（角色图／完整卡面）、`face`（正面／背面）。
- 对应资源名、实际扩展名、`renderMode`、像素尺寸、Alpha 和文件 SHA-256。
- 原始来源路径／文件名与来源哈希；合成图行列或裁切矩形、方向／缩放处理记录。
- 用户明确提供的显示名称、故事、说明、稀有度（如果有），以及独立稳定的 `unlockRuleID`／隐藏规则 ID。

约束：同一展示身份唯一；一个来源跨角色复用必须明确记录。ID、排序和奖励身份不能随文件名或图片排列改变。资源路径不得进入收藏持久化身份。原始图片、Word、PDF、Quick Look 和 `.tmp` 预览产物不打入 App bundle。隐藏卡未解锁时，资源加载、日志、无障碍文本和占位轮廓均不能泄露受保护信息。

## 7. 数据迁移和测试底线

保留 `Progress.totalXP`、每日 XP 记录、金币流水及六维自测数据。资源替换不触发重算，也不触发额外奖励。

- `CollectionProgress`：兼容原 `highestLevel / activeOrdinaryIndex / activeStageRaw / lastProcessedMaturityLevel`。不可直接删除旧阶段枚举导致 raw 值改义。
- `PendingCardReward`：保留 `awardKey / collectibleID / maturityLevel / eligibleAt / triggeredAt` 和领取顺序，重启后不得丢失或重复奖励。
- `OwnedCollectible`：保留身份、获得原因、日期及 `isUnseen`，不能因换图变成未拥有或自动已读。
- 迁移需验证真实磁盘旧存档升级并再次打开，不能只测内存模型；不要重置用户模拟器数据来证明迁移。
- 必测：未知阶段／重复身份／缺图／坏图；已有 ID 与排序稳定；异步旧加载不能覆盖新伙伴；成熟节点与重复重启／领取的幂等；升级撤销及跨多级奖励；锁定信息保护；0 XP 任务仍保留行为成就。

## 8. 必须保留的体验

- 收集轮播居中、奖励到达和未查看状态、放大与正反面翻转、关闭后的滚动位置与 VoiceOver 焦点恢复。
- 奖励飞向“收集”Tab 中心的动画终点，Reduce Motion、Dynamic Type、VoiceOver。
- Today 六维状态即时更新、节点从中心展开、卡片顺序展开，以及本轮修复的切回首页位置稳定性。
- 今日塔罗每日一次、本地解析、正逆位、跨日／时区刷新，继续与 XP、Archive、普通收藏及正式卡库解耦；`TarotRWS00…21 / TarotRWSBack` 不用于普通卡。

## 9. 验证记录与后续 Debug

- 2026-10-31：74 项相关测试通过；iPhone 17 Pro 正常模式构建、安装、启动成功，录屏逐帧检查 Profile → Today 的六维展开及后续卡片展开。
- 近期实现详情和历史测试结果见 `docs/superpowers/plans/2026-10-28-assessment-intro-integration.md`。
- 2026-11-01 合并前：六维展示、成长卡、自测会话、持久化、实时查询和任务反馈共 77 项相关测试通过，0 失败；独立只读代码审查未发现阻塞问题。结果：`~/Library/Developer/XcodeBuildMCP/workspaces/LIVELVL-2ff2b8f231d7/result-bundles/test_sim_2026-11-01T13-18-57-776Z_pid7004_2d0f714b.xcresult`。测试后只新增本交接文档，Swift 源码未再改动。完整测试及统一 Debug 仍延后到规则和正式卡片样本接入后。
- 已有 `CompanionPointCloudRepositoryTests.swift` actor／protocol isolation 编译问题单独登记，相关测试命令使用 `EXCLUDED_SOURCE_FILE_NAMES=CompanionPointCloudRepositoryTests.swift`；不是本轮回归。
- `LifeFieldPresentationTests/accessibilityDetailProvidesAScrollContainerForLongSources()` 已在旧基线复现失败，相关运行显式排除；另有旧的 `CardRewardPresentationTests/collectionTargetResolvesByStableIdentityAfterReordering` 待最终 Debug 检查。不能把有限范围通过表述成全量测试通过。

## 10. 主工作区保护与下一轮开场指令

不要暂存、覆盖、还原、移动或删除主工作区既有的：

- `LIVELVL/LIVELVL.xcodeproj/project.pbxproj`。
- `LIVELVL/LIVELVL.xcodeproj/project.xcworkspace/xcuserdata/fy.xcuserdatad/UserInterfaceState.xcuserstate`。
- `.tmp/`、`output/`、`tmp/`。
- `docs/CARD-IMAGE-FINALIZATION-HANDOFF.md`、`docs/JOURNAL-MODULE-HANDOFF.md`。
- 其他 worktree 中的任何已有内容。未经明确要求不推送、不删除 worktree。

可复制到下一次对话：

> 开始前完整阅读 `/Users/fy/Desktop/LIVELVL/docs/LEVEL-UP-CARD-IMAGES-HANDOFF.md`，再按其中顺序阅读旧交接。先只读核对 main、工作区与卡片分支状态。接下来我要提供升级卡片图片，请先只读清点原图和内容表，列出已明确与待确认的幼年／成熟、正反面及展示入口映射；不要猜测物种、阶段、名称、稀有度或隐藏条件，不要批量裁切、改名或复制。今天页只显示幼年体，奖励和收藏显示成熟体，没有中间形态。先核对未合并两阶段实现与 main 的兼容方式，再在新的隔离分支做少量样本及磁盘存档迁移验证，展示效果后再考虑批量导入。保留主工作区用户文件、所有 worktree 和塔罗解耦；不推送。完整 Debug 放在规则和正式样本接入后统一进行。
