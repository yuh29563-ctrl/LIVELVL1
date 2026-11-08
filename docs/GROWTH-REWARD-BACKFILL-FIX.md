# 成长卡漏发修复（2026-11-05）

## 根因与处理

卡库仅有前三张时，用户已达到 Lv.5；原逻辑将最高等级推进到 5，却没有生成无素材可用的第 4、5 级奖励。后续扩充卡库只处理新达到的等级，导致这两个 awardKey 永久缺失。

CardRewardService 现在核对已达到的所有等级，以既有 OwnedCollectible 与 PendingCardReward 的 awardKey 防重，只为缺失等级分配下一张尚未拥有且未排队的卡。保留既有卡片 ID、获得等级、时间、原因和已查看状态。领取时伙伴索引只前进，避免迟领旧奖励造成倒退。保留原有保存失败回滚。

## 验证

- 新增磁盘回归：模拟 Lv.65、63 张已有卡、缺第 4/5 级；重开后补齐，重复核对无重复，已有记录不改，反序领取不倒退。
- 新增旧版待领取记录的卡片占用检查，避免将同一卡分配给两个等级。
- 40 项相关测试通过：成长卡批次、奖励服务、领取生命周期、重制迁移、任务奖励协调、每日 XP 磁盘持久化。日志 `/tmp/livelvl-missing-level-green2.log`。既有 CompanionPointCloudRepositoryTests.swift isolation 问题排除；未做全量回归。
- 已在 iPhone 17 Pro 模拟器安装并重开验证，实际存档从 63 张补到 65 张。补发 `ordinary.level.4` → `growth.pulsar-core`，`ordinary.level.5` → `growth.collapsed-star-nest`，沿用稳定 ID 并保留全部已有映射。
- 数据比对确认 XP 128200、Lv.65 不变，原有卡片每条记录不变；任务、日记、金币、自测、塔罗等其他业务表内容不变。

本轮未提交、未推送，未改 Xcode 项目配置或用户本地 UI 状态。
