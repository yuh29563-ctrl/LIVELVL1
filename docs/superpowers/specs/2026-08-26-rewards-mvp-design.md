# LIVELVL 现实奖励兑换 MVP 设计规格

## 目标与边界

本阶段把现有“奖励”占位页替换为完全本地运行的现实奖励兑换模块。用户通过完成任务获得金币，再使用金币兑换自己创建的现实奖励；模块不连接网络、账户、云同步、真实支付、物流或商城后台。

现实奖励模块是独立领域。它不复用或改写伙伴成熟卡、隐藏发现卡、`PendingCardReward`、`OwnedCollectible`、`CollectionProgress`、`CardRewardService` 或收集卡飞向“收集”Tab 的呈现状态机。现有收集奖励动画只作为回归保护对象，不作为现实奖励的实现依赖。

本阶段包含：

- 整数最小单位金币账本。
- 既有 XP 的一次性导入。
- 任务完成发币与任务撤销扣币。
- 用户创建、编辑和归档现实奖励。
- 可选静态图片及本地图片原子替换。
- 余额不足保护、二次兑换确认和重复点击幂等。
- 兑换快照与“待兑现 / 已兑现”状态。
- 兑换历史、重启恢复和 Debug 全量重置。
- Dynamic Type、VoiceOver 和 Reduce Motion 支持。

本阶段不包含：

- 兑换取消、退款、库存、重复兑换限制或真实支付。
- 商品分类、排序算法、网络图片、GIF/动图或图片云备份。
- 对收集奖励流程的重构。

## 已确认的产品规则

### 金币单位

内部使用整数 `coinUnit`，避免浮点累计误差：

- `1 XP = 1 coinUnit`。
- `10 coinUnit = 1.0 金币`。
- 所有价格存为正整数 `coinUnit`。
- UI 统一用一位小数显示金币，例如 `12.3 金币`。
- 余额等于有效金币流水的整数总和，任何写入都必须保证结果不小于 0。

### 既有 XP 首次导入

金币账本第一次初始化时读取当前 `Progress.totalXP`，写入唯一业务键为 `legacy-xp-import` 的收入流水。导入只发生一次；即使重复打开奖励页、重启 App 或重复执行初始化，也不能再次导入。

初始化必须发生在任何新的任务完成发币之前。这样已有 XP 由一次性导入覆盖，初始化之后的新任务由各自的完成事件流水记录，不会重复计算。

### 任务完成与撤销

完成任务后按该完成事件的 XP 发放等量 `coinUnit`。每个完成事件拥有稳定的事件 ID，收入流水以该 ID 生成幂等键。

撤销任务时写入对应的撤销流水，尝试扣回该任务尚未消费的金币：

- 当前余额足够时，扣回全部对应金币。
- 当前余额不足时，只扣到 0，不建立负债。
- 余额绝不允许为负。
- 已经成功兑换的记录不会被取消、追回或修改。
- 撤销流水保存请求扣回量和实际扣回量，保证行为可审计。
- 撤销后重新完成同一任务会产生新的完成事件和新的收入流水。

### 商品生命周期

用户自行创建奖励。商品字段为：

- 必填名称，去除首尾空白后不能为空。
- 正整数价格 `priceCoinUnits`。
- 可选备注。
- 可选静态图片引用。
- `createdAt`。
- `updatedAt`。
- `isArchived`。

不提供硬删除。用户界面的“删除”语义统一为归档：归档商品从活跃列表消失、不可新兑换，但历史记录永久保留。

商品可以编辑名称、价格、备注和图片。编辑只影响当前商品，不影响已产生的兑换快照。

### 兑换生命周期

兑换成功后创建一条不可变商品快照，初始状态为 `待兑现`。用户可以在历史详情中把它标记为 `已兑现`；该状态转换只发生一次，不包含退款或回滚。

快照至少保存：

- 商品 ID（商品仍存在时用于关联）。
- 商品名称。
- 兑换时价格。
- 兑换时备注。
- 兑换时图片引用。
- 兑换时间。
- 兑现状态。

商品后续改名、改价、换图或归档，都不能改变历史页面显示的名称、价格、备注和图片。

## 领域模型

### `CoinTransaction`

SwiftData 持久化不可变金币流水：

- `id: UUID`。
- `operationKey: String`，唯一，用于幂等。
- `kindRaw: String`：`legacyImport`、`taskEarned`、`taskRevoked`、`redemptionDebit`。
- `amountCoinUnits: Int`，收入为正，扣减为负。
- `requestedCoinUnits: Int`，记录业务请求量；普通收入与兑换时等于实际量。
- `sourceID: UUID?`，任务完成或兑换请求的来源 ID。
- `createdAt: Date`。
- `note: String`。

模型没有公开的余额可变字段。`CoinLedgerService.balance(in:)` 每次从流水计算整数余额，并在发现负数时抛出一致性错误；正常业务路径在插入扣减前先检查余额，因此不会写入负余额。

### `RewardProduct`

SwiftData 当前商品模型：

- `id: UUID`。
- `name: String`。
- `priceCoinUnits: Int`。
- `note: String`。
- `imageReference: String?`。
- `createdAt: Date`。
- `updatedAt: Date`。
- `isArchived: Bool`。

只有未归档、名称有效且价格为正的商品可以兑换。

### `RewardRedemption`

SwiftData 兑换历史模型：

- `id: UUID`。
- `requestKey: String`，唯一，用于兑换提交幂等。
- `productID: UUID?`。
- `productNameSnapshot: String`。
- `priceCoinUnitsSnapshot: Int`。
- `noteSnapshot: String`。
- `imageReferenceSnapshot: String?`。
- `redeemedAt: Date`。
- `statusRaw: String`：`pending` 或 `fulfilled`。
- `fulfilledAt: Date?`。

兑换记录一旦创建，快照字段不再被商品编辑操作修改。只有状态和 `fulfilledAt` 可以通过明确的“标记已兑现”动作改变。

### `Completion` 事件 ID

为现有 `Completion` 增加稳定 `id: UUID`，用于金币流水幂等和撤销关联。它不改变收集系统现有的完成事实、隐藏规则或成熟奖励语义。

### 图片文件

`RewardProductImageStore` 只管理：

```text
Application Support/RewardProductImages/<UUID>.image
```

图片文件使用 UUID 名称并视为不可变内容。商品换图时写入新文件并更新新引用；旧文件只有在没有任何商品或兑换快照引用时才可清理。该 store 不访问 `UserCardMedia` 或其他图片目录。

## 领域服务与事务边界

### `CoinLedgerService`

负责：

- 首次 XP 导入。
- 查询整数余额和流水。
- 以唯一业务键发放收入。
- 撤销任务的部分或全部扣回。
- 创建兑换扣币流水。

它不负责商品 UI、收集卡奖励或文件图片。

### `RewardProductImageStore`

负责：

- 保存新图片。
- 读取稳定引用。
- 删除未被引用的文件。
- 在替换失败时清理临时文件。

图片数据只允许静态格式；图片引用不把二进制写入 SwiftData。

### `RewardStoreService`

负责商品和兑换用例：

- `ensureLegacyXPImported(in:)`。
- `createProduct(name:priceCoinUnits:note:imageReference:in:)`。
- `updateProduct(_:name:priceCoinUnits:note:imageReference:in:)`。
- `archiveProduct(_:in:)`。
- `redeem(product:requestKey:in:)`。
- `markFulfilled(_:in:)`。

兑换是一个单一 SwiftData 保存事务：

1. 通过 `requestKey` 查找已存在结果；存在则直接返回原兑换，不重复扣币。
2. 重新读取商品，确认商品未归档。
3. 计算当前整数余额并检查价格。
4. 插入 `redemptionDebit` 流水。
5. 插入商品快照兑换记录。
6. 一次 `context.save()`。
7. 任何错误都 `context.rollback()`，确保余额和兑换记录同时失败。

商品编辑与归档各自只保存商品状态；归档不删除图片或历史。

### 任务完成接入

在现有 `ContentView.confirmCompletion()` 中，保存完成事件和 XP 前初始化金币账本；完成保存成功后调用独立的金币收入服务。金币处理失败时，不能把 UI 显示为成功，且必须回滚本次完成和 XP 变更或通过同一错误路径重试；不得调用或修改 `CardRewardService` 来处理金币。

撤销任务时，在删除完成记录和扣 XP 的同一错误处理路径中调用金币撤销服务。失败时保留原完成记录和 XP，不能只完成一半撤销。

收集奖励仍只由原有 `CardRewardService.processCompletion` 处理；两者通过调用方并列存在，互不读取对方模型。

## UI 设计

`RewardPlaceholderView` 改为 `RewardStoreView`，保留现有奖励 Tab 的导航外壳和全局收集奖励覆盖层。

页面结构：

1. 导航标题“奖励”。
2. 顶部余额卡片，显示一位小数金币和“来自任务 XP”的说明。
3. 活跃奖励列表。
4. 新建奖励按钮。
5. 兑换历史入口。
6. 归档商品不出现在默认活跃列表，但历史不受影响。

商品编辑使用 `.sheet(item:)`，表单包括名称、价格、备注和静态图片选择；保存按钮在字段无效时禁用并显示明确错误。

兑换使用商品绑定的确认弹窗，展示商品名称、价格和兑换后的余额；余额不足时显示原因，不产生任何数据库变化。

成功兑换后显示短暂的本地完成反馈，并保持在奖励页；不触发收集卡动画、不切换 Tab。

历史页面按时间倒序展示快照，使用状态标签和 VoiceOver 文案区分“待兑现 / 已兑现”。

所有交互遵守：

- Dynamic Type 下名称、备注、按钮不截断或重叠。
- VoiceOver 读出商品名称、价格、可兑换状态、归档状态、兑换时间和兑现状态。
- 图片提供商品名相关的可访问性标签，图片缺失时仍有文本信息。
- Reduce Motion 下只使用淡入、颜色或静态状态变化，不使用必要的空间飞行动画。
- 现实奖励 UI 不修改 `CardRewardOverlay`、`CollectionTabFeedbackBridge` 或 Tab 坐标解析。

## Debug 全量重置

扩展现有 `LocalDataResetService` 的明确删除清单，新增：

- `CoinTransaction`。
- `RewardProduct`。
- `RewardRedemption`。

并删除 `Application Support/RewardProductImages` 目录。保留现有伙伴媒体清理和部分失败报告语义；奖励图片清理失败必须可诊断，不能静默成功。

Debug 双确认行为不变；Release 不显示重置入口。

## 测试策略与验收标准

每个行为先写失败测试，确认失败原因是缺少目标行为，再写最小实现并运行聚焦测试和完整 Debug 测试。

领域测试至少覆盖：

- 1 XP、0 XP、负输入保护和一位小数显示。
- 首次 XP 导入、重复初始化和新完成不重复导入。
- 多次任务收入、完成事件幂等和重新完成的新事件。
- 全额撤销、余额不足时部分撤销、余额保持零。
- 商品字段验证、编辑、归档和归档后不可兑换。
- 余额不足兑换无副作用。
- 成功兑换同时扣币并创建快照。
- SwiftData 保存失败时扣币和兑换记录共同回滚。
- 重复 request key 不重复扣币。
- 修改或归档商品不改变历史快照。
- 待兑现与已兑现状态转换幂等。
- 图片新建、替换、失败回滚和无孤儿引用清理。
- Debug 重置清除三类新模型及图片目录。

模拟器验收至少覆盖：

- 创建奖励、编辑、归档。
- 余额不足、成功兑换、重复点击。
- 强制退出并重启后余额、商品、兑换历史恢复。
- 图片创建、替换、历史快照保留。
- 待兑现标记为已兑现。
- Dynamic Type、VoiceOver、Reduce Motion。
- Debug 重置后恢复初始状态。
- 现有收集奖励卡飞向“收集”Tab 的真实 iPhone 17 Pro 坐标、队列顺序和 Reduce Motion 回归。

## 不变量

- 任何有效余额都为非负整数 `coinUnit`。
- 每个业务事件最多产生一条相应金币流水。
- 一次兑换要么同时扣币并写入快照，要么两者都不发生。
- 重复兑换提交不会重复扣币。
- 归档商品不可新兑换，历史兑换永不丢失。
- 删除或替换商品图片不会删除仍被历史引用的图片。
- Debug 重置会清除现实奖励领域的全部本地数据和图片。
- `CardRewardService`、收集模型和收集动画的语义不因本模块改变。
