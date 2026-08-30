import 'dart:convert';
import 'package:dio/dio.dart';
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

/// 声明式 DSL 规则引擎
class DslPluginEngine extends PluginRuntimeEngine {
  Map<String, dynamic> _rules = {};

  DslPluginEngine(super.manifest);

  @override
  Future<void> init(String content) async {
    try {
      _rules = jsonDecode(content) as Map<String, dynamic>;
      isInitialized = true;
    } catch (e) {
      throw FormatException('Failed to parse DSL rules JSON: $e');
    }
  }

  /// 字符串模板变量替换
  String _interpolate(String template, Map<String, dynamic> vars) {
    var result = template;
    vars.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value?.toString() ?? '');
    });
    return result;
  }

  /// 递归或路径式读取 Map/List 中的值
  /// 支持形如: "data.items", "data.user.name", "urls"
  dynamic _extractByPath(dynamic data, String? path) {
    if (path == null || path.isEmpty || path == '\$' || path == '.') {
      return data;
    }
    if (data == null) return null;

    var cleanedPath = path.startsWith('\$.') ? path.substring(2) : (path.startsWith('\$') ? path.substring(1) : path);
    if (cleanedPath.isEmpty) return data;

    var segments = cleanedPath.split('.');
    dynamic current = data;

    for (var seg in segments) {
      if (current == null) return null;

      // Check for array index notation, e.g. items[0]
      if (seg.contains('[') && seg.endsWith(']')) {
        var key = seg.substring(0, seg.indexOf('['));
        var indexStr = seg.substring(seg.indexOf('[') + 1, seg.length - 1);
        var index = int.tryParse(indexStr);

        if (key.isNotEmpty) {
          if (current is Map) {
            current = current[key];
          } else {
            return null;
          }
        }

        if (current is List && index != null && index >= 0 && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else {
        if (current is Map) {
          current = current[seg];
        } else {
          return null;
        }
      }
    }

    return current;
  }

  /// 发送 DSL 中定义的请求并返回解码后的数据（JSON 或 String）
  Future<dynamic> _executeRequest(Map<String, dynamic> rule, Map<String, dynamic> vars) async {
    var urlTemplate = rule['url']?.toString() ?? '';
    if (urlTemplate.isEmpty) return null;

    var url = _interpolate(urlTemplate, vars);
    var method = (rule['method']?.toString() ?? 'GET').toUpperCase();

    Map<String, dynamic> headers = {};
    if (rule['headers'] is Map) {
      (rule['headers'] as Map).forEach((k, v) {
        headers[k.toString()] = _interpolate(v.toString(), vars);
      });
    }

    Map<String, dynamic> queryParams = {};
    if (rule['params'] is Map) {
      (rule['params'] as Map).forEach((k, v) {
        queryParams[k.toString()] = _interpolate(v.toString(), vars);
      });
    }

    dynamic body;
    if (rule['body'] != null) {
      if (rule['body'] is String) {
        body = _interpolate(rule['body'], vars);
      } else if (rule['body'] is Map) {
        var bodyMap = <String, dynamic>{};
        (rule['body'] as Map).forEach((k, v) {
          bodyMap[k.toString()] = v is String ? _interpolate(v, vars) : v;
        });
        body = bodyMap;
      }
    }

    var options = Options(
      method: method,
      headers: headers.isEmpty ? null : headers,
      responseType: ResponseType.plain,
    );

    Response response;
    if (method == 'POST') {
      response = await HttpClient.instance.dio.post(url, data: body, queryParameters: queryParams, options: options);
    } else {
      response = await HttpClient.instance.dio.get(url, queryParameters: queryParams, options: options);
    }

    var resStr = response.data.toString();

    // 如果规则配置了 regex 抽取 JSON
    if (rule['regex'] != null) {
      var reg = RegExp(rule['regex'].toString(), dotAll: true);
      var match = reg.firstMatch(resStr);
      if (match != null && match.groupCount >= 1) {
        resStr = match.group(1) ?? resStr;
      }
    }

    try {
      return jsonDecode(resStr);
    } catch (_) {
      return resStr;
    }
  }

  @override
  Future<List<LiveCategory>> getCategories() async {
    var rule = _rules['categories'];
    if (rule is! Map<String, dynamic>) return [];

    var resp = await _executeRequest(rule, {});
    var mapping = rule['mapping'] as Map<String, dynamic>? ?? rule['jsonPath'] as Map<String, dynamic>? ?? {};

    var listData = _extractByPath(resp, mapping['list']?.toString() ?? 'data');
    if (listData is! List) return [];

    List<LiveCategory> categories = [];
    for (var item in listData) {
      if (item is! Map) continue;
      var catId = _extractByPath(item, mapping['id']?.toString() ?? 'id')?.toString() ?? '';
      var catName = _extractByPath(item, mapping['name']?.toString() ?? 'name')?.toString() ?? '';

      List<LiveSubCategory> subCategories = [];
      var childrenData = _extractByPath(item, mapping['children']?.toString() ?? 'children');
      if (childrenData is List) {
        for (var sub in childrenData) {
          if (sub is! Map) continue;
          var subId = _extractByPath(sub, mapping['childId']?.toString() ?? 'id')?.toString() ?? '';
          var subName = _extractByPath(sub, mapping['childName']?.toString() ?? 'name')?.toString() ?? '';
          var subPic = _extractByPath(sub, mapping['childPic']?.toString() ?? 'pic')?.toString();
          subCategories.add(LiveSubCategory(
            id: subId,
            name: subName,
            parentId: catId,
            pic: subPic,
          ));
        }
      }

      categories.add(LiveCategory(
        id: catId,
        name: catName,
        children: subCategories,
      ));
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var rule = _rules['recommendRooms'];
    if (rule is! Map<String, dynamic>) {
      return LiveCategoryResult(hasMore: false, items: []);
    }

    var resp = await _executeRequest(rule, {'page': page});
    return _parseRoomListResult(rule, resp);
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category, {int page = 1}) async {
    var rule = _rules['categoryRooms'];
    if (rule is! Map<String, dynamic>) {
      return LiveCategoryResult(hasMore: false, items: []);
    }

    var resp = await _executeRequest(rule, {
      'page': page,
      'categoryId': category.id,
      'categoryName': category.name,
      'parentId': category.parentId,
    });
    return _parseRoomListResult(rule, resp);
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    var rule = _rules['searchRooms'];
    if (rule is! Map<String, dynamic>) {
      return LiveSearchRoomResult(hasMore: false, items: []);
    }

    var resp = await _executeRequest(rule, {'keyword': keyword, 'page': page});
    var roomResult = _parseRoomListResult(rule, resp);
    return LiveSearchRoomResult(hasMore: roomResult.hasMore, items: roomResult.items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) async {
    var rule = _rules['searchAnchors'];
    if (rule is! Map<String, dynamic>) {
      return LiveSearchAnchorResult(hasMore: false, items: []);
    }

    var resp = await _executeRequest(rule, {'keyword': keyword, 'page': page});
    var mapping = rule['mapping'] as Map<String, dynamic>? ?? rule['jsonPath'] as Map<String, dynamic>? ?? {};

    var listData = _extractByPath(resp, mapping['list']?.toString() ?? 'data');
    if (listData is! List) {
      return LiveSearchAnchorResult(hasMore: false, items: []);
    }

    List<LiveAnchorItem> items = [];
    for (var item in listData) {
      if (item is! Map) continue;
      items.add(LiveAnchorItem(
        roomId: _extractByPath(item, mapping['roomId']?.toString() ?? 'roomId')?.toString() ?? '',
        avatar: _extractByPath(item, mapping['avatar']?.toString() ?? 'avatar')?.toString() ?? '',
        userName: _extractByPath(item, mapping['userName']?.toString() ?? 'userName')?.toString() ?? '',
        liveStatus: _extractByPath(item, mapping['liveStatus']?.toString() ?? 'liveStatus') == true,
      ));
    }

    var hasMore = _extractByPath(resp, mapping['hasMore']?.toString() ?? 'hasMore');
    return LiveSearchAnchorResult(hasMore: hasMore == true, items: items);
  }

  LiveCategoryResult _parseRoomListResult(Map<String, dynamic> rule, dynamic resp) {
    var mapping = rule['mapping'] as Map<String, dynamic>? ?? rule['jsonPath'] as Map<String, dynamic>? ?? {};
    var listData = _extractByPath(resp, mapping['list']?.toString() ?? 'data');
    if (listData is! List) {
      return LiveCategoryResult(hasMore: false, items: []);
    }

    List<LiveRoomItem> items = [];
    for (var item in listData) {
      if (item is! Map) continue;
      var roomId = _extractByPath(item, mapping['roomId']?.toString() ?? 'roomId')?.toString() ?? '';
      var title = _extractByPath(item, mapping['title']?.toString() ?? 'title')?.toString() ?? '';
      var cover = _extractByPath(item, mapping['cover']?.toString() ?? 'cover')?.toString() ?? '';
      var userName = _extractByPath(item, mapping['userName']?.toString() ?? 'userName')?.toString() ?? '';
      var onlineRaw = _extractByPath(item, mapping['online']?.toString() ?? 'online');
      var online = int.tryParse(onlineRaw?.toString() ?? '0') ?? 0;

      items.add(LiveRoomItem(
        roomId: roomId,
        title: title,
        cover: cover,
        userName: userName,
        online: online,
      ));
    }

    var hasMoreRaw = _extractByPath(resp, mapping['hasMore']?.toString() ?? 'hasMore');
    bool hasMore = hasMoreRaw == true || (hasMoreRaw != null && hasMoreRaw.toString() == '1') || items.isNotEmpty;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    var rule = _rules['roomDetail'];
    if (rule is! Map<String, dynamic>) {
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

    var resp = await _executeRequest(rule, {'roomId': roomId});
    var mapping = rule['mapping'] as Map<String, dynamic>? ?? rule['jsonPath'] as Map<String, dynamic>? ?? {};

    var title = _extractByPath(resp, mapping['title']?.toString() ?? 'title')?.toString() ?? '';
    var cover = _extractByPath(resp, mapping['cover']?.toString() ?? 'cover')?.toString() ?? '';
    var userName = _extractByPath(resp, mapping['userName']?.toString() ?? 'userName')?.toString() ?? '';
    var userAvatar = _extractByPath(resp, mapping['userAvatar']?.toString() ?? 'userAvatar')?.toString() ?? '';
    var statusRaw = _extractByPath(resp, mapping['status']?.toString() ?? 'status');
    var status = statusRaw == true || statusRaw.toString() == '1' || statusRaw.toString().toLowerCase() == 'live';
    var onlineRaw = _extractByPath(resp, mapping['online']?.toString() ?? 'online');
    var online = int.tryParse(onlineRaw?.toString() ?? '0') ?? 0;
    var intro = _extractByPath(resp, mapping['introduction']?.toString())?.toString();
    var notice = _extractByPath(resp, mapping['notice']?.toString())?.toString();
    var url = _extractByPath(resp, mapping['url']?.toString())?.toString() ?? '';

    return LiveRoomDetail(
      roomId: roomId,
      title: title,
      cover: cover,
      userName: userName,
      userAvatar: userAvatar,
      online: online,
      status: status,
      introduction: intro,
      notice: notice,
      url: url,
      data: resp,
    );
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities({required LiveRoomDetail detail}) async {
    var rule = _rules['playQualities'];
    if (rule == null) {
      // 默认提供原画
      return [LivePlayQuality(quality: '原画', data: 'origin')];
    }

    if (rule is List) {
      // 静态清晰度列表
      return rule.map((e) {
        var map = e as Map;
        return LivePlayQuality(
          quality: map['quality']?.toString() ?? '默认',
          data: map['data'] ?? map['quality'],
          sort: int.tryParse(map['sort']?.toString() ?? '0') ?? 0,
        );
      }).toList();
    }

    if (rule is Map<String, dynamic>) {
      var resp = await _executeRequest(rule, {'roomId': detail.roomId});
      var mapping = rule['mapping'] as Map<String, dynamic>? ?? rule['jsonPath'] as Map<String, dynamic>? ?? {};
      var listData = _extractByPath(resp, mapping['list']?.toString() ?? 'data');
      if (listData is! List) return [];

      return listData.map((e) {
        var qName = _extractByPath(e, mapping['quality']?.toString() ?? 'quality')?.toString() ?? '默认';
        var qData = _extractByPath(e, mapping['data']?.toString() ?? 'data') ?? qName;
        return LivePlayQuality(quality: qName, data: qData);
      }).toList();
    }

    return [];
  }

  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail, required LivePlayQuality quality}) async {
    var rule = _rules['playUrls'];
    if (rule is! Map<String, dynamic>) {
      return LivePlayUrl(urls: []);
    }

    var resp = await _executeRequest(rule, {
      'roomId': detail.roomId,
      'quality': quality.quality,
      'qualityData': quality.data?.toString() ?? '',
    });

    var mapping = rule['mapping'] as Map<String, dynamic>? ?? rule['jsonPath'] as Map<String, dynamic>? ?? {};
    var urlsData = _extractByPath(resp, mapping['urls']?.toString() ?? 'urls');

    List<String> urls = [];
    if (urlsData is List) {
      urls = urlsData.map((e) => e.toString()).toList();
    } else if (urlsData != null) {
      urls = [urlsData.toString()];
    }

    Map<String, String>? headers;
    if (rule['headers'] is Map) {
      headers = {};
      (rule['headers'] as Map).forEach((k, v) {
        headers![k.toString()] = _interpolate(v.toString(), {
          'roomId': detail.roomId,
        });
      });
    }

    return LivePlayUrl(urls: urls, headers: headers);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var rule = _rules['liveStatus'];
    if (rule is Map<String, dynamic>) {
      var resp = await _executeRequest(rule, {'roomId': roomId});
      var mapping = rule['mapping'] as Map<String, dynamic>? ?? rule['jsonPath'] as Map<String, dynamic>? ?? {};
      var statusRaw = _extractByPath(resp, mapping['status']?.toString() ?? 'status');
      return statusRaw == true || statusRaw.toString() == '1';
    }
    var detail = await getRoomDetail(roomId: roomId);
    return detail.status;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async => [];

  @override
  Future<List<LiveHighlightItem>> getHighlights({required String roomId}) async => [];

  @override
  Future<LiveReplayResult> getReplays({required String roomId, int page = 1}) async {
    return LiveReplayResult(hasMore: false, items: []);
  }

  @override
  Future<LivePlayUrl> getReplayPlayUrls({required LiveReplayItem item}) async {
    return LivePlayUrl(urls: item.playUrl.isNotEmpty ? [item.playUrl] : []);
  }

  @override
  void dispose() {
    _rules.clear();
  }
}

