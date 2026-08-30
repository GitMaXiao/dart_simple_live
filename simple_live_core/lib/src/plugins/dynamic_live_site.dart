import '../interface/live_danmaku.dart';
import '../interface/live_site.dart';
import '../model/live_category.dart';
import '../model/live_category_result.dart';
import '../model/live_highlight_item.dart';
import '../model/live_message.dart';
import '../model/live_play_quality.dart';
import '../model/live_play_url.dart';
import '../model/live_replay_item.dart';
import '../model/live_room_detail.dart';
import '../model/live_search_result.dart';
import 'dynamic_live_danmaku.dart';
import 'live_plugin_manifest.dart';
import 'plugin_runtime_engine.dart';

/// 动态站点适配器，将插件引擎包装为标准 LiveSite 实例
class DynamicLiveSite extends LiveSite {
  final LivePluginManifest manifest;
  final PluginRuntimeEngine engine;
  final LiveDanmaku? customDanmaku;

  DynamicLiveSite({
    required this.manifest,
    required this.engine,
    this.customDanmaku,
  }) {
    id = manifest.id;
    name = manifest.name;
  }

  @override
  LiveDanmaku getDanmaku() => customDanmaku ?? DynamicLiveDanmaku();

  @override
  Future<List<LiveCategory>> getCategores() {
    return engine.getCategories();
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) {
    return engine.searchRooms(keyword, page: page);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) {
    return engine.searchAnchors(keyword, page: page);
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category, {int page = 1}) {
    return engine.getCategoryRooms(category, page: page);
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) {
    return engine.getRecommendRooms(page: page);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) {
    return engine.getRoomDetail(roomId: roomId);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoomDetail detail}) {
    return engine.getPlayQualities(detail: detail);
  }

  @override
  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  }) {
    return engine.getPlayUrls(detail: detail, quality: quality);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) {
    return engine.getLiveStatus(roomId: roomId);
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    return engine.getSuperChatMessage(roomId: roomId);
  }

  @override
  Future<List<LiveHighlightItem>> getHighlights({required String roomId}) {
    return engine.getHighlights(roomId: roomId);
  }

  @override
  Future<LiveReplayResult> getReplays({required String roomId, int page = 1}) {
    return engine.getReplays(roomId: roomId, page: page);
  }

  @override
  Future<LivePlayUrl> getReplayPlayUrls({required LiveReplayItem item}) {
    return engine.getReplayPlayUrls(item: item);
  }

  void dispose() {
    engine.dispose();
  }
}

