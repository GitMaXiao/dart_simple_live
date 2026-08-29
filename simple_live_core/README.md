# simple_live_core

Simple Live 跨平台聚合直播核心库（纯 Dart 实现），负责各直播平台的接口解析、流媒体地址提取与 WebSocket 实时弹幕协议交互。

## 📦 支持平台与接口

- **Bilibili 直播** (`BiliBiliSite`)
- **斗鱼直播** (`DouyuSite`)
- **虎牙直播** (`HuyaSite`)
- **抖音直播** (`DouyinSite`)

## 🛠️ 包含子模块

- `packages/dart_quickjs`: QuickJS JavaScript 引擎 Dart FFI 绑定封装，用于执行各平台加密签名算法。
- `packages/tars_dart`: Tars 编解码协议的纯 Dart 实现（用于虎牙等平台协议解析）。

