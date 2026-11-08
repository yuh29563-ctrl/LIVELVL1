# 旅途指引永久卡片

日期：2026-11-05。

## 产品规则

五张卡片按 01–05 的固定顺序作为收集页的前缀；未来加入同类永久卡片时，继续位于所有获得的成长／隐藏收藏之前。空收藏、新用户及重置后的收集页同样直接显示永久卡片。

这类卡片属于产品内置说明，不保存为 OwnedCollectible，不创建 PendingCardReward，不计入成长卡库、XP、金币、奖励队列或未查看奖励；不修改 SwiftData schema。

正面为单幅图片，轮播下方保留标题及“旅途指引／永久保留”标识。用户提供的故事、使用说明和强调文字全部放在可滚动的背面，不套用成熟卡的获得时间、获得原因或成长阶段。保留原轮播居中、放大翻面、关闭后位置与焦点恢复，以及 Reduce Motion、Dynamic Type、VoiceOver 和塔罗入口。

## 稳定身份与图片

| 编号 | 永久 ID | 图片 asset | 来源位置 |
| --- | --- | --- | --- |
| 01 | permanent.journey.awareness | JourneyGuide01 | 左上水母 |
| 02 | permanent.journey.action | JourneyGuide02 | 中左星环 |
| 03 | permanent.journey.memory | JourneyGuide03 | 中右沙漏 |
| 04 | permanent.journey.rewards | JourneyGuide04 | 左下双核 |
| 05 | permanent.journey.growth | JourneyGuide05 | 右下花朵 |

原图 `/Users/fy/Downloads/透明背景上的五幅点彩抽象图.png` 实际为 1024×1536 RGB，棋盘格已写入像素。经用户选择，使用内置 imagegen 去除棋盘格，输出真正的 RGBA 图，再用 CoreGraphics 从透明合成图精确裁切五个 512×512 单图；不覆盖原图。最终图片位于 `LIVELVL/LIVELVL/Assets.xcassets/JourneyGuide01.imageset` 至 `JourneyGuide05.imageset`。来源、坐标和 SHA-256 见 `JOURNEY-GUIDE-ASSETS.json`。

文案由 `PermanentCollectionCatalog.cards` 明确保存，永久卡片通过 `ArchiveCollectiblePresentation.permanent` 参与共享轮播和放大视图。后续永久说明卡在目录中追加，使用新的稳定 ID；`items(owned:permanentCards:)` 保证其仍排在获得卡片之前，无需写入用户数据库。

## 图片处理提示词

使用内置 imagegen，transparent_background=true：

> Edit the provided sheet ONLY to remove the faint gray/white checkerboard baked into the background and replace that background with true transparent alpha. Preserve the five black and gray stippled/pointillist illustrations with maximum fidelity, all tiny separated ink dots and filaments, their original scale, positions, orientation, silhouette, and entire canvas framing. Top left is the jellyfish, middle left the ring gate, middle right the hourglass, bottom left linked double cores, bottom right the flower. Do not redesign, simplify, add text, sharpen into solid silhouettes, rearrange, or add/remove any illustration. Keep the original 1024 x 1536 portrait composition and generous separation. This is a background-removal restoration for production UI assets, not a new illustration. Output a genuinely transparent PNG.

## 验证边界

本次运行永久卡片数据／资源测试、收集状态测试、奖励呈现相关测试及空收藏／塔罗呈现测试，结果以本轮最终运行记录为准。完整回归、真实旧存档迁移链路和统一验收仍按前期安排延后。已知的 CompanionPointCloudRepositoryTests.swift isolation 编译问题继续单独排除，不在本次修改范围内。

## 本轮结果

- 五个 512×512 RGBA 资源均可解码，来源图哈希保持不变。
- 永久卡片顺序、未来同类卡片前置、空收藏默认显示、不创建获得记录、未查看状态不受影响、翻面关闭后选择恢复等新增测试通过。
- 本轮相关测试合计 68 项，67 项通过。`emptyArchiveKeepsTheDailyTarotEntryAvailable()` 的 UIKit 无障碍标识读取断言失败；测试窗口截图已确认第 1 张指引及今日塔罗实际可见。该断言仍保留，未将其排除后宣称全部通过。
- 相关运行记录：`/Users/fy/Desktop/LIVELVL-backups/20261104-162618/journey-ready-simulator.xcresult`；此前一次 Debug 构建及 iPhone 17 Pro 启动成功。
- 用户在模拟器中亲自测试后反馈“我个人测试没啥问题呀”。按该反馈结束本次界面读取排查，恢复原测试辅助代码，不把试验性的无障碍分组改动留在产品中。
- 本轮未提交、未推送；临时测试升级按钮和伙伴测试图保持已有状态。
