import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_core/simple_live_core.dart';

String formatVODDuration(Duration d) {
  var minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  var seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    var hours = d.inHours.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

class VODProgressBar extends StatefulWidget {
  final LiveRoomController controller;
  const VODProgressBar({super.key, required this.controller});

  @override
  State<VODProgressBar> createState() => _VODProgressBarState();
}

class _VODProgressBarState extends State<VODProgressBar> {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = widget.controller.vodPosition.value;
      final dur = widget.controller.vodDuration.value;
      final maxDur =
          dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
      final currentPos =
          (_draggingValue ?? pos.inMilliseconds.toDouble()).clamp(0.0, maxDur);

      final displayPos = _draggingValue != null
          ? Duration(milliseconds: _draggingValue!.toInt())
          : pos;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              formatVODDuration(displayPos),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Theme.of(context).primaryColor,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: currentPos,
                  min: 0.0,
                  max: maxDur,
                  onChangeStart: (val) {
                    setState(() {
                      _draggingValue = val;
                    });
                  },
                  onChanged: (val) {
                    setState(() {
                      _draggingValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    widget.controller
                        .seekTo(Duration(milliseconds: val.toInt()));
                    setState(() {
                      _draggingValue = null;
                    });
                  },
                ),
              ),
            ),
            Text(
              formatVODDuration(dur),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    });
  }
}

Widget buildVODBottomBar(LiveRoomController controller, {bool isFull = false}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 进度条与时间显示
      VODProgressBar(controller: controller),
      // 控制按钮栏
      Row(
        children: [
          // 播放/暂停
          Obx(
            () => IconButton(
              onPressed: () {
                controller.togglePlayPause();
              },
              icon: Icon(
                controller.isPlaying.value ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
          // 快退 10 秒
          IconButton(
            onPressed: () {
              controller.seekBackward(10);
            },
            icon: const Icon(
              Remix.replay_10_line,
              color: Colors.white,
              size: 20,
            ),
          ),
          // 快进 10 秒
          IconButton(
            onPressed: () {
              controller.seekForward(10);
            },
            icon: const Icon(
              Remix.forward_10_line,
              color: Colors.white,
              size: 20,
            ),
          ),
          // 倍速播放
          Obx(
            () => TextButton(
              onPressed: () {
                var current = controller.playbackRate.value;
                double nextRate = 1.0;
                if (current == 1.0) {
                  nextRate = 1.25;
                } else if (current == 1.25) {
                  nextRate = 1.5;
                } else if (current == 1.5) {
                  nextRate = 2.0;
                } else if (current == 2.0) {
                  nextRate = 0.75;
                } else {
                  nextRate = 1.0;
                }
                controller.setPlaybackRate(nextRate);
              },
              child: Text(
                "${controller.playbackRate.value}x",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          const Spacer(),
          // 返回直播按钮
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withAlpha(200),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              controller.returnToLive();
            },
            icon: const Icon(Remix.live_line, size: 14),
            label: const Text("返回直播", style: TextStyle(fontSize: 12)),
          ),
          AppStyle.hGap12,
          // 全屏按钮
          IconButton(
            onPressed: () {
              if (controller.fullScreenState.value) {
                controller.exitFull();
              } else {
                controller.enterFullScreen();
              }
            },
            icon: Icon(
              controller.fullScreenState.value
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget playerControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  return Obx(() {
    if (controller.fullScreenState.value) {
      return buildFullControls(
        videoState,
        controller,
      );
    }
    return buildControls(
      videoState.context.orientation == Orientation.portrait,
      videoState,
      controller,
    );
  });
}

Widget buildFullControls(
  VideoState videoState,
  LiveRoomController controller,
) {
  var padding = MediaQuery.of(videoState.context).padding;
  GlobalKey volumeButtonkey = GlobalKey();
  return DragToMoveArea(
    child: Stack(
      children: [
        Container(),
        buildAudioOnlyOverlay(controller, videoState.context),
        buildDanmuView(videoState, controller),

        // 左下角SC显示
        Obx(
          () => Visibility(
            visible: AppSettingsController.instance.playershowSuperChat.value &&
                ((!Platform.isAndroid && !Platform.isIOS) ||
                    controller.fullScreenState.value),
            child: Positioned(
              left: 24,
              bottom: 24,
              child: PlayerSuperChatOverlay(controller: controller),
            ),
          ),
        ),

        Center(
          child: // 中间
              StreamBuilder(
            stream: videoState.widget.controller.player.stream.buffering,
            initialData: videoState.widget.controller.player.state.buffering,
            builder: (_, s) => Visibility(
              visible: s.data ?? false,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: controller.onTap,
            onDoubleTapDown: controller.onDoubleTap,
            onLongPress: () {
              if (controller.lockControlsState.value) {
                return;
              }
              showFollowUser(controller);
            },
            onVerticalDragStart: controller.onVerticalDragStart,
            onVerticalDragUpdate: controller.onVerticalDragUpdate,
            onVerticalDragEnd: controller.onVerticalDragEnd,
            child: MouseRegion(
              onHover: (PointerHoverEvent event) {
                controller.onHover(event, videoState.context);
              },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // 顶部
        Obx(
          () => AnimatedPositioned(
            left: 0,
            right: 0,
            top: (controller.showControlsState.value &&
                    !controller.lockControlsState.value)
                ? 0
                : -(64 + padding.top),
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: EdgeInsets.only(
                top: padding.top + 4,
                left: padding.left + 8,
                right: padding.right + 8,
                bottom: 4,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (controller.smallWindowState.value) {
                        controller.exitSmallWindow();
                      } else {
                        controller.exitFull();
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: Obx(
                      () => Text(
                        controller.isVODMode.value
                            ? "[回看] ${controller.currentReplay.value?.title ?? controller.detail.value?.title}"
                            : "${controller.detail.value?.title} - ${controller.detail.value?.userName}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  AppStyle.hGap12,
                  Obx(
                    () => Visibility(
                      visible: controller.isVODMode.value,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            backgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          onPressed: () => controller.returnToLive(),
                          icon: const Icon(Remix.live_line, size: 16),
                          label: const Text("返回直播",
                              style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  ),
                  Obx(
                    () => IconButton(
                      tooltip:
                          controller.isAudioOnly.value ? "恢复视频" : "纯音频模式",
                      onPressed: () {
                        controller.toggleAudioOnly();
                      },
                      icon: Icon(
                        controller.isAudioOnly.value
                            ? Remix.headphone_fill
                            : Remix.headphone_line,
                        color: controller.isAudioOnly.value
                            ? Theme.of(videoState.context).colorScheme.primary
                            : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.saveScreenshot();
                    },
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showFollowUser(controller);
                    },
                    icon: const Icon(
                      Remix.play_list_2_line,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Visibility(
                    visible: Platform.isAndroid,
                    child: IconButton(
                      onPressed: () {
                        controller.enablePIP();
                      },
                      icon: const Icon(
                        Icons.picture_in_picture,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Get.toNamed(
                        RoutePath.kMultiView,
                        arguments: {
                          'site': controller.site,
                          'roomId': controller.roomId,
                        },
                      );
                    },
                    icon: const Icon(
                      Remix.layout_grid_line,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: "以多屏同播打开",
                  ),
                  IconButton(
                    onPressed: () {
                      showPlayerSettings(controller);
                    },
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 底部
        Obx(
          () => AnimatedPositioned(
            left: 0,
            right: 0,
            bottom: (controller.showControlsState.value &&
                    !controller.lockControlsState.value)
                ? 0
                : -(80 + padding.bottom),
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black87,
                  ],
                ),
              ),
              padding: EdgeInsets.only(
                left: padding.left + 12,
                right: padding.right + 12,
                bottom: padding.bottom,
              ),
              child: Obx(() {
                if (controller.isVODMode.value) {
                  return buildVODBottomBar(controller, isFull: true);
                }
                return Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        controller.refreshRoom();
                      },
                      icon: const Icon(
                        Remix.refresh_line,
                        color: Colors.white,
                      ),
                    ),
                    Offstage(
                      offstage: controller.showDanmakuState.value,
                      child: IconButton(
                        onPressed: () => controller.showDanmakuState.value =
                            !controller.showDanmakuState.value,
                        icon: const ImageIcon(
                          AssetImage('assets/icons/icon_danmaku_open.png'),
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Offstage(
                      offstage: !controller.showDanmakuState.value,
                      child: IconButton(
                        onPressed: () => controller.showDanmakuState.value =
                            !controller.showDanmakuState.value,
                        icon: const ImageIcon(
                          AssetImage('assets/icons/icon_danmaku_close.png'),
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showDanmakuSettings(controller);
                      },
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_setting.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    Obx(
                      () => Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          controller.liveDuration.value,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    const Expanded(child: Center()),
                    Visibility(
                      visible: !Platform.isAndroid && !Platform.isIOS,
                      child: IconButton(
                        key: volumeButtonkey,
                        onPressed: () {
                          controller
                              .showVolumeSlider(volumeButtonkey.currentContext!);
                        },
                        icon: const Icon(
                          Icons.volume_down,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        showQualitesInfo(controller);
                      },
                      child: Obx(
                        () => Text(
                          controller.currentQualityInfo.value,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        showLinesInfo(controller);
                      },
                      child: Text(
                        controller.currentLineInfo.value,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (controller.smallWindowState.value) {
                          controller.exitSmallWindow();
                        } else {
                          controller.exitFull();
                        }
                      },
                      icon: const Icon(
                        Remix.fullscreen_exit_fill,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),

        // 右侧锁定
        Obx(
          () => AnimatedPositioned(
            top: 0,
            bottom: 0,
            right: controller.showControlsState.value
                ? padding.right + 12
                : -(64 + padding.right),
            duration: const Duration(milliseconds: 200),
            child: buildLockButton(controller),
          ),
        ),
        // 左侧锁定
        Obx(
          () => AnimatedPositioned(
            top: 0,
            bottom: 0,
            left: controller.showControlsState.value
                ? padding.left + 12
                : -(64 + padding.right),
            duration: const Duration(milliseconds: 200),
            child: buildLockButton(controller),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: !controller.showGestureTip.value,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.gestureTipText.value,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildLockButton(LiveRoomController controller) {
  return Center(
    child: InkWell(
      onTap: () {
        controller.setLockState();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: AppStyle.radius8,
        ),
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            controller.lockControlsState.value
                ? Icons.lock_outline_rounded
                : Icons.lock_open_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    ),
  );
}

Widget buildControls(
  bool isPortrait,
  VideoState videoState,
  LiveRoomController controller,
) {
  GlobalKey volumeButtonkey = GlobalKey();
  return Stack(
    children: [
      Container(),
      buildAudioOnlyOverlay(controller, videoState.context),
      buildDanmuView(videoState, controller),

      // 左下角SC显示
      Obx(
        () => Visibility(
          visible: AppSettingsController.instance.playershowSuperChat.value &&
              ((!Platform.isAndroid && !Platform.isIOS) ||
                  controller.fullScreenState.value),
          child: Positioned(
            left: 24,
            bottom: 24,
            child: PlayerSuperChatOverlay(controller: controller),
          ),
        ),
      ),

      // 中间
      Center(
        child: StreamBuilder(
          stream: videoState.widget.controller.player.stream.buffering,
          initialData: videoState.widget.controller.player.state.buffering,
          builder: (_, s) => Visibility(
            visible: s.data ?? false,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          onTap: controller.onTap,
          onDoubleTapDown: controller.onDoubleTap,
          onVerticalDragStart: controller.onVerticalDragStart,
          onVerticalDragUpdate: controller.onVerticalDragUpdate,
          onVerticalDragEnd: controller.onVerticalDragEnd,
          //onLongPress: controller.showDebugInfo,
          child: MouseRegion(
            onEnter: controller.onEnter,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ),
      ),
      Obx(
        () => AnimatedPositioned(
          left: 0,
          right: 0,
          bottom: controller.showControlsState.value ? 0 : -48,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black87,
                ],
              ),
            ),
            child: Obx(() {
              if (controller.isVODMode.value) {
                return buildVODBottomBar(controller, isFull: false);
              }
              return Row(
                children: [
                  IconButton(
                    onPressed: () {
                      controller.refreshRoom();
                    },
                    icon: const Icon(
                      Remix.refresh_line,
                      color: Colors.white,
                    ),
                  ),
                  Offstage(
                    offstage: controller.showDanmakuState.value,
                    child: IconButton(
                      onPressed: () => controller.showDanmakuState.value =
                          !controller.showDanmakuState.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_open.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !controller.showDanmakuState.value,
                    child: IconButton(
                      onPressed: () => controller.showDanmakuState.value =
                          !controller.showDanmakuState.value,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/icon_danmaku_close.png'),
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.showDanmuSettingsSheet();
                    },
                    icon: const ImageIcon(
                      AssetImage('assets/icons/icon_danmaku_setting.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  Obx(
                    () => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        controller.liveDuration.value,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  const Expanded(child: Center()),
                  Visibility(
                    visible: !Platform.isAndroid && !Platform.isIOS,
                    child: IconButton(
                      key: volumeButtonkey,
                      onPressed: () {
                        controller.showVolumeSlider(
                          volumeButtonkey.currentContext!,
                        );
                      },
                      icon: const Icon(
                        Icons.volume_down,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: isPortrait,
                    child: TextButton(
                      onPressed: () {
                        controller.showQualitySheet();
                      },
                      child: Obx(
                        () => Text(
                          controller.currentQualityInfo.value,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: isPortrait,
                    child: TextButton(
                      onPressed: () {
                        controller.showPlayUrlsSheet();
                      },
                      child: Text(
                        controller.currentLineInfo.value,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  Obx(
                    () => IconButton(
                      tooltip:
                          controller.isAudioOnly.value ? "恢复视频" : "纯音频模式",
                      onPressed: () {
                        controller.toggleAudioOnly();
                      },
                      icon: Icon(
                        controller.isAudioOnly.value
                            ? Remix.headphone_fill
                            : Remix.headphone_line,
                        color: controller.isAudioOnly.value
                            ? Theme.of(videoState.context).colorScheme.primary
                            : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: !Platform.isAndroid && !Platform.isIOS,
                    child: IconButton(
                      onPressed: () {
                        controller.enterSmallWindow();
                      },
                      icon: const Icon(
                        Icons.picture_in_picture,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.enterFullScreen();
                    },
                    icon: const Icon(
                      Remix.fullscreen_line,
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
      Obx(
        () => Offstage(
          offstage: !controller.showGestureTip.value,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                controller.gestureTipText.value,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget buildDanmuView(VideoState videoState, LiveRoomController controller) {
  var padding = MediaQuery.of(videoState.context).padding;
  controller.danmakuView ??= DanmakuScreen(
    key: controller.globalDanmuKey,
    createdController: controller.initDanmakuController,
    option: DanmakuOption(
      fontSize: AppSettingsController.instance.danmuSize.value,
      area: AppSettingsController.instance.danmuArea.value,
      duration: AppSettingsController.instance.danmuSpeed.value.toInt(),
      opacity: AppSettingsController.instance.danmuOpacity.value,
      //strokeWidth: AppSettingsController.instance.danmuStrokeWidth.value,
      fontWeight: AppSettingsController.instance.danmuFontWeight.value,
    ),
  );
  return Positioned.fill(
    top: padding.top,
    bottom: padding.bottom,
    child: Obx(
      () => Offstage(
        offstage: !controller.showDanmakuState.value,
        child: Padding(
          padding: controller.fullScreenState.value
              ? EdgeInsets.only(
                  top: AppSettingsController.instance.danmuTopMargin.value,
                  bottom:
                      AppSettingsController.instance.danmuBottomMargin.value,
                )
              : EdgeInsets.zero,
          child: controller.danmakuView!,
        ),
      ),
    ),
  );
}

void showLinesInfo(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showPlayUrlsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "线路",
    useSystem: true,
    child: ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: controller.playUrls.length,
      itemBuilder: (_, i) {
        return ListTile(
          selected: controller.currentLineIndex == i,
          title: Text.rich(
            TextSpan(
              text: "线路${i + 1}",
              children: [
                WidgetSpan(
                    child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppStyle.radius4,
                    border: Border.all(
                      color: Colors.grey,
                    ),
                  ),
                  padding: AppStyle.edgeInsetsH4,
                  margin: AppStyle.edgeInsetsL8,
                  child: Text(
                    controller.playUrls[i].contains(".flv") ? "FLV" : "HLS",
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                )),
              ],
            ),
            style: const TextStyle(fontSize: 14),
          ),
          minLeadingWidth: 16,
          onTap: () {
            Utils.hideRightDialog();
            //controller.currentLineIndex = i;
            //controller.setPlayer();
            controller.changePlayLine(i);
          },
        );
      },
    ),
  );
}

void showQualitesInfo(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showQualitySheet();
    return;
  }
  Utils.showRightDialog(
    title: "清晰度",
    useSystem: true,
    child: ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: controller.qualites.length,
      itemBuilder: (_, i) {
        var item = controller.qualites[i];
        return ListTile(
          selected: controller.currentQuality == i,
          title: Text(
            item.quality,
            style: const TextStyle(fontSize: 14),
          ),
          minLeadingWidth: 16,
          onTap: () {
            Utils.hideRightDialog();
            controller.currentQuality = i;
            controller.getPlayUrl();
          },
        );
      },
    ),
  );
}

void showDanmakuSettings(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showDanmuSettingsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "弹幕设置",
    width: 400,
    useSystem: true,
    child: Obx(
      () => ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          DanmuSettingsView(
            danmakuController: controller.danmakuController,
            isDanmakuConnected: controller.danmakuConnected.value,
            isDanmakuConnecting: controller.danmakuConnecting.value,
            onReconnectDanmaku: () {
              controller.reconnectDanmaku();
            },
          ),
        ],
      ),
    ),
  );
}

void showPlayerSettings(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showPlayerSettingsSheet();
    return;
  }
  Utils.showRightDialog(
    title: "设置",
    width: 320,
    useSystem: true,
    child: Obx(
      () => ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          SwitchListTile(
            secondary: Icon(
              controller.isAudioOnly.value
                  ? Remix.headphone_fill
                  : Remix.headphone_line,
              color: controller.isAudioOnly.value
                  ? Get.theme.colorScheme.primary
                  : null,
            ),
            title: const Text("纯音频模式"),
            subtitle: const Text("仅解码并播放音频，关闭视频渲染以省电"),
            value: controller.isAudioOnly.value,
            onChanged: (val) {
              controller.setAudioOnly(val);
            },
          ),
          const Divider(),
          Padding(
            padding: AppStyle.edgeInsetsH16,
            child: Text(
              "画面尺寸",
              style: Get.textTheme.titleMedium,
            ),
          ),
          RadioGroup(
            groupValue: AppSettingsController.instance.scaleMode.value,
            onChanged: (e) {
              AppSettingsController.instance.setScaleMode(e ?? 0);
              controller.updateScaleMode();
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: 0,
                  contentPadding: AppStyle.edgeInsetsH4,
                  title: Text("适应"),
                  visualDensity: VisualDensity.compact,
                ),
                RadioListTile(
                  value: 1,
                  contentPadding: AppStyle.edgeInsetsH4,
                  title: Text("拉伸"),
                  visualDensity: VisualDensity.compact,
                ),
                RadioListTile(
                  value: 2,
                  contentPadding: AppStyle.edgeInsetsH4,
                  title: Text("铺满"),
                  visualDensity: VisualDensity.compact,
                ),
                RadioListTile(
                  value: 3,
                  contentPadding: AppStyle.edgeInsetsH4,
                  title: Text("16:9"),
                  visualDensity: VisualDensity.compact,
                ),
                RadioListTile(
                  value: 4,
                  contentPadding: AppStyle.edgeInsetsH4,
                  title: Text("4:3"),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void showFollowUser(LiveRoomController controller) {
  if (controller.isVertical.value) {
    controller.showFollowUserSheet();
    return;
  }

  Utils.showRightDialog(
    title: "关注列表",
    width: 400,
    useSystem: true,
    child: Obx(
      () => Stack(
        children: [
          RefreshIndicator(
            onRefresh: FollowService.instance.loadData,
            child: ListView.builder(
              itemCount: FollowService.instance.liveList.length,
              itemBuilder: (_, i) {
                var item = FollowService.instance.liveList[i];
                return Obx(
                  () => FollowUserItem(
                    item: item,
                    playing: controller.rxSite.value.id == item.siteId &&
                        controller.rxRoomId.value == item.roomId,
                    onTap: () {
                      Utils.hideRightDialog();
                      controller.resetRoom(
                        Sites.allSites[item.siteId]!,
                        item.roomId,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            Positioned(
              right: 12,
              bottom: 12,
              child: Obx(
                () => DesktopRefreshButton(
                  refreshing: FollowService.instance.updating.value,
                  onPressed: FollowService.instance.loadData,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class PlayerSuperChatCard extends StatefulWidget {
  final LiveSuperChatMessage message;
  final VoidCallback onExpire;
  final int duration;
  const PlayerSuperChatCard(
      {required this.message,
      required this.onExpire,
      required this.duration,
      Key? key})
      : super(key: key);
  @override
  State<PlayerSuperChatCard> createState() => _PlayerSuperChatCardState();
}

class _PlayerSuperChatCardState extends State<PlayerSuperChatCard> {
  late Timer timer;
  late int countdown;
  @override
  void initState() {
    super.initState();
    countdown = widget.duration;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown <= 1) {
        widget.onExpire();
        timer.cancel();
        return;
      }
      setState(() {
        countdown -= 1;
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.65,
      child: SuperChatCard(
        widget.message,
        onExpire: () {},
        customCountdown: countdown,
      ),
    );
  }
}

class LocalDisplaySC {
  final LiveSuperChatMessage sc;
  final DateTime expireAt;
  final int duration;
  LocalDisplaySC(this.sc, this.expireAt, this.duration);
}

class PlayerSuperChatOverlay extends StatefulWidget {
  final LiveRoomController controller;
  const PlayerSuperChatOverlay({required this.controller, Key? key})
      : super(key: key);
  @override
  State<PlayerSuperChatOverlay> createState() => _PlayerSuperChatOverlayState();
}

class _PlayerSuperChatOverlayState extends State<PlayerSuperChatOverlay> {
  final List<LocalDisplaySC> _displayed = [];
  final Map<LocalDisplaySC, Timer> _timers = {};
  late Worker _worker;

  void _addSC(LiveSuperChatMessage sc, {int? customSeconds}) {
    if (_displayed.any((e) => e.sc == sc)) return;
    int showSeconds = customSeconds ?? 15;
    final expireAt = DateTime.now().add(Duration(seconds: showSeconds));
    final localSC = LocalDisplaySC(sc, expireAt, showSeconds);
    _displayed.add(localSC);
    _timers[localSC] = Timer(Duration(seconds: showSeconds), () {
      setState(() {
        _displayed.remove(localSC);
        _timers.remove(localSC)?.cancel();
      });
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // 首次进房时同步已有SC
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var sc in widget.controller.superChats) {
      int remain = (sc.endTime.millisecondsSinceEpoch - now) ~/ 1000;
      if (remain > 0) {
        _addSC(sc, customSeconds: remain < 15 ? remain : 15);
      }
    }
    // 监听SC列表变化
    _worker =
        ever<List<LiveSuperChatMessage>>(widget.controller.superChats, (list) {
      // 新增
      for (var sc in list) {
        if (!_displayed.any((e) => e.sc == sc)) {
          _addSC(sc);
        }
      }
      // 移除
      _displayed.removeWhere((e) => !list.contains(e.sc));
      setState(() {});
    });
  }

  @override
  void dispose() {
    _worker.dispose();
    for (var t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _displayed.toList()
      ..sort((a, b) => a.sc.endTime.compareTo(b.sc.endTime));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var localSC in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 240,
              child: PlayerSuperChatCard(
                message: localSC.sc,
                onExpire: () {},
                duration: localSC.duration,
              ),
            ),
          ),
      ],
    );
  }
}

/// 纯音频模式电台风格视觉覆盖层
Widget buildAudioOnlyOverlay(
  LiveRoomController controller,
  BuildContext context,
) {
  return Obx(() {
    if (!controller.isAudioOnly.value) {
      return const SizedBox.shrink();
    }
    final detail = controller.detail.value;
    final avatar = detail?.userAvatar ?? "";
    final cover = detail?.cover ?? "";
    final name = detail?.userName ?? "";

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF121212),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 磨砂模糊封面背景
            if (cover.isNotEmpty || avatar.isNotEmpty)
              Opacity(
                opacity: 0.35,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: NetImage(
                    cover.isNotEmpty ? cover : avatar,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            // 渐变蒙层
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black45,
                    Colors.black87,
                  ],
                ),
              ),
            ),
            // 居中信息
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(200),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(90),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: avatar.isNotEmpty
                        ? NetImage(
                            avatar,
                            width: 72,
                            height: 72,
                            borderRadius: 36,
                          )
                        : const CircleAvatar(
                            radius: 36,
                            child: Icon(Remix.radio_2_line, size: 36),
                          ),
                  ),
                  AppStyle.vGap12,
                  if (name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  AppStyle.vGap8,
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Remix.headphone_fill,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "纯音频模式运行中 (已停止视频画面渲染)",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  });
}
