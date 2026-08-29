import 'dart:async';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_core/simple_live_core.dart';

class MultiViewItemController {
  final int index;
  final Function(int index)? onFocusRequested;

  MultiViewItemController({
    required this.index,
    this.onFocusRequested,
  });

  Site? site;
  String? roomId;

  late final Player player = Player(
    configuration: PlayerConfiguration(
      title: "MultiView-$index",
      logLevel: MPVLogLevel.error,
    ),
  );

  late final VideoController videoController = VideoController(
    player,
    configuration: AppSettingsController.instance.customPlayerOutput.value
        ? VideoControllerConfiguration(
            vo: AppSettingsController.instance.videoOutputDriver.value,
            hwdec: AppSettingsController.instance.videoHardwareDecoder.value,
          )
        : AppSettingsController.instance.playerCompatMode.value
            ? const VideoControllerConfiguration(
                vo: 'mediacodec_embed',
                hwdec: 'mediacodec',
              )
            : VideoControllerConfiguration(
                enableHardwareAcceleration:
                    AppSettingsController.instance.hardwareDecode.value,
                androidAttachSurfaceAfterVideoParameters: false,
              ),
  );

  LiveDanmaku? liveDanmaku;
  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);

  final RxBool hasRoom = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isError = false.obs;
  final RxString errorMsg = "".obs;

  final RxDouble volume = 100.0.obs;
  final RxBool isMuted = false.obs;
  final RxBool showDanmaku = false.obs;

  final RxList<LivePlayQuality> qualities = <LivePlayQuality>[].obs;
  final RxInt currentQualityIndex = (-1).obs;
  final RxList<String> playUrls = <String>[].obs;

  final RxList<LiveMessage> messages = <LiveMessage>[].obs;

  /// 初始化并加载直播间
  Future<void> loadRoom(Site site, String roomId) async {
    this.site = site;
    this.roomId = roomId;
    hasRoom.value = true;
    isLoading.value = true;
    isError.value = false;
    errorMsg.value = "";
    messages.clear();

    await stop();

    try {
      var roomDetail = await site.liveSite.getRoomDetail(roomId: roomId);
      detail.value = roomDetail;

      if (!roomDetail.status && !roomDetail.isRecord) {
        isLoading.value = false;
        isError.value = true;
        errorMsg.value = "当前主播未开播";
        return;
      }

      // 获取清晰度与播放地址
      qualities.value = await site.liveSite.getPlayQualites(detail: roomDetail);
      if (qualities.isEmpty) {
        isLoading.value = false;
        isError.value = true;
        errorMsg.value = "获取播放地址失败";
        return;
      }

      // 默认选择第一个或最高清晰度
      currentQualityIndex.value = 0;
      await _playCurrentQuality();

      // 初始化并连接弹幕
      _startDanmaku(roomDetail.danmakuData);

      isLoading.value = false;
    } catch (e) {
      Log.e("MultiView item $index 加载失败: $e", StackTrace.current);
      isLoading.value = false;
      isError.value = true;
      errorMsg.value = "加载失败: $e";
    }
  }

  Future<void> _playCurrentQuality() async {
    if (qualities.isEmpty) return;
    try {
      var quality = qualities[currentQualityIndex.value];
      var playUrl = await site!.liveSite.getPlayUrls(
        detail: detail.value!,
        quality: quality,
      );
      if (playUrl.urls.isEmpty) {
        isError.value = true;
        errorMsg.value = "无可用播放流";
        return;
      }
      playUrls.value = playUrl.urls;

      String url = playUrls.first;
      var headers = playUrl.headers;

      await player.open(
        Media(
          url,
          httpHeaders: headers,
        ),
        play: true,
      );

      // 同步音量设置
      player.setVolume(isMuted.value ? 0 : volume.value);
    } catch (e) {
      Log.e("MultiView item $index 播放失败: $e", StackTrace.current);
      isError.value = true;
      errorMsg.value = "播放失败: $e";
    }
  }

  void switchQuality(int qIndex) async {
    if (qIndex < 0 || qIndex >= qualities.length) return;
    currentQualityIndex.value = qIndex;
    isLoading.value = true;
    await _playCurrentQuality();
    isLoading.value = false;
  }

  void _startDanmaku(dynamic danmakuData) {
    try {
      liveDanmaku?.stop();
      liveDanmaku = site?.liveSite.getDanmaku();
      if (liveDanmaku == null) return;

      liveDanmaku!.onMessage = (msg) {
        if (msg.type == LiveMessageType.chat) {
          if (messages.length > 50) {
            messages.removeAt(0);
          }
          messages.add(msg);
        }
      };

      liveDanmaku!.start(danmakuData);
    } catch (e) {
      Log.e("MultiView item $index 弹幕启动失败: $e", StackTrace.current);
    }
  }

  void setVolume(double val) {
    volume.value = val;
    if (val > 0 && isMuted.value) {
      isMuted.value = false;
    }
    player.setVolume(isMuted.value ? 0 : val);
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    player.setVolume(isMuted.value ? 0 : volume.value);
  }

  void mute(bool mute) {
    isMuted.value = mute;
    player.setVolume(mute ? 0 : volume.value);
  }

  Future<void> refreshStream() async {
    if (site != null && roomId != null) {
      await loadRoom(site!, roomId!);
    }
  }

  Future<void> stop() async {
    try {
      await player.stop();
    } catch (_) {}
    try {
      await liveDanmaku?.stop();
    } catch (_) {}
  }

  void clearRoom() {
    stop();
    site = null;
    roomId = null;
    hasRoom.value = false;
    detail.value = null;
    qualities.clear();
    playUrls.clear();
    messages.clear();
    isError.value = false;
    errorMsg.value = "";
  }

  void dispose() {
    stop();
    player.dispose();
  }
}
