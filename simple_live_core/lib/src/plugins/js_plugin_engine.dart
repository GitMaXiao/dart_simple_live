import 'dart:convert';
import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:dio/dio.dart';
import '../common/core_log.dart';
import '../common/http_client.dart';
import '../model/live_anchor_item.dart';
import '../model/live_category.dart';
import '../model/live_category_result.dart';
import '../model/live_highlight_item.dart';
import '../model/live_message.dart';
import '../model/live_play_quality.dart';
import '../model/live_play_url.dart';
import '../model/live_replay_item.dart';
import '../model/live_room_detail.dart';
import '../model/live_room_item.dart';
import '../model/live_search_result.dart';
import 'plugin_runtime_engine.dart';

/// 基于 QuickJS 的 JavaScript 脚本沙箱引擎
class JsPluginEngine extends PluginRuntimeEngine {
  JsRuntime? _runtime;
  String _pluginId = '';

  JsPluginEngine(super.manifest);

  static const String _hostBootstrapJs = r'''
var SimpleLive = {
  _sites: {},
  registerSite: function(site) {
    if (site && site.id) {
      SimpleLive._sites[site.id] = site;
      globalThis.__currentSite = site;
    }
  },
  regex: {
    find: function(str, pattern, groupIndex) {
      try {
        var re = new RegExp(pattern);
        var match = re.exec(str);
        if (!match) return null;
        return match[groupIndex || 1] || match[0];
      } catch (e) {
        return null;
      }
    }
  }
};
''';

  @override
  Future<void> init(String content) async {
    _pluginId = manifest.id;
    _runtime = JsRuntime(
      memoryLimit: 16 * 1024 * 1024,
      maxStackSize: 256 * 1024,
    );

    // 注入基础全局环境与 SimpleLive 命名空间
    _runtime!.eval(_hostBootstrapJs, filename: 'bootstrap.js');

    // 执行插件脚本
    _runtime!.eval(content, filename: manifest.entry);
    isInitialized = true;
  }

  /// 在 JS 环境中执行指定方法，并支持 HTTP 异步调度协议
  Future<dynamic> _invokeSiteMethod(String methodName, List<dynamic> args) async {
    if (_runtime == null || _runtime!.isDisposed) {
      throw StateError('JsPluginEngine runtime is disposed or not initialized');
    }

    var argsJson = jsonEncode(args);
    var runnerJs = '''
(function() {
  var site = globalThis.__currentSite || (SimpleLive._sites['$_pluginId']);
  if (!site) {
    throw new Error('Plugin site with id "$_pluginId" not registered');
  }
  var fn = site['$methodName'];
  if (typeof fn !== 'function') {
    return null;
  }
  var args = $argsJson;
  return fn.apply(site, args);
})()
''';

    var result = _runtime!.eval(runnerJs);

    // 如果 JS 返回的是一个 HTTP 请求指令描述对象，则在 Dart 端执行网络请求并将结果再回调 JS
    if (result is Map && result['__type'] == 'http_request') {
      return await _handleHttpRequestInstruction(result, methodName);
    }

    return result;
  }

  /// 处理 JS 触发的 HTTP 请求流转指令
  Future<dynamic> _handleHttpRequestInstruction(Map requestMap, String originalMethod) async {
    var url = requestMap['url']?.toString() ?? '';
    var method = (requestMap['method']?.toString() ?? 'GET').toUpperCase();
    var headers = requestMap['headers'] is Map ? Map<String, dynamic>.from(requestMap['headers']) : null;
    var params = requestMap['params'] is Map ? Map<String, dynamic>.from(requestMap['params']) : null;
    var data = requestMap['body'] ?? requestMap['data'];
    var nextCallback = requestMap['callback']?.toString();

    var options = Options(
      method: method,
      headers: headers,
      responseType: ResponseType.plain,
    );

    Response resp;
    try {
      if (method == 'POST') {
        resp = await HttpClient.instance.dio.post(url, data: data, queryParameters: params, options: options);
      } else {
        resp = await HttpClient.instance.dio.get(url, queryParameters: params, options: options);
      }
    } catch (e) {
      CoreLog.error('Plugin $_pluginId HTTP request failed: $e');
      rethrow;
    }

    var respBody = resp.data.toString();

    // 如果定义了后续解析回调函数，则将 response 传递回 JS 进行下一步解析
    if (nextCallback != null && nextCallback.isNotEmpty) {
      var callbackCode = '''
(function() {
  var site = globalThis.__currentSite || (SimpleLive._sites['$_pluginId']);
  var cb = site['$nextCallback'];
  if (typeof cb === 'function') {
    return cb.call(site, ${jsonEncode(respBody)}, ${resp.statusCode});
  }
  return null;
})()
''';
      return _runtime!.eval(callbackCode);
    }

    return respBody;
  }

  @override
  Future<List<LiveCategory>> getCategories() async {
    var raw = await _invokeSiteMethod('getCategories', []);
    if (raw is! List) return [];

    List<LiveCategory> categories = [];
    for (var cat in raw) {
      if (cat is! Map) continue;
      var catId = cat['id']?.toString() ?? '';
      var catName = cat['name']?.toString() ?? '';

      List<LiveSubCategory> subList = [];
      if (cat['children'] is List) {
        for (var sub in cat['children']) {
          if (sub is! Map) continue;
          subList.add(LiveSubCategory(
            id: sub['id']?.toString() ?? '',
            name: sub['name']?.toString() ?? '',
            parentId: catId,
            pic: sub['pic']?.toString(),
          ));
        }
      }

      categories.add(LiveCategory(
        id: catId,
        name: catName,
        children: subList,
      ));
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var raw = await _invokeSiteMethod('getRecommendRooms', [page]);
    return _parseCategoryResult(raw);
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category, {int page = 1}) async {
    var catMap = {
      'id': category.id,
      'name': category.name,
      'parentId': category.parentId,
      'pic': category.pic,
    };
    var raw = await _invokeSiteMethod('getCategoryRooms', [catMap, page]);
    return _parseCategoryResult(raw);
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    var raw = await _invokeSiteMethod('searchRooms', [keyword, page]);
    var catResult = _parseCategoryResult(raw);
    return LiveSearchRoomResult(hasMore: catResult.hasMore, items: catResult.items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) async {
    var raw = await _invokeSiteMethod('searchAnchors', [keyword, page]);
    if (raw is! Map) {
      return LiveSearchAnchorResult(hasMore: false, items: []);
    }

    var hasMore = raw['hasMore'] == true;
    List<LiveAnchorItem> items = [];
    if (raw['items'] is List) {
      for (var item in raw['items']) {
        if (item is! Map) continue;
        items.add(LiveAnchorItem(
          roomId: item['roomId']?.toString() ?? '',
          avatar: item['avatar']?.toString() ?? '',
          userName: item['userName']?.toString() ?? '',
          liveStatus: item['liveStatus'] == true,
        ));
      }
    }
    return LiveSearchAnchorResult(hasMore: hasMore, items: items);
  }

  LiveCategoryResult _parseCategoryResult(dynamic raw) {
    if (raw is! Map) {
      return LiveCategoryResult(hasMore: false, items: []);
    }

    var hasMore = raw['hasMore'] == true;
    List<LiveRoomItem> items = [];

    if (raw['items'] is List) {
      for (var item in raw['items']) {
        if (item is! Map) continue;
        items.add(LiveRoomItem(
          roomId: item['roomId']?.toString() ?? '',
          title: item['title']?.toString() ?? '',
          cover: item['cover']?.toString() ?? '',
          userName: item['userName']?.toString() ?? '',
          online: int.tryParse(item['online']?.toString() ?? '0') ?? 0,
        ));
      }
    }

    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    var raw = await _invokeSiteMethod('getRoomDetail', [roomId]);
    if (raw is! Map) {
      return LiveRoomDetail(
        roomId: roomId,
        title: '',
        cover: '',
        userName: '',
        userAvatar: '',
        online: 0,
        status: false,
        url: '',
      );
    }

    return LiveRoomDetail(
      roomId: raw['roomId']?.toString() ?? roomId,
      title: raw['title']?.toString() ?? '',
      cover: raw['cover']?.toString() ?? '',
      userName: raw['userName']?.toString() ?? '',
      userAvatar: raw['userAvatar']?.toString() ?? '',
      online: int.tryParse(raw['online']?.toString() ?? '0') ?? 0,
      status: raw['status'] == true,
      introduction: raw['introduction']?.toString(),
      notice: raw['notice']?.toString(),
      url: raw['url']?.toString() ?? '',
      data: raw['data'],
      danmakuData: raw['danmakuData'],
      isRecord: raw['isRecord'] == true,
      showTime: raw['showTime']?.toString(),
    );
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities({required LiveRoomDetail detail}) async {
    var detailMap = {
      'roomId': detail.roomId,
      'title': detail.title,
      'cover': detail.cover,
      'userName': detail.userName,
      'status': detail.status,
      'data': detail.data,
      'danmakuData': detail.danmakuData,
    };
    var raw = await _invokeSiteMethod('getPlayQualities', [detailMap]);
    if (raw is! List) return [];

    List<LivePlayQuality> qualities = [];
    for (var q in raw) {
      if (q is! Map) continue;
      qualities.add(LivePlayQuality(
        quality: q['quality']?.toString() ?? '默认',
        data: q['data'] ?? q['quality'],
        sort: int.tryParse(q['sort']?.toString() ?? '0') ?? 0,
      ));
    }
    return qualities;
  }

  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail, required LivePlayQuality quality}) async {
    var detailMap = {
      'roomId': detail.roomId,
      'title': detail.title,
      'cover': detail.cover,
      'userName': detail.userName,
      'status': detail.status,
      'data': detail.data,
      'danmakuData': detail.danmakuData,
    };
    var qualityMap = {
      'quality': quality.quality,
      'data': quality.data,
      'sort': quality.sort,
    };

    var raw = await _invokeSiteMethod('getPlayUrls', [detailMap, qualityMap]);
    if (raw is! Map) {
      return LivePlayUrl(urls: []);
    }

    List<String> urls = [];
    if (raw['urls'] is List) {
      urls = (raw['urls'] as List).map((e) => e.toString()).toList();
    }

    Map<String, String>? headers;
    if (raw['headers'] is Map) {
      headers = Map<String, String>.from(
        (raw['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }

    return LivePlayUrl(urls: urls, headers: headers);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var raw = await _invokeSiteMethod('getLiveStatus', [roomId]);
    if (raw is bool) return raw;
    var detail = await getRoomDetail(roomId: roomId);
    return detail.status;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    var raw = await _invokeSiteMethod('getSuperChatMessage', [roomId]);
    if (raw is! List) return [];
    List<LiveSuperChatMessage> list = [];
    for (var item in raw) {
      if (item is! Map) continue;
      var st = int.tryParse(item['startTime']?.toString() ?? '0') ?? 0;
      var et = int.tryParse(item['endTime']?.toString() ?? '0') ?? 0;
      list.add(LiveSuperChatMessage(
        backgroundBottomColor: item['backgroundBottomColor']?.toString() ?? '',
        backgroundColor: item['backgroundColor']?.toString() ?? '',
        endTime: DateTime.fromMillisecondsSinceEpoch(et > 0 ? et : DateTime.now().millisecondsSinceEpoch),
        face: item['face']?.toString() ?? '',
        message: item['message']?.toString() ?? '',
        price: int.tryParse(item['price']?.toString() ?? '0') ?? 0,
        startTime: DateTime.fromMillisecondsSinceEpoch(st > 0 ? st : DateTime.now().millisecondsSinceEpoch),
        userName: item['userName']?.toString() ?? '',
      ));
    }
    return list;
  }

  @override
  Future<List<LiveHighlightItem>> getHighlights({required String roomId}) async {
    var raw = await _invokeSiteMethod('getHighlights', [roomId]);
    if (raw is! List) return [];
    List<LiveHighlightItem> list = [];
    for (var item in raw) {
      if (item is! Map) continue;
      list.add(LiveHighlightItem(
        id: item['id']?.toString() ?? '',
        title: item['title']?.toString() ?? '',
        cover: item['cover']?.toString() ?? '',
        duration: item['duration']?.toString() ?? '00:00',
        url: item['url']?.toString() ?? '',
        tag: item['tag']?.toString() ?? 'AI看点',
        viewCount: item['viewCount']?.toString() ?? '0',
        danmuCount: item['danmuCount']?.toString() ?? '0',
        description: item['description']?.toString() ?? '',
        likeCount: int.tryParse(item['likeCount']?.toString() ?? '0') ?? 0,
      ));
    }
    return list;
  }

  @override
  Future<LiveReplayResult> getReplays({required String roomId, int page = 1}) async {
    var raw = await _invokeSiteMethod('getReplays', [roomId, page]);
    if (raw is! Map) return LiveReplayResult(hasMore: false, items: []);
    var hasMore = raw['hasMore'] == true;
    List<LiveReplayItem> items = [];
    if (raw['items'] is List) {
      for (var item in raw['items']) {
        if (item is! Map) continue;
        items.add(LiveReplayItem(
          id: item['id']?.toString() ?? '',
          title: item['title']?.toString() ?? '',
          cover: item['cover']?.toString() ?? '',
          duration: item['duration']?.toString() ?? '00:00',
          playUrl: item['playUrl']?.toString() ?? '',
          url: item['url']?.toString() ?? '',
          tag: item['tag']?.toString() ?? '直播录播',
          viewCount: item['viewCount']?.toString() ?? '0',
          danmuCount: item['danmuCount']?.toString() ?? '0',
          extra: item['extra'] is Map ? Map<String, dynamic>.from(item['extra']) : null,
        ));
      }
    }
    return LiveReplayResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LivePlayUrl> getReplayPlayUrls({required LiveReplayItem item}) async {
    var itemMap = {
      'id': item.id,
      'title': item.title,
      'cover': item.cover,
      'duration': item.duration,
      'playUrl': item.playUrl,
      'url': item.url,
      'tag': item.tag,
      'extra': item.extra,
    };
    var raw = await _invokeSiteMethod('getReplayPlayUrls', [itemMap]);
    if (raw is Map && raw['urls'] is List) {
      return LivePlayUrl(
        urls: (raw['urls'] as List).map((e) => e.toString()).toList(),
        headers: raw['headers'] is Map ? Map<String, String>.from(raw['headers']) : null,
      );
    }
    if (item.playUrl.isNotEmpty) {
      return LivePlayUrl(urls: [item.playUrl]);
    }
    return LivePlayUrl(urls: []);
  }

  @override
  void dispose() {
    _runtime?.dispose();
    _runtime = null;
  }
}

