<p align="center">
  <img width="120" src="./assets/logo.png" alt="Simple Live logo">
</p>

<h1 align="center">Simple Live</h1>

<p align="center">
  <strong>简简单单的看直播 —— 基于 Flutter 的全平台开源聚合直播客户端</strong>
</p>

<p align="center">
  <a href="https://flutter.dev">
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
  </a>
  <a href="https://dart.dev">
    <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart">
  </a>
  <a href="https://github.com/xiaoyaocz/dart_simple_live/releases">
    <img src="https://img.shields.io/github/v/release/xiaoyaocz/dart_simple_live?color=orange&label=Release" alt="Release">
  </a>
  <a href="https://github.com/xiaoyaocz/dart_simple_live/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-GPL%20v3-green.svg" alt="License">
  </a>
  <a href="https://github.com/xiaoyaocz/dart_simple_live/stargazers">
    <img src="https://img.shields.io/github/stars/xiaoyaocz/dart_simple_live?style=flat&color=yellow" alt="Stars">
  </a>
</p>

---

> [!WARNING]
> **本项目不提供 Release 安装包，请自行编译后运行测试。**

## 📖 项目介绍

**Simple Live** 是一款基于 Flutter 开发的跨平台开源聚合直播应用。项目旨在提供纯粹、轻量、无广告的直播观看体验，聚合各大主流直播平台，支持移动端、桌面端以及电视大屏端。

## 📸 界面预览

| 浅色模式 | 深色模式 |
| :---: | :---: |
| ![浅色模式](./assets/screenshot_light.jpg) | ![深色模式](./assets/screenshot_dark.jpg) |

---

## ✨ 核心特性

- 🌐 **多平台聚合**：一站式聚合主流直播平台（哔哩哔哩直播、斗鱼直播、虎牙直播、抖音直播）。
- 📺 **全平台支持**：支持 Android、iOS、Windows、macOS、Linux 以及专属 Android TV 大屏端。
- 💬 **高性能弹幕**：基于 Canvas 渲染引擎的高性能实时弹幕，支持弹幕速度、字体大小、不透明度调节及关键字屏蔽。
- 🪟 **多视窗分屏播放**：支持多路直播同屏同时观看与实时切换，多主播对局/赛事不错过。
- 📱 **丰富播放体验**：
  - 自由切换清晰度（蓝光/超清/高清）与播放源（CDN/线路）
  - 支持系统画中画（PiP）与后台纯音频播放
  - 手势操作快捷调节音量、亮度
  - 定时睡眠关闭
- 🌟 **统一关注与分组**：跨平台统一管理关注主播，支持自定义标签分组、开播状态实时展示与通知。
- ☁️ **数据同步与备份**：内置 WebDAV 云端备份与局域网多设备间快速同步配置与关注数据。
- 🎨 **现代 UI 设计**：遵循 Material 3 设计规范，支持动态取色（Dynamic Color）与深浅色模式无缝切换。

---

## 🎯 平台支持矩阵

| 平台 | 移动/桌面端 (`simple_live_app`) | 电视端 (`simple_live_tv_app`) | 终端工具 (`simple_live_console`) |
| :--- | :---: | :---: | :---: |
| **Android** | ✅ 支持 | ✅ 深度适配（遥控器交互） | - |
| **iOS** | ✅ 支持 | - | - |
| **Windows** | ✅ 支持 (Beta) | - | ✅ 支持 |
| **macOS** | ✅ 支持 (Beta) | - | ✅ 支持 |
| **Linux** | ✅ 支持 (Beta) | - | ✅ 支持 |

### 直播平台支持列表

| 平台 | 推荐与分类 | 搜索 | 播放与画质切换 | 实时弹幕 |
| :--- | :---: | :---: | :---: | :---: |
| **哔哩哔哩** | ✅ | ✅ | ✅ | ✅ |
| **斗鱼直播** | ✅ | ✅ | ✅ | ✅ |
| **虎牙直播** | ✅ | ✅ | ✅ | ✅ |
| **抖音直播** | ✅ | ✅ | ✅ | ✅ |

---

## 🏗️ 项目架构

本项目采用模块化架构设计：

```text
dart_simple_live/
├── simple_live_core/       # 纯 Dart 核心逻辑库（各平台接口解析、清晰度获取、WebSocket 弹幕通信）
│   ├── packages/
│   │   ├── dart_quickjs/   # QuickJS Dart 绑定封装
│   │   └── tars_dart/      # Tars 协议 Dart 实现
├── simple_live_app/        # 主客户端（支持 Android / iOS / Windows / macOS / Linux）
├── simple_live_tv_app/     # 专为电视大屏与遥控器交互优化的 Android TV 客户端
└── simple_live_console/    # 命令行测试与控制台工具
```

---

## 🛠️ 本地开发与编译指南

### 1. 环境准备

- [Flutter SDK](https://flutter.dev/docs/get-started/install) : `>= 3.3.0` (推荐 `3.24+`)
- [Dart SDK](https://dart.dev/get-dart) : `>= 3.0.0`
- 对应目标平台的构建工具链（如 Android Studio、Xcode、Visual Studio 等）

### 2. 克隆仓库

```bash
git clone https://github.com/xiaoyaocz/dart_simple_live.git
cd dart_simple_live
```

### 3. 依赖安装与代码生成

进入应用目录并获取依赖：

```bash
# 移动/桌面端客户端
cd simple_live_app
flutter pub get

# 生成 Hive 数据模型适配代码（如需修改数据库模型）
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. 运行与编译打包

#### 运行调试

```bash
# 查看可用设备
flutter devices

# 运行到指定设备
flutter run
# 或指定平台运行，例如：
flutter run -d windows
flutter run -d chrome
flutter run -d <android-device-id>
```

#### 构建产物

```bash
# 构建 Android APK
flutter build apk --release

# 构建 Windows 安装包/程序
flutter build windows --release

# 构建 macOS 应用程序
flutter build macos --release

# 构建 Linux 应用程序
flutter build linux --release

# 构建 iOS 应用程序 (需在 macOS 环境)
flutter build ipa --release
```

#### Android TV 客户端编译

```bash
cd ../simple_live_tv_app
flutter pub get
flutter build apk --release
```

---

## 🔗 参考与致谢

感谢以下优秀开源项目与社区贡献者的启发和支持：

- [AllLive](https://github.com/xiaoyaocz/AllLive) - 本项目的 C# 版本实现
- [dart_tars_protocol](https://github.com/xiaoyaocz/dart_tars_protocol.git) - Tars 协议 Dart 解析
- [wbt5/real-url](https://github.com/wbt5/real-url) - 获取各大直播平台真实流媒体地址
- [lovelyyoshino/Bilibili-Live-API](https://github.com/lovelyyoshino/Bilibili-Live-API/blob/master/API.WebSocket.md) - B站直播 WebSocket 协议分析
- [IsoaSFlus/danmaku](https://github.com/IsoaSFlus/danmaku) - 弹幕库参考
- [BacooTang/huya-danmu](https://github.com/BacooTang/huya-danmu) - 虎牙直播弹幕解析
- [TarsCloud/Tars](https://github.com/TarsCloud/Tars) - Tars 框架
- [YunzhiYike/douyin-live](https://github.com/YunzhiYike/douyin-live) - 抖音直播解析
- [5ime/Tiktok_Signature](https://github.com/5ime/Tiktok_Signature) - 签名算法参考

---

## ⚖️ 免责声明

1. 本项目的所有功能均基于互联网公开接口与技术资料开发，不包含任何逆向破解或绕过付费等行为。
2. 本项目仅供编程技术交流与个人学习使用，**严禁用于任何商业目的**。使用者因商业使用产生的一切后果与本项目及开发者无关。
3. 若本项目任何内容无意中侵犯了您的合法权益，请联系开发者，我们将及时进行核实并移除相关内容。

---

## 📈 Star History

<a href="https://www.star-history.com/#xiaoyaocz/dart_simple_live&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=xiaoyaocz/dart_simple_live&type=Date" />
 </picture>
</a>
