# LIVELVL UI polish handoff

更新时间：2026-08-24

## 当前基线

- 基线分支：本地 `main`
- 基线提交：`18fc10e`（`fix: anchor reward flight to overlay center`）
- Collection MVP 已从 `codex/collection-mvp` fast-forward 合入本地 `main`；原功能分支及隔离工作区已清理。
- 工程：`LIVELVL/LIVELVL.xcodeproj`。不要打开仓库根目录的旧工程。
- 最近一次合并后验证：iPhone 17 Pro（iOS 26.5）Debug 完整测试 76/76 通过。
- 当前合并只发生在本地；在用户明确要求前不要推送远端。

## 下一阶段目标

下一阶段只做现有界面的 UI 细节微调，例如布局、间距、字号、颜色、卡片样式及已有交互的视觉手感。保持现有产品逻辑、持久化、奖励队列和收集流程稳定。

明确不在本阶段开发：

- 奖励商城或商品购买逻辑
- 网络、账户、云同步
- 新的成长或奖励规则
- 与 UI 微调无关的大规模重构

奖励栏目继续保持占位。

## 已验收的产品行为

- 四个 Tab：今天、收集、奖励、我的。
- “今天”页已经把当前伙伴与等级进度合并为一张卡片；当前伙伴替代了旧的小草图标。
- 等级可随撤销任务下降；收藏历史、当前伙伴和已领取卡片不会因此回退。
- 普通成熟奖励和隐藏发现进入持久化待领取队列，重启 App 后仍会重新出现。
- 领取卡片会归档奖励、更新未查看状态，并播放收集反馈；连续奖励按明确的消失完成时刻依次展示。
- 收集页支持已发现卡片、未发现轮廓、重点卡、网格卡、放大、翻面和辅助功能焦点返回。
- Debug 构建的“我的”页提供两次确认的本地数据重置；Release 不显示该入口。
- Reduce Motion 下不执行奖励卡空间飞行，收集 Tab 也不抖动或缩放，只保留淡出/颜色反馈。

## 奖励飞行动画：不要破坏

这段动画经过多轮真实模拟器排查，已由用户确认修复成功：

- 卡片先轻微上浮，再沿弧线向收集 Tab 飞行并逐渐缩小。
- 到达收集图标中心时缩小到 0，而不是留下残影或飞出屏幕。
- 收集 Tab 在到达时弹跳并显示扩散光环；只有 UIKit 光环动画实际完成后才关闭奖励覆盖层。
- 目标通过真实 `UITabBar` 控件及稳定槽位 fallback 解析，不能依赖相邻控件顺序。
- 飞行起点使用全屏覆盖层的同步几何中心；不要恢复异步卡片 PreferenceKey frame。旧实现领取瞬间可能得到 `(0,0,0,0)`，从而把绝对目标误当位移，导致卡片飞向右侧奖励方向并越出屏幕。

相关实现：

- `LIVELVL/LIVELVL/Collection/CardRewardOverlay.swift`
- `LIVELVL/LIVELVL/MainTabView.swift`
- `LIVELVL/LIVELVLTests/CardRewardPresentationTests.swift`

## 新阶段 Git 工作方式

1. 从最新本地 `main` 创建 `codex/ui-polish`。
2. 使用 `.worktrees/ui-polish` 隔离工作区，不要直接在主工作区开发。
3. 先运行完整基线测试，再按截图或明确需求逐项调整。
4. 每个 UI 问题先确认设计，再用小提交实现和验证。
5. 不要提交 Xcode 自动生成的 `UserInterfaceState.xcuserstate`。
6. `project.pbxproj` 只有在确实修改工程成员或构建配置时才可提交；纯排序或 Xcode 自动改写必须排除。

当前主工作区存在以下 Xcode 本地改动，属于用户状态，不要暂存、覆盖或带入 UI 提交：

- `LIVELVL/LIVELVL.xcodeproj/project.pbxproj`
- `LIVELVL/LIVELVL.xcodeproj/project.xcworkspace/xcuserdata/fy.xcuserdatad/UserInterfaceState.xcuserstate`

## 新聊天开始时

先阅读本文档以及：

- `docs/superpowers/specs/2026-08-23-collection-mvp-design.md`
- `docs/superpowers/plans/2026-08-23-collection-mvp-implementation.md`

然后确认 `main` 位于 `18fc10e` 或其后继提交，创建隔离 UI 分支，并请用户提供第一张需要调整的界面截图或第一项明确需求。不要自行开始奖励商城。
