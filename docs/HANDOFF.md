# LIVELVL 项目交接文档

更新时间：2026-08-20

## 项目目标

LIVELVL 是一款帮助年轻人看见现实成长的生活 RPG。

核心闭环：

> 创建现实任务 → 完成任务 → 获得 XP → 等级成长 → 六维状态变化 → 查看真实成长记录

六个生活维度：健康、学习、事业、财务、关系、兴趣。

Level 代表长期累计成长，只会上升；六维状态代表最近 15 天的生活状态，可以上升或下降。第一版不做 AI、社交、商城、排行榜、抽卡或复杂角色系统。

## 技术环境

- iOS 17+
- Swift、SwiftUI、SwiftData
- 本地持久化，无服务器、无登录
- Xcode 26.6
- 推荐模拟器：iPhone 17 Pro，iOS 26.5

正确的 Xcode 工程：

```text
/Users/fy/Desktop/LIVELVL/LIVELVL/LIVELVL.xcodeproj
```

不要打开旧的根目录工程：`/Users/fy/Desktop/LIVELVL/LIVELVL.xcodeproj`。

## 已完成功能

### 任务和 XP

- 创建一次性、每日、每周任务。
- 选择生活维度、预计时间和难度。
- 系统推荐 XP。
- 完成任务后获得 XP。
- 同一天同一任务不会重复结算。
- 误触取消完成后退回对应 XP。
- 第一次升级需要 200 XP，之后每级需要 2000 XP。

### 六维状态

- Day 0 初始化和每周状态自评。
- 每个维度 1–10 分。
- 最近 15 天状态计算。
- 正式状态和行动预估状态分离。
- 任务完成后显示轻微预增长，不直接改变正式状态。
- 自评后结算正式状态。

### 页面

- 等级卡：等级、当前 XP、升级进度和剩余 XP。
- 六边形生命状态雷达图。
- 正式状态实线区域。
- 行动预估虚线区域。
- 任务完成后对应维度轻微脉冲反馈。
- 状态变化来源提示，例如“学习预计 +0.3，来自「阅读 30 分钟」”。
- 自评倒计时和每周自评入口。
- 成长页复用同一套等级和状态规则。

## 项目结构

```text
/Users/fy/Desktop/LIVELVL/
├── LIVELVL/
│   ├── LIVELVL.xcodeproj/
│   └── LIVELVL/
│       ├── LIVELVLApp.swift
│       ├── ContentView.swift
│       ├── Item.swift
│       ├── Domain/
│       ├── LifeState/
│       ├── Persistence/
│       └── Today/
├── docs/HANDOFF.md
└── .git/
```

关键文件：

- `LIVELVL/LIVELVL/ContentView.swift`：今天、成长、我的三个 Tab 和任务交互。
- `LIVELVL/LIVELVL/Item.swift`：任务、完成记录、XP 和等级。
- `LIVELVL/LIVELVL/Today/LevelCard.swift`：等级卡。
- `LIVELVL/LIVELVL/Today/LifeStateCard.swift`：六维状态卡。
- `LIVELVL/LIVELVL/Today/RadarChartView.swift`：六边形雷达图。
- `LIVELVL/LIVELVL/Domain/LifeStateEngine.swift`：状态计算规则。
- `LIVELVL/LIVELVL/LifeState/StateAssessmentView.swift`：Day 0 和每周自评。

## Git 状态

主分支已经合并验证过的功能分支，当前 HEAD：

```text
ae79a42 docs: record growth page verification
```

重要提交：

```text
adba3b7 feat: add double layer life state radar
7706a54 feat: integrate life state cards into today
755ee81 feat: align growth page with life state model
```

合并前的用户修改已保存在 Git stash 中。不要随意执行 `git stash pop`，否则可能把旧版 ContentView 覆盖回来。

## 验证结果

主项目纯构建已成功：

```text
** BUILD SUCCEEDED **
```

隔离分支测试已通过：18 tests passed across 4 suites。

推荐命令：

```bash
xcodebuild test \
  -project LIVELVL/LIVELVL.xcodeproj \
  -scheme LIVELVL \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -configuration Debug \
  -derivedDataPath /tmp/LIVELVLTest \
  CODE_SIGNING_ALLOWED=NO
```

## 当前首先要确认的问题

用户之前的截图仍然是旧版首页，没有六维图。原因是当时功能只在隔离分支，后来已经合并到主分支；Xcode 也可能仍打开旧工程或使用旧缓存。

重新确认：

1. 关闭当前 Xcode 窗口。
2. 打开 `/Users/fy/Desktop/LIVELVL/LIVELVL/LIVELVL.xcodeproj`。
3. 选择 Scheme `LIVELVL` 和 `iPhone 17 Pro`。
4. Product → Clean Build Folder。
5. 重新运行。
6. 确认首页出现等级卡和六边形状态卡。

如果没有初始化数据，应先完成 Day 0 状态评估。

## 推荐下一个任务

先做真实模拟器验收：

- 确认六边形状态图出现。
- 创建一个学习任务。
- 完成任务，确认 XP 增加。
- 确认学习维度出现行动预估变化。
- 取消完成，确认 XP 退回、预增长消失。
- 进入成长页，确认内容一致。

验收通过后，再做首页视觉打磨、轻量完成反馈、空状态、自评入口、大字体和 VoiceOver 优化。

## 新聊天接入提示词

```text
继续开发 LIVELVL。请先阅读 docs/HANDOFF.md，并打开正确工程：
/Users/fy/Desktop/LIVELVL/LIVELVL/LIVELVL.xcodeproj

当前已经完成等级卡、六边形生命状态图、正式状态/行动预估状态、任务 XP 反馈和成长页整合。请先运行并检查真实界面，不要大规模重构。优先验证六维图是否显示，以及完成任务、撤销任务时 XP 和预增长是否正确。
```

## 开发原则

- 每次只完成一个可运行阶段。
- 修改前先确认打开的是嵌套工程。
- Level 和 State 永远分开。
- 不要让六维图因单个任务大幅跳动。
- 优先验证“现实行动 → 即时反馈 → 看见成长”。

## 2026-08-20 模拟器验收记录

- 使用正确的嵌套工程在 iPhone 17 Pro（iOS 26.5）真实模拟器构建并启动成功。
- 首页确认显示等级卡、六边形状态图、正式状态和行动预估图层。
- 新增学习任务“Read English 30 min”成功，系统推荐 35 XP。
- 完成任务后显示获得 +35 XP，学习行动预估来源更新为该任务。
- 再次点击完成按钮后显示退回 35 XP，任务恢复未完成状态。
- XcodeBuildMCP 测试通过：18 tests passed，0 failed，0 skipped。
