import 'dart:convert';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('1. LivePluginManifest 测试用例', () {
    test('完整 Manifest 序列化与反序列化测试', () {
      final jsonMap = {
        'id': 'site_kuaishou',
        'name': '快手直播',
        'version': '1.0.2',
        'type': 'js',
        'author': 'SimpleLive Team',
        'description': '快手直播动态解析插件',
        'icon': 'https://example.com/icon.png',
        'entry': 'index.js',
        'updateUrl': 'https://example.com/update.json',
        'homepage': 'https://github.com/example/plugin',
        'minAppVersion': '1.0.0',
        'permissions': ['network', 'storage'],
        'scriptContent': 'console.log("hello");',
      };

      final manifest = LivePluginManifest.fromJson(jsonMap);
      expect(manifest.id, 'site_kuaishou');
      expect(manifest.name, '快手直播');
      expect(manifest.version, '1.0.2');
      expect(manifest.type, LivePluginType.js);
      expect(manifest.author, 'SimpleLive Team');
      expect(manifest.description, '快手直播动态解析插件');
      expect(manifest.icon, 'https://example.com/icon.png');
      expect(manifest.entry, 'index.js');
      expect(manifest.updateUrl, 'https://example.com/update.json');
      expect(manifest.homepage, 'https://github.com/example/plugin');
      expect(manifest.permissions, ['network', 'storage']);
      expect(manifest.scriptContent, 'console.log("hello");');

      final serialized = manifest.toJson();
      expect(serialized['id'], 'site_kuaishou');
      expect(serialized['type'], 'js');
      expect(serialized['permissions'], ['network', 'storage']);
    });

    test('DSL 类型与默认值解析测试', () {
      final dslJson = {
        'id': 'site_dsl_demo',
        'name': 'DSL 平台',
        'type': 'dsl',
      };

      final manifest = LivePluginManifest.fromJson(dslJson);
      expect(manifest.id, 'site_dsl_demo');
      expect(manifest.type, LivePluginType.dsl);
      expect(manifest.version, '1.0.0');
      expect(manifest.entry, 'rules.json');
      expect(manifest.permissions, isEmpty);
    });
  });

  group('2. JsPluginEngine & DynamicLiveSite 全量方法测试用例', () {
    late DynamicLiveSite dynamicSite;

    const fullJsPluginCode = r'''
SimpleLive.registerSite({
  id: 'site_mock_full',
  name: 'Mock Full JS Site',

  getCategories: function() {
    return [
      {
        id: 'game',
        name: '游戏',
        children: [
          { id: 'lol', name: '英雄联盟', pic: 'http://example.com/lol.png' },
          { id: 'dota', name: '刀塔', pic: 'http://example.com/dota.png' }
        ]
      },
      {
        id: 'ent',
        name: '娱乐',
        children: []
      }
    ];
  },

  getRecommendRooms: function(page) {
    return {
      hasMore: page < 3,
      items: [
        { roomId: '1001', title: '推荐房间1', cover: 'http://example.com/1.png', userName: '主播1', online: 999 },
        { roomId: '1002', title: '推荐房间2', cover: 'http://example.com/2.png', userName: '主播2', online: 888 }
      ]
    };
  },

  getCategoryRooms: function(category, page) {
    return {
      hasMore: false,
      items: [
        { roomId: '2001', title: category.name + '的房间', cover: '', userName: '分类主播', online: 666 }
      ]
    };
  },

  searchRooms: function(keyword, page) {
    return {
      hasMore: false,
      items: [
        { roomId: '3001', title: '搜索到: ' + keyword, cover: '', userName: '搜索主播', online: 500 }
      ]
    };
  },

  searchAnchors: function(keyword, page) {
    return {
      hasMore: false,
      items: [
        { roomId: '4001', userName: '主播_' + keyword, avatar: 'http://example.com/av.png', liveStatus: true }
      ]
    };
  },

  getRoomDetail: function(roomId) {
    return {
      roomId: roomId,
      title: '直播间 ' + roomId,
      userName: '测试主播',
      userAvatar: 'http://example.com/avatar.png',
      cover: 'http://example.com/cover.png',
      online: 12345,
      status: true,
      introduction: '房间简介文本',
      notice: '主播公告文本',
      url: 'http://example.com/room/' + roomId
    };
  },

  getPlayQualities: function(detail) {
    return [
      { quality: '原画 1080P', data: '1080p', sort: 1 },
      { quality: '高清 720P', data: '720p', sort: 2 }
    ];
  },

  getPlayUrls: function(detail, quality) {
    return {
      urls: [
        'http://stream.example.com/' + detail.roomId + '_' + quality.data + '.flv',
        'http://stream.example.com/' + detail.roomId + '_' + quality.data + '.m3u8'
      ],
      headers: {
        'User-Agent': 'Mozilla/5.0 SimpleLive',
        'Referer': 'http://example.com'
      }
    };
  },

  getLiveStatus: function(roomId) {
    return roomId !== 'offline_room';
  },

  getSuperChatMessage: function(roomId) {
    return [
      {
        userName: '粉丝1号',
        face: 'http://example.com/fan1.png',
        message: '主播加油！',
        price: 100,
        startTime: 1700000000000,
        endTime: 1700000060000,
        backgroundColor: '#FF0000',
        backgroundBottomColor: '#CC0000'
      }
    ];
  },

  getHighlights: function(roomId) {
    return [
      {
        id: 'hl_1',
        title: '五杀时刻',
        cover: 'http://example.com/hl1.png',
        duration: '01:30',
        url: 'http://example.com/hl/1',
        tag: '精彩切片',
        viewCount: '10000',
        danmuCount: '500',
        description: '高能团战',
        likeCount: 999
      }
    ];
  },

  getReplays: function(roomId, page) {
    return {
      hasMore: false,
      items: [
        {
          id: 'rp_1',
          title: '2026-08-30 录播回放',
          cover: 'http://example.com/rp1.png',
          duration: '02:30:00',
          playUrl: 'http://replay.example.com/1.mp4',
          tag: '直播录播',
          viewCount: '5000',
          danmuCount: '300'
        }
      ]
    };
  },

  getReplayPlayUrls: function(item) {
    return {
      urls: [item.playUrl],
      headers: { 'Referer': 'http://example.com' }
    };
  }
});
''';

    setUp(() async {
      final manifest = LivePluginManifest(
        id: 'site_mock_full',
        name: 'Mock Full JS Site',
        version: '1.0.0',
        type: LivePluginType.js,
      );
      dynamicSite = await PluginManagerCore.loadPlugin(
        manifest: manifest,
        content: fullJsPluginCode,
      );
    });

    tearDown(() {
      dynamicSite.dispose();
    });

    test('getCategores 测试', () async {
      final categories = await dynamicSite.getCategores();
      expect(categories.length, 2);
      expect(categories[0].id, 'game');
      expect(categories[0].name, '游戏');
      expect(categories[0].children.length, 2);
      expect(categories[0].children[0].name, '英雄联盟');
    });

    test('getRecommendRooms 测试', () async {
      final res = await dynamicSite.getRecommendRooms(page: 1);
      expect(res.hasMore, true);
      expect(res.items.length, 2);
      expect(res.items[0].roomId, '1001');
      expect(res.items[0].title, '推荐房间1');
    });

    test('getCategoryRooms 测试', () async {
      final subCat = LiveSubCategory(id: 'lol', name: '英雄联盟', parentId: 'game');
      final res = await dynamicSite.getCategoryRooms(subCat, page: 1);
      expect(res.items.length, 1);
      expect(res.items[0].title, '英雄联盟的房间');
    });

    test('searchRooms 与 searchAnchors 测试', () async {
      final roomRes = await dynamicSite.searchRooms('王者');
      expect(roomRes.items.length, 1);
      expect(roomRes.items[0].title, '搜索到: 王者');

      final anchorRes = await dynamicSite.searchAnchors('张三');
      expect(anchorRes.items.length, 1);
      expect(anchorRes.items[0].userName, '主播_张三');
      expect(anchorRes.items[0].liveStatus, true);
    });

    test('getRoomDetail、getPlayQualities 与 getPlayUrls 测试', () async {
      final detail = await dynamicSite.getRoomDetail(roomId: '88888');
      expect(detail.roomId, '88888');
      expect(detail.title, '直播间 88888');
      expect(detail.userName, '测试主播');
      expect(detail.status, true);
      expect(detail.introduction, '房间简介文本');
      expect(detail.notice, '主播公告文本');

      final qualities = await dynamicSite.getPlayQualites(detail: detail);
      expect(qualities.length, 2);
      expect(qualities[0].quality, '原画 1080P');

      final playUrl = await dynamicSite.getPlayUrls(detail: detail, quality: qualities[0]);
      expect(playUrl.urls.length, 2);
      expect(playUrl.urls[0], contains('88888_1080p.flv'));
      expect(playUrl.headers?['Referer'], 'http://example.com');
    });

    test('getLiveStatus、SC、看点及录播回放测试', () async {
      expect(await dynamicSite.getLiveStatus(roomId: '88888'), true);
      expect(await dynamicSite.getLiveStatus(roomId: 'offline_room'), false);

      final scList = await dynamicSite.getSuperChatMessage(roomId: '88888');
      expect(scList.length, 1);
      expect(scList[0].userName, '粉丝1号');
      expect(scList[0].price, 100);

      final hlList = await dynamicSite.getHighlights(roomId: '88888');
      expect(hlList.length, 1);
      expect(hlList[0].title, '五杀时刻');

      final replayRes = await dynamicSite.getReplays(roomId: '88888');
      expect(replayRes.items.length, 1);
      expect(replayRes.items[0].title, contains('录播回放'));

      final replayUrl = await dynamicSite.getReplayPlayUrls(item: replayRes.items[0]);
      expect(replayUrl.urls.first, 'http://replay.example.com/1.mp4');
    });
  });

  group('3. DslPluginEngine 规则解析测试用例', () {
    test('DSL 静态清晰度与属性提取', () async {
      final manifest = LivePluginManifest(
        id: 'site_dsl_test',
        name: 'DSL Test Site',
        version: '1.0.0',
        type: LivePluginType.dsl,
      );

      final dslConfig = {
        'playQualities': [
          {'quality': '超清 1080P', 'data': '1080p', 'sort': 1},
          {'quality': '高清 720P', 'data': '720p', 'sort': 2}
        ]
      };

      final dynamicSite = await PluginManagerCore.loadPlugin(
        manifest: manifest,
        content: jsonEncode(dslConfig),
      );

      final dummyDetail = LiveRoomDetail(
        roomId: '1000',
        title: 'Title',
        cover: '',
        userName: 'User',
        userAvatar: '',
        online: 10,
        status: true,
        url: '',
      );

      final qualities = await dynamicSite.getPlayQualites(detail: dummyDetail);
      expect(qualities.length, 2);
      expect(qualities[0].quality, '超清 1080P');
      expect(qualities[0].data, '1080p');

      dynamicSite.dispose();
    });
  });
}
