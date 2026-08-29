# Simple Live App

基于 `simple_live_core` 核心库实现的 Flutter 跨平台聚合直播客户端（支持 Android / iOS / Windows / macOS / Linux）。

## 📱 模块功能

- **直播聚合浏览**：首页推荐、平台分类、分区列表、全站搜索。
- **直播间功能**：多流清晰度切换、线路切换、实时弹幕互动、画中画（PiP）、后台音频播放、定时关闭。
- **多视窗播放**：同屏多路直播分屏同时观看与切换。
- **关注与管理**：主播分类标签分组、开播状态实时提醒与排序、观看历史。
- **数据同步与设置**：WebDAV 备份恢复、局域网多端同步、Material 3 动态色彩与深色模式。

## 🚀 快速开始

```bash
# 获取依赖
flutter pub get

# 运行代码生成器（Hive 数据模型）
flutter pub run build_runner build --delete-conflicting-outputs

# 启动运行
flutter run
```
 