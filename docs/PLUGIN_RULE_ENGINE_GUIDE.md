# Simple Live 动态插件与在线规则引擎开发指南 (Plugin & Rule Engine Guide)

---

## 1. 概述与核心特性

Simple Live 动态插件与规则引擎提供了解耦、可在线热更新的直播解析方案：
- **双模解析**：支持 **声明式 JSON DSL 规则**（极简免代码配置）与 **JavaScript 沙箱脚本**（基于 QuickJS-ng，支持复杂加密算法与动态签名）。
- **零编译热更新**：支持通过远程订阅 URL、剪贴板导入或扫码导入，规则即刻生效无需打包发布 App。
- **无感适配**：插件内部自动桥接并映射为 `LiveSite` 标准 Dart 强类型对象。

---

## 2. 插件文件结构与 Manifest 规范

每个插件由元数据（Manifest）与解析逻辑（DSL JSON 或 JS 脚本）组成，可封装为一个 `.plugin.json` 文件：

```json
{
  "id": "site_example",
  "name": "示例直播平台",
  "version": "1.0.0",
  "type": "js", 
  "author": "SimpleLive",
  "description": "基于 JS 沙箱的示例直播平台插件",
  "icon": "https://example.com/icon.png",
  "entry": "index.js",
  "updateUrl": "https://raw.githubusercontent.com/.../example.plugin.json",
  "permissions": ["network"],
  "scriptContent": "/* JS 脚本源码或 DSL JSON 字符串 */"
}
```

### 字段说明：
| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | `string` | 平台唯一标识，如 `site_kuaishou`, `site_twitch` |
| `name` | `string` | 平台显示名称，如 `快手直播` |
| `version` | `string` | 语义化版本号，如 `1.0.0` |
| `type` | `string` | 插件类型：`"js"` 或 `"dsl"` |
| `author` | `string` | 作者名称 |
| `description`| `string` | 插件功能简述 |
| `icon` | `string` | 图标 URL 或本地内置 Asset 路径 |
| `entry` | `string` | 入口文件名（如 `index.js` 或 `rules.json`） |
| `updateUrl` | `string` | 在线检测与静默热更新的下载地址 |
| `scriptContent`| `string`| 内嵌的 JS 脚本代码或 DSL 规则 JSON 字符串 |

---

## 3. 声明式 DSL 规则规范 (`type: "dsl"`)

DSL 规则适用于结构规范的 RESTful API 平台。

### 3.1 变量插值与路径提取
- **变量插值**：在 `url`、`params`、`headers`、`body` 中使用 `{{key}}` 自动替换。
  - `{{roomId}}`：房间 ID
  - `{{page}}`：分页页码
  - `{{keyword}}`：搜索关键词
  - `{{categoryId}}`：分类 ID
  - `{{qualityData}}`：选中的清晰度标识
- **路径导航**：支持点号层级（`data.room.title`）及数组下标（`items[0].url`）。
- **正则表达式**：在非标准 JSON 返回（如 HTML 页面）时配置 `regex` 截取目标 JSON 字符串。

### 3.2 完整 DSL 规则示例
```json
{
  "categories": {
    "url": "https://api.example.com/v1/categories",
    "method": "GET",
    "mapping": {
      "list": "data.category_list",
      "id": "id",
      "name": "title",
      "children": "sub_categories",
      "childId": "id",
      "childName": "name",
      "childPic": "icon_url"
    }
  },
  "recommendRooms": {
    "url": "https://api.example.com/v1/rooms/recommend",
    "method": "GET",
    "params": {
      "page": "{{page}}",
      "page_size": "20"
    },
    "mapping": {
      "list": "data.items",
      "roomId": "room_id",
      "title": "room_title",
      "cover": "cover_image",
      "userName": "anchor_name",
      "online": "online_count",
      "hasMore": "data.has_more"
    }
  },
  "roomDetail": {
    "url": "https://api.example.com/v1/room/info",
    "method": "GET",
    "params": {
      "id": "{{roomId}}"
    },
    "mapping": {
      "title": "data.title",
      "cover": "data.cover",
      "userName": "data.anchor.nickname",
      "userAvatar": "data.anchor.avatar",
      "online": "data.online_num",
      "status": "data.is_live",
      "url": "data.share_url"
    }
  },
  "playQualities": [
    { "quality": "超清 1080P", "data": "1080p", "sort": 1 },
    { "quality": "高清 720P", "data": "720p", "sort": 2 },
    { "quality": "标清 540P", "data": "540p", "sort": 3 }
  ],
  "playUrls": {
    "url": "https://api.example.com/v1/room/stream",
    "method": "GET",
    "params": {
      "room_id": "{{roomId}}",
      "quality": "{{qualityData}}"
    },
    "headers": {
      "User-Agent": "Mozilla/5.0 SimpleLive/1.0",
      "Referer": "https://example.com"
    },
    "mapping": {
      "urls": "data.stream_urls"
    }
  }
}
```

---

## 4. JavaScript 沙箱脚本规范 (`type: "js"`)

JS 插件运行在轻量 QuickJS 沙箱中，适用于需要参数混淆、签名计算、Cookie 组装或复杂数据洗练的平台。

### 4.1 宿主全局对象 `SimpleLive` API
- `SimpleLive.registerSite(siteObject)`：注册插件站点对象。
- `SimpleLive.regex.find(str, pattern, groupIndex)`：正则表达式提取匹配子串。

### 4.2 HTTP 异步调度协议
JS 脚本可直接返回 `__type: "http_request"` 指令对象，由 Dart 宿主发起原生网络请求，并将返回内容通过 `callback` 回传给指定 JS 函数：

```javascript
// 触发网络请求
return {
  __type: 'http_request',
  url: 'https://api.example.com/info?roomId=' + roomId,
  method: 'GET',
  headers: { 'User-Agent': 'Mozilla/5.0' },
  callback: '_onGetRoomDetail' // 请求完成后回调的方法名
};
```

### 4.3 完整 JS 插件代码示例
```javascript
SimpleLive.registerSite({
  id: "site_kuaishou",
  name: "快手直播",

  // 1. 获取分类列表
  getCategories: function() {
    return [
      {
        id: "game",
        name: "游戏专区",
        children: [
          { id: "lol", name: "英雄联盟", pic: "https://example.com/lol.png" },
          { id: "honor", name: "王者荣耀", pic: "https://example.com/honor.png" }
        ]
      }
    ];
  },

  // 2. 获取推荐房间
  getRecommendRooms: function(page) {
    return {
      hasMore: false,
      items: [
        {
          roomId: "10001",
          title: "快手热门直播间",
          cover: "https://example.com/cover.png",
          userName: "官方推荐主播",
          online: 88888
        }
      ]
    };
  },

  // 3. 读取房间详情
  getRoomDetail: function(roomId) {
    return {
      roomId: roomId,
      title: "快手直播间 " + roomId,
      cover: "https://example.com/cover_" + roomId + ".png",
      userName: "快手主播",
      userAvatar: "https://example.com/avatar.png",
      online: 12500,
      status: true,
      url: "https://live.kuaishou.com/u/" + roomId
    };
  },

  // 4. 清晰度列表
  getPlayQualities: function(detail) {
    return [
      { quality: "超清 1080P", data: "1080p", sort: 1 },
      { quality: "高清 720P", data: "720p", sort: 2 }
    ];
  },

  // 5. 提取流地址
  getPlayUrls: function(detail, quality) {
    return {
      urls: [
        "https://txmov2.a.yximgs.com/bs2/livestream/" + detail.roomId + "_" + quality.data + ".flv",
        "https://txmov2.a.yximgs.com/bs2/livestream/" + detail.roomId + "_" + quality.data + ".m3u8"
      ],
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "Referer": "https://live.kuaishou.com/"
      }
    };
  },

  // 6. 查询开播状态
  getLiveStatus: function(roomId) {
    return true;
  }
});
```

---

## 5. 在线订阅源仓库清单格式 (`plugins_index.json`)

发布插件仓库时，提供 `plugins_index.json` 作为订阅入口：

```json
{
  "name": "Simple Live 社区插件源",
  "version": "1.0.0",
  "updatedAt": "2026-08-30",
  "plugins": [
    {
      "id": "site_kuaishou",
      "name": "快手直播",
      "version": "1.0.0",
      "type": "js",
      "author": "SimpleLive",
      "description": "快手直播解析插件",
      "icon": "https://example.com/kuaishou.png",
      "downloadUrl": "https://raw.githubusercontent.com/.../kuaishou.plugin.json"
    }
  ]
}
```

---

## 6. 在 App 中管理与使用

1. 打开 Simple Live，进入 **「设置」 -> 「其他设置」 -> 「插件与规则引擎」**。
2. **导入插件**：
   - 点击右上角 **「+」** 或 **「导入插件 / 订阅」**。
   - 输入在线订阅 URL 或直接粘贴 JSON / JS 脚本内容。
   - 也可点击 **「示例插件」** 一键快速载入内置预设插件。
3. **启停与排序**：
   - 在列表中通过 Switch 开关启用或停用指定插件。
   - 启用的插件自动出现在首页及「站点管理」排序列表中。
4. **代码预览与更新**：
   - 点击插件项右侧更多按钮，可随时「查看规则/代码」或「检查更新」。
