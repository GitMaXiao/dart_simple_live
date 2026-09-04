import 'dart:async';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class MultiViewItemController {
  final int index;
  final Function(int index)? onFocusRequested;
  final VoidCallback? onPlaybackStateChanged;

  MultiViewItemController({
    required this.index,
    this.onFocusRequested,
    this.onPlaybackStateChanged,
  }) {
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (player.platform is NativePlayer) {
        var pp = player.platform as NativePlayer;
        if (AppSettingsController.instance.customPlayerOutput.value) {
          await pp.setProperty(
            'ao',
            AppSettingsController.instance.audioOutputDriver.value,
          );
        }
        await pp.setProperty('force-seekable', 'no');
        int bufferBytes =
            AppSettingsController.instance.playerBufferSize.value * 1024 * 1024;
        await pp.setProperty('demuxer-max-bytes', bufferBytes.toString());
        await pp.setProperty('demuxer-max-back-bytes', '0');
        await pp.setProperty('demuxer-readahead-secs', '10');
      }
    } catch (e) {
      Log.e("MultiView item $index 初始化播放参数失败: $e", StackTrace.current);
    }
  }

  Site? site;
  String? roomId;

  DanmakuController? danmakuController;
  final RxBool showDanmaku = true.obs;

  void initDanmakuController(DanmakuController c) {
    danmakuController = c;
  }

  void toggleDanmaku() {
    showDanmaku.value = !showDanmaku.value;
  }

  late final Player player = Player(
    configuration: PlayerConfiguration(
      title: "MultiView-$index",
      bufferSize:
          AppSettingsController.instance.playerBufferSize.value * 1024 * 1024,
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
  final RxBool isPlaybackSuspended = false.obs;
  final RxBool isPreviewQuality = false.obs;

  final RxList<LivePlayQuality> qualities = <LivePlayQuality>[].obs;
  final RxInt currentQualityIndex = (-1).obs;
  final RxList<String> playUrls = <String>[].obs;
  int _preferredQualityIndex = 0;
  int _policyVersion = 0;

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
      _preferredQualityIndex = 0;
      await _playCurrentQuality();

      // 初始化并连接弹幕
      _startDanmaku(roomDetail.danmakuData);

      isLoading.value = false;
    } catch (e) {
      Log.e("MultiView item $index 加载失败: $e", StackTrace.current);
      isLoading.value = false;
      isError.value = true;
      errorMsg.value = "加载失败: $e";
    } finally {
      onPlaybackStateChanged?.call();
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

  Future<void> switchQuality(
    int qIndex, {
    bool updatePreferredQuality = true,
  }) async {
    if (qIndex < 0 || qIndex >= qualities.length) return;
    currentQualityIndex.value = qIndex;
    if (updatePreferredQuality) {
      _preferredQualityIndex = qIndex;
    }
    isLoading.value = true;
    await _playCurrentQuality();
    isLoading.value = false;
    onPlaybackStateChanged?.call();
  }

  Future<void> applyPlaybackPolicy({
    required bool shouldDecode,
    required bool isPrimary,
  }) async {
    final version = ++_policyVersion;
    mute(!isPrimary);
    if (!hasRoom.value) return;

    try {
      if (!shouldDecode) {
        if (!isPlaybackSuspended.value) {
          await player.pause();
          if (version == _policyVersion) {
            isPlaybackSuspended.value = true;
          }
        }
        return;
      }

      if (isPlaybackSuspended.value) {
        await player.play();
        if (version != _policyVersion) return;
        isPlaybackSuspended.value = false;
      }

      if (isPrimary) {
        if (isPreviewQuality.value &&
            _preferredQualityIndex != currentQualityIndex.value) {
          await switchQuality(
            _preferredQualityIndex,
            updatePreferredQuality: false,
          );
        }
        isPreviewQuality.value = false;
      } else {
        final lowQualityIndex = _getLowestQualityIndex();
        if (lowQualityIndex >= 0 &&
            lowQualityIndex != currentQualityIndex.value) {
          await switchQuality(
            lowQualityIndex,
            updatePreferredQuality: false,
          );
        }
        if (version == _policyVersion) {
          isPreviewQuality.value = lowQualityIndex >= 0;
        }
      }
    } catch (e) {
      Log.e("MultiView item $index policy update failed: $e", StackTrace.current);
    }
  }

  int _getLowestQualityIndex() {
    if (qualities.isEmpty) return -1;
    var candidate = 0;
    for (var i = 1; i < qualities.length; i++) {
      final item = qualities[i];
      final selected = qualities[candidate];
      if (item.sort < selected.sort ||
          (item.sort == selected.sort && i > candidate)) {
        candidate = i;
      }
    }
    return candidate;
  }

  final RxBool danmakuConnected = false.obs;
  final RxBool danmakuConnecting = false.obs;

  void _startDanmaku(dynamic danmakuData) {
    try {
      liveDanmaku?.stop();
      liveDanmaku = site?.liveSite.getDanmaku();
      if (liveDanmaku == null) return;

      danmakuConnecting.value = true;
      danmakuConnected.value = false;

      liveDanmaku!.onMessage = (msg) {
        if (msg.type == LiveMessageType.chat) {
          if (messages.length > 50) {
            messages.removeAt(0);
          }
          messages.add(msg);
          Color color = Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b);
          if (Get.isRegistered<MultiViewController>()) {
            Get.find<MultiViewController>().dispatchDanmaku(index, msg.message, color);
          }
        }
      };

      liveDanmaku!.onReady = () {
        danmakuConnected.value = true;
        danmakuConnecting.value = false;
      };

      liveDanmaku!.onClose = (msg) {
        danmakuConnected.value = false;
        danmakuConnecting.value = false;
      };

      liveDanmaku!.start(danmakuData);
    } catch (e) {
      danmakuConnecting.value = false;
      danmakuConnected.value = false;
      Log.e("MultiView item $index 弹幕启动失败: $e", StackTrace.current);
    }
  }

  Future<void> reconnectDanmaku() async {
    if (site == null || roomId == null) return;
    danmakuConnecting.value = true;
    try {
      await liveDanmaku?.stop();
      var danmakuData = detail.value?.danmakuData;
      if (danmakuData == null) {
        var newDetail = await site!.liveSite.getRoomDetail(roomId: roomId!);
        detail.value = newDetail;
        danmakuData = newDetail.danmakuData;
      }
      _startDanmaku(danmakuData);
      Log.d("MultiView item $index 已发起弹幕重连");
    } catch (e) {
      danmakuConnecting.value = false;
      danmakuConnected.value = false;
      Log.e("MultiView item $index 弹幕重连失败: $e", StackTrace.current);
    }
  }

  void setVolume(double val) {
    volume.value = val;
    if (val > 0 && isMuted.value) {
      isMuted.value = false;
    }
    player.setVolume(isMuted.value ? 0 : val);
    onPlaybackStateChanged?.call();
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    player.setVolume(isMuted.value ? 0 : volume.value);
    onPlaybackStateChanged?.call();
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
    danmakuController?.clear();
    site = null;
    roomId = null;
    hasRoom.value = false;
    detail.value = null;
    qualities.clear();
    playUrls.clear();
    messages.clear();
    isError.value = false;
    errorMsg.value = "";
    isPlaybackSuspended.value = false;
    isPreviewQuality.value = false;
    onPlaybackStateChanged?.call();
  }

  void dispose() {
    stop();
    danmakuController?.clear();
    player.dispose();
  }
}
