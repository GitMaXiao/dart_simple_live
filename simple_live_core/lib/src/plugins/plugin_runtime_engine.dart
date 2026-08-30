import '../model/live_category.dart';
import '../model/live_category_result.dart';
import '../model/live_highlight_item.dart';
import '../model/live_message.dart';
import '../model/live_play_quality.dart';
import '../model/live_play_url.dart';
import '../model/live_replay_item.dart';
import '../model/live_room_detail.dart';
import '../model/live_search_result.dart';
import 'live_plugin_manifest.dart';

abstract class PluginRuntimeEngine {
  final LivePluginManifest manifest;
  bool isInitialized = false;

  PluginRuntimeEngine(this.manifest);

  Future<void> init(String content);

  Future<List<LiveCategory>> getCategories();

  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1});

  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1});

  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category, {int page = 1});

  Future<LiveCategoryResult> getRecommendRooms({int page = 1});

  Future<LiveRoomDetail> getRoomDetail({required String roomId});

  Future<List<LivePlayQuality>> getPlayQualities({required LiveRoomDetail detail});

  Future<LivePlayUrl> getPlayUrls({
    required LiveRoomDetail detail,
    required LivePlayQuality quality,
  });

  Future<bool> getLiveStatus({required String roomId});

  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId});

  Future<List<LiveHighlightItem>> getHighlights({required String roomId});

  Future<LiveReplayResult> getReplays({required String roomId, int page = 1});

  Future<LivePlayUrl> getReplayPlayUrls({required LiveReplayItem item});

  void dispose();
}

