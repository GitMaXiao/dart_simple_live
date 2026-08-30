import 'dart:convert';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('LivePluginManifest Tests', () {
    test('Manifest serialization and deserialization', () {
      final jsonMap = {
        'id': 'test_plugin',
        'name': '测试插件',
        'version': '1.0.0',
        'type': 'js',
        'author': 'Tester',
        'description': 'Plugin description',
        'entry': 'index.js',
        'permissions': ['network', 'storage'],
      };

      final manifest = LivePluginManifest.fromJson(jsonMap);
      expect(manifest.id, 'test_plugin');
      expect(manifest.name, '测试插件');
      expect(manifest.type, LivePluginType.js);
      expect(manifest.permissions.length, 2);

      final encoded = manifest.toJson();
      expect(encoded['id'], 'test_plugin');
      expect(encoded['type'], 'js');
    });
  });

  group('JsPluginEngine & DynamicLiveSite Tests', () {
    test('JS Plugin execution and standard host bridge', () async {
      final manifest = LivePluginManifest(
        id: 'mock_js_site',
        name: 'Mock JS Site',
        version: '1.0.0',
        type: LivePluginType.js,
      );

      const jsCode = r'''
SimpleLive.registerSite({
  id: 'mock_js_site',
  name: 'Mock JS Site',

  getCategories: function() {
    return [
      {
        id: 'game',
        name: '游戏',
        children: [
          { id: 'lol', name: '英雄联盟', pic: 'http://example.com/lol.png' }
        ]
      }
    ];
  },

  getRoomDetail: function(roomId) {
    return {
      roomId: roomId,
      title: 'JS Test Room ' + roomId,
      userName: 'JS Streamer',
      userAvatar: 'http://example.com/avatar.png',
      cover: 'http://example.com/cover.png',
      online: 12345,
      status: true,
      url: 'http://example.com/room/' + roomId
    };
  },

  getPlayQualities: function(detail) {
    return [
      { quality: '原画 1080P', data: '1080p' },
      { quality: '高清 720P', data: '720p' }
    ];
  },

  getPlayUrls: function(detail, quality) {
    var sign = 'signed_' + detail.roomId + '_' + quality.data;
    return {
      urls: [
        'http://stream.example.com/' + detail.roomId + '_' + quality.data + '.m3u8?sign=' + sign
      ],
      headers: {
        'Referer': 'http://example.com'
      }
    };
  },

  getLiveStatus: function(roomId) {
    return true;
  }
});
''';

      final dynamicSite = await PluginManagerCore.loadPlugin(
        manifest: manifest,
        content: jsCode,
      );

      expect(dynamicSite.id, 'mock_js_site');
      expect(dynamicSite.name, 'Mock JS Site');

      // Test getCategores
      final categories = await dynamicSite.getCategores();
      expect(categories.length, 1);
      expect(categories.first.id, 'game');
      expect(categories.first.name, '游戏');
      expect(categories.first.children.length, 1);
      expect(categories.first.children.first.name, '英雄联盟');

      // Test getRoomDetail
      final detail = await dynamicSite.getRoomDetail(roomId: '88888');
      expect(detail.roomId, '88888');
      expect(detail.title, 'JS Test Room 88888');
      expect(detail.userName, 'JS Streamer');
      expect(detail.online, 12345);
      expect(detail.status, true);

      // Test getPlayQualites
      final qualities = await dynamicSite.getPlayQualites(detail: detail);
      expect(qualities.length, 2);
      expect(qualities.first.quality, '原画 1080P');

      // Test getPlayUrls
      final playUrls = await dynamicSite.getPlayUrls(
        detail: detail,
        quality: qualities.first,
      );
      expect(playUrls.urls.length, 1);
      expect(playUrls.urls.first, contains('88888_1080p.m3u8'));
      expect(playUrls.headers?['Referer'], 'http://example.com');

      // Test getLiveStatus
      final isLiving = await dynamicSite.getLiveStatus(roomId: '88888');
      expect(isLiving, true);

      dynamicSite.dispose();
    });
  });

  group('DslPluginEngine Tests', () {
    test('DSL rule static parsing', () async {
      final manifest = LivePluginManifest(
        id: 'mock_dsl_site',
        name: 'Mock DSL Site',
        version: '1.0.0',
        type: LivePluginType.dsl,
      );

      final dslJson = {
        'playQualities': [
          {'quality': '原画', 'data': 'origin'},
          {'quality': '高清', 'data': '720p'}
        ]
      };

      final dynamicSite = await PluginManagerCore.loadPlugin(
        manifest: manifest,
        content: jsonEncode(dslJson),
      );

      final detail = LiveRoomDetail(
        roomId: '123',
        title: 'Title',
        cover: '',
        userName: 'User',
        userAvatar: '',
        online: 100,
        status: true,
        url: '',
      );

      final qualities = await dynamicSite.getPlayQualites(detail: detail);
      expect(qualities.length, 2);
      expect(qualities[0].quality, '原画');
      expect(qualities[1].quality, '高清');

      dynamicSite.dispose();
    });
  });
}

