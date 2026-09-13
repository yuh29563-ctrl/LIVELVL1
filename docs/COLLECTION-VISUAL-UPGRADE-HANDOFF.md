# LIVELVL 收集页视觉升级交接

更新时间：2026-09-13

## 下一阶段目标

在已经完成的 Today 页面视觉升级基础上，升级底部 Tab 的下一个页面“收集”。本阶段不是重做收集系统，也不是开始批量接入约 200 张正式图片，而是在保留现有收藏、轮播、奖励到达、放大、翻面、图鉴、锁定态与无障碍行为的前提下，重新梳理收集页的视觉层级。

新聊天开始后，先确认用户希望进入“收集”页时第一眼感受到的核心内容，再给出简短、可实现的设计方案和实例图。用户确认设计之前，不要直接修改 Swift。

## 当前 Git 状态

- 仓库：`/Users/fy/Desktop/LIVELVL`
- 工程：`LIVELVL/LIVELVL.xcodeproj`
- 主工作区分支：`main`
- 主工作区提交：`32e9c13 feat: add daily journal experience`
- Today 升级隔离工作区：`/Users/fy/Desktop/LIVELVL/.worktrees/today-visual-upgrade`
- 隔离分支：`codex/today-visual-upgrade`
- Today 页面实现最新提交：`d34fea4 fix: center Today card in life field`
- 交接文档创建前，隔离工作区为干净状态。
- Today 升级尚未合并到 `main`，也没有推送远端。

Today 升级提交顺序：

```text
d34fea4 fix: center Today card in life field
0fa49b2 fix: prevent collapsed Today layout overlap
4d9d328 feat: refine Today visual hierarchy
9afc8b8 chore: checkpoint before Today visual upgrade
32e9c13 feat: add daily journal experience
```

`9afc8b8` 是 Today 视觉修改前的明确回滚点。

## 主工作区必须保留的用户文件

主工作区当前不是干净状态。以下内容属于用户或 Xcode 本地状态，不要暂存、覆盖、还原、移动或删除：

- `LIVELVL/LIVELVL.xcodeproj/project.pbxproj`
- `LIVELVL/LIVELVL.xcodeproj/project.xcworkspace/xcuserdata/fy.xcuserdatad/UserInterfaceState.xcuserstate`
- `.tmp/`
- `docs/CARD-IMAGE-FINALIZATION-HANDOFF.md`
- `docs/JOURNAL-MODULE-HANDOFF.md`

不要清理或复用其他已有 worktree：

- `.worktrees/archive-grounding`
- `.worktrees/home-life-state`
- `.worktrees/rewards-mvp`
- `.worktrees/you-mvp`

继续收集页工作时优先复用 `.worktrees/today-visual-upgrade`，因为 Today 的视觉语言和共享主题修改只存在于该分支。创建新分支或新 worktree 前必须先说明原因并获得用户确认。

## Today 页面已经完成的内容

- 增加 `LIVELVL` eyebrow 和本地化日期。
- 六个维度节点在实际画布坐标中构成正六边形。
- 展开成长卡与六维图的几何中心精确对齐。
- 折叠态为日期、折叠卡和“健康”顶部标签分别保留安全间距。
- 日记入口位于任务区上方。
- 任务行显示维度和基础 XP，奖励反馈使用克制的青绿色强调。
- 保留成长卡展开/折叠、维度详情、任务完成与编辑、奖励动画、日记、VoiceOver 和 Reduce Motion 行为。

最近一次 Today 完整验证：

- 296 项测试通过，0 失败，0 跳过。
- Debug 模拟器构建成功。
- iPhone 17 Pro 模拟器上检查了展开/折叠、卡片居中、维度详情、任务编辑和日记打开/关闭。
- 模拟器 UDID：`CDEFD7CB-0175-4A46-BC1E-12BD8E9B37D9`

不要在收集页升级中回退上述 Today 布局或破坏共享的奖励动画终点。

## 当前收集页实况

2026-09-10 在 iPhone 17 Pro 模拟器上重新构建并检查了当前收集页。当前测试数据只有 1 张归档卡：

- 页头标题为 `Archive`。
- 标题下显示 `1 / 1`。
- 右上角圆形按钮进入图鉴与筛选。
- 首屏主体是一张居中的大型成熟卡轮播。
- 卡片下方依次显示名称、类别、等级和获得日期。
- 底部保留四栏 Tab。

当前页面干净，但存在以下视觉问题：

- 与升级后的 Today 页头语言不完全一致。
- 单张卡占据主体，但收藏进度、收藏意义和图鉴入口的层级较弱。
- 卡片说明文字悬浮在大面积留白中，信息关系松散。
- 当前只有一张卡时，轮播的空间感强于“收藏档案”的内容感。
- 正式图片尚未接入，卡面仍使用程序化抽象点阵；本阶段应让布局兼容未来正式素材，不应以占位图细节作为最终构图依据。

## 必须保留的现有行为

- 横向卡片轮播与稳定居中。
- 非中心卡片点击后先居中，中心卡片点击后放大。
- 放大卡正反面翻转。
- 点击卡片外部关闭并恢复原滚动位置和 VoiceOver 焦点。
- 新奖励到达、居中和未查看状态处理。
- `CollectionSeenRetryState` 的失败提示与重试。
- Reduce Motion 下取消空间旋转、飞行动画并保留功能结果。
- Dynamic Type 无障碍尺寸下切换为纵向页面滚动。
- 隐藏卡未解锁时不泄露名称、故事、触发条件或可辨认的正式图片。
- 奖励卡飞向底部“收集”Tab 中心的动画终点。

## 开始设计前需要确认的问题

只问用户一个核心问题：

> 用户打开“收集”页时，你最希望他第一眼看到并理解的核心是什么？

这个答案将决定页面以“大卡档案/轮播”为主视觉，还是以“收藏进度/卡墙”为首屏重点。不要默认改变交互模型，也不要在用户确认前把轮播改成网格。

## 推荐设计原则

- 延续 Today 的 `LIVELVL` eyebrow、强标题、轻量元信息和克制青绿色状态点。
- 保留白、黑、灰主色，不把页面做成科幻面板或彩色游戏图鉴。
- 每屏只有一个明确焦点：当前卡片、收藏进度或图鉴入口不能同时争夺主视觉。
- 正式图片未来通过共享资源解析层进入；收集页不要自行拼接资源名。
- 卡片尺寸和留白应兼容普通成熟卡、隐藏卡与未来完整卡面。
- 先用现有 1 张卡的数据验证单卡状态，再补 2–3 张卡的轮播状态和空状态。
- 不新增持久化字段，不改变奖励、收藏顺序或 `awardKey` 语义。

## 下一步建议流程

1. 重新执行 Git 只读检查，确认上述提交和工作区状态没有漂移。
2. 阅读本文档与收集 MVP 设计文档。
3. 阅读收集页的核心 SwiftUI 文件和相应状态测试。
4. 在模拟器上截图当前单卡、放大正面、放大背面和图鉴页。
5. 向用户提出上面的一个核心问题。
6. 根据回答给出 2–3 个可实现方向，并明确推荐方案。
7. 先制作实例图或低风险原型，等待用户确认。
8. 用户确认后再用测试驱动方式修改代码。
9. 完成后运行收集相关测试、完整测试、Debug 构建和 iPhone 17 Pro 交互验收。
10. 单独提交收集页升级；不推送、不合并 `main`，除非用户明确要求。

## 新聊天应优先阅读的文件

1. `docs/COLLECTION-VISUAL-UPGRADE-HANDOFF.md`
2. `docs/superpowers/specs/2026-08-23-collection-mvp-design.md`
3. `docs/superpowers/specs/2026-09-07-today-visual-upgrade-design.md`
4. `LIVELVL/LIVELVL/Collection/CollectionView.swift`
5. `LIVELVL/LIVELVL/Collection/ArchiveCarouselView.swift`
6. `LIVELVL/LIVELVL/Collection/ArchiveCarouselState.swift`
7. `LIVELVL/LIVELVL/Collection/ArchiveCardView.swift`
8. `LIVELVL/LIVELVL/Collection/ArchiveExpandedView.swift`
9. `LIVELVL/LIVELVL/Collection/CatalogView.swift`
10. `LIVELVL/LIVELVLTests/CollectionViewStateTests.swift`

## 与约 200 张正式图片任务的边界

正式图片接入仍以 `docs/CARD-IMAGE-FINALIZATION-HANDOFF.md` 为准，目前暂停。收集页视觉升级可以为正式素材预留共享渲染入口，但在收到完整图片批次和内容表之前：

- 不批量裁切、改名或复制图片；
- 不猜测物种、阶段、稀有度或隐藏条件；
- 不删除 manifest 中现有映射；
- 不把 `.tmp`、Word、Quick Look、PDF 或预览产物加入 App bundle。
