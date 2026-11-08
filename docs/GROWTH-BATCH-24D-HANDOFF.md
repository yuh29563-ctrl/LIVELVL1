# 成长卡第五批 24 张（2026-11-06）

按用户给出的八组顺序追加第 88–111 张，普通卡索引 87–110。每行对应一张卡，左幼年、右成熟；今天页幼年，奖励及获得后收藏成熟。卡背加入独立编写的奇幻励志故事。旅途指引仍永久置前。

## 内容与素材

- 完整名称、稳定 ID、主题、短句、故事和源图映射：`GROWTH-BATCH-24D-CONTENT.json`。
- 48 幅图片的来源、源／输出 SHA-256、精确裁切坐标和画布缩放：`GROWTH-BATCH-24D-ASSETS.json`。
- 八张原图均为 1024×1536 RGBA，直接保留原透明通道。只拆分与必要画布缩放，没有生成新图案。源图保存在 `/Users/fy/Desktop/LIVELVL-backups/20261105-growth-v1/batch24d-source-sheets`。
- 共 111 张成长卡、222 幅幼年／成熟图。既有 87 个定义、174 条素材映射、174 幅图片与本轮开始时完全一致；奖励服务未改动。

## 验证与交付

40 项相关测试通过，覆盖批次顺序、全库素材读取与唯一性、奖励排序／幂等、领取衔接和磁盘迁移／重开。日志 `/tmp/livelvl-batch24d-tests.log`；结果位于 `/Users/fy/Desktop/LIVELVL-backups/20261104-162618/TestArtworkDerivedData/Logs/Test/Test-LIVELVL-2026.11.06_10-36-38-+0800.xcresult`。既有 CompanionPointCloudRepositoryTests.swift isolation 问题按前次约定排除，未做全量回归。

已检查 48 幅拆分预览，安装并打开 iPhone 17 Pro 模拟器新版。安装前的全部 77 条已有卡片记录逐条保持不变；12 个非成长进度业务表内容一致。核验期间模拟器持续进行升级测试，等级从 Lv.77 增至 Lv.99，新增奖励按 Lv.78–99 顺序对应原有及本批卡片。代理没有点击测试升级按钮，没有回写等级或重新分配已有卡片。

Xcode 本地配置与 UI 状态未改动；未提交、未推送。
