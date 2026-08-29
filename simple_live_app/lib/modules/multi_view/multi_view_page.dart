import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_item_controller.dart';

class MultiViewPage extends GetView<MultiViewController> {
  const MultiViewPage({super.key});

  String _getDanmakuTooltip(MultiViewDanmakuMode mode) {
    switch (mode) {
      case MultiViewDanmakuMode.none:
        return "弹幕已关闭 (点击开启主视角弹幕)";
      case MultiViewDanmakuMode.primary:
        return "主视角弹幕 (点击开启焦点弹幕)";
      case MultiViewDanmakuMode.focused:
        return "仅焦点视角弹幕 (点击开启全部视角弹幕)";
      case MultiViewDanmakuMode.all:
        return "全部视角弹幕 (点击关闭)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(
          () => controller.isFullScreen.value
              ? const SizedBox.shrink()
              : AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  title: const Text("多屏同播 / 多视角", style: TextStyle(fontSize: 16)),
                  actions: [
                    // 布局切换
                    PopupMenuButton<MultiViewLayout>(
                      icon: const Icon(Remix.layout_grid_line, size: 20),
                      tooltip: "切换分屏布局",
                      onSelected: (l) => controller.setLayout(l),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: MultiViewLayout.two,
                          child: Text("2 分屏"),
                        ),
                        const PopupMenuItem(
                          value: MultiViewLayout.three,
                          child: Text("3 分屏 (1主+2副)"),
                        ),
                        const PopupMenuItem(
                          value: MultiViewLayout.four,
                          child: Text("4 宫格分屏"),
                        ),
                      ],
                    ),
                    // 音频模式
                    IconButton(
                      icon: Icon(
                        controller.isSoloAudioMode.value
                            ? Remix.volume_up_line
                            : Remix.sound_module_line,
                        size: 20,
                        color: controller.isSoloAudioMode.value ? Colors.blueAccent : Colors.orangeAccent,
                      ),
                      tooltip: controller.isSoloAudioMode.value ? "焦点独占音频 (点击切混音)" : "多路混音模式 (点击切独占)",
                      onPressed: () => controller.toggleAudioMode(),
                    ),
                    // 弹幕模式
                    IconButton(
                      icon: Icon(
                        controller.danmakuMode.value != MultiViewDanmakuMode.none
                            ? Remix.chat_1_line
                            : Remix.chat_off_line,
                        size: 20,
                        color: controller.danmakuMode.value != MultiViewDanmakuMode.none
                            ? Colors.blueAccent
                            : Colors.white60,
                      ),
                      tooltip: _getDanmakuTooltip(controller.danmakuMode.value),
                      onPressed: () => controller.cycleDanmakuMode(),
                    ),
                    // 全屏/横屏
                    IconButton(
                      icon: const Icon(Remix.fullscreen_line, size: 20),
                      tooltip: "横屏全屏",
                      onPressed: () => controller.toggleFullScreen(),
                    ),
                  ],
                ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Obx(() => _buildLayout(context)),
            // 全屏模式下的悬浮返回与退出全屏按钮
            Obx(
              () => controller.isFullScreen.value
                  ? Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(150),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Remix.layout_grid_line, color: Colors.white, size: 18),
                              onPressed: () {
                                var next = controller.layout.value == MultiViewLayout.four
                                    ? MultiViewLayout.two
                                    : (controller.layout.value == MultiViewLayout.two
                                        ? MultiViewLayout.three
                                        : MultiViewLayout.four);
                                controller.setLayout(next);
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                controller.isSoloAudioMode.value
                                    ? Remix.volume_up_line
                                    : Remix.sound_module_line,
                                color: controller.isSoloAudioMode.value ? Colors.blueAccent : Colors.orangeAccent,
                                size: 18,
                              ),
                              onPressed: () => controller.toggleAudioMode(),
                            ),
                            IconButton(
                              icon: Icon(
                                controller.danmakuMode.value != MultiViewDanmakuMode.none
                                    ? Remix.chat_1_line
                                    : Remix.chat_off_line,
                                color: controller.danmakuMode.value != MultiViewDanmakuMode.none
                                    ? Colors.blueAccent
                                    : Colors.white60,
                                size: 18,
                              ),
                              onPressed: () => controller.cycleDanmakuMode(),
                            ),
                            IconButton(
                              icon: const Icon(Remix.fullscreen_exit_line, color: Colors.white, size: 18),
                              onPressed: () => controller.toggleFullScreen(),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context) {
    switch (controller.layout.value) {
      case MultiViewLayout.two:
        return _buildTwoLayout(context);
      case MultiViewLayout.three:
        return _buildThreeLayout(context);
      case MultiViewLayout.four:
        return _buildFourLayout(context);
    }
  }

  Widget _buildTwoLayout(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return Row(
            children: [
              Expanded(child: _buildItemView(context, 0)),
              Container(width: 2, color: Colors.grey.shade900),
              Expanded(child: _buildItemView(context, 1)),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(child: _buildItemView(context, 0)),
              Container(height: 2, color: Colors.grey.shade900),
              Expanded(child: _buildItemView(context, 1)),
            ],
          );
        }
      },
    );
  }

  Widget _buildThreeLayout(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return Row(
            children: [
              Expanded(flex: 2, child: _buildItemView(context, 0)),
              Container(width: 2, color: Colors.grey.shade900),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(child: _buildItemView(context, 1)),
                    Container(height: 2, color: Colors.grey.shade900),
                    Expanded(child: _buildItemView(context, 2)),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(flex: 2, child: _buildItemView(context, 0)),
              Container(height: 2, color: Colors.grey.shade900),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(child: _buildItemView(context, 1)),
                    Container(width: 2, color: Colors.grey.shade900),
                    Expanded(child: _buildItemView(context, 2)),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildFourLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildItemView(context, 0)),
              Container(width: 2, color: Colors.grey.shade900),
              Expanded(child: _buildItemView(context, 1)),
            ],
          ),
        ),
        Container(height: 2, color: Colors.grey.shade900),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildItemView(context, 2)),
              Container(width: 2, color: Colors.grey.shade900),
              Expanded(child: _buildItemView(context, 3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemView(BuildContext context, int index) {
    var item = controller.items[index];
    return Obx(() {
      bool isFocused = controller.focusedIndex.value == index;
      return GestureDetector(
        onTap: () => controller.setFocus(index),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: isFocused
                ? Border.all(color: Colors.blueAccent, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 视频或未添加占位
              if (item.hasRoom.value)
                Video(
                  controller: item.videoController,
                  controls: NoVideoControls,
                )
              else
                _buildEmptyPlaceholder(context, index),

              // 弹幕图层
              if (item.hasRoom.value)
                Obx(() {
                  bool isVisible = controller.shouldShowDanmaku(index) && item.showDanmaku.value;
                  return Offstage(
                    offstage: !isVisible,
                    child: DanmakuScreen(
                      key: Key("danmaku_mobile_item_${item.roomId ?? index}"),
                      createdController: item.initDanmakuController,
                      option: DanmakuOption(
                        fontSize: (index == 0 && controller.layout.value == MultiViewLayout.three) ? 14 : 11,
                        area: 0.65,
                        duration: 7,
                        opacity: 0.85,
                      ),
                    ),
                  );
                }),

              // 加载中
              if (item.isLoading.value)
                const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                ),

              // 错误提示
              if (item.isError.value)
                Center(
                  child: Container(
                    padding: AppStyle.edgeInsetsA12,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                        AppStyle.vGap8,
                        Text(
                          item.errorMsg.value,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        AppStyle.vGap8,
                        FilledButton.tonal(
                          onPressed: () => item.refreshStream(),
                          child: const Text("重试"),
                        ),
                      ],
                    ),
                  ),
                ),

              // 焦点角标
              if (isFocused && item.hasRoom.value)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      index == 0 ? "主视角 (1)" : "视角 (${index + 1})",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // 控制浮层（当有房间时）
              if (item.hasRoom.value)
                _buildOverlayControls(context, item, index, isFocused),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildEmptyPlaceholder(BuildContext context, int index) {
    return Center(
      child: InkWell(
        onTap: () => controller.selectRoomForItem(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Remix.add_circle_line, size: 32, color: Colors.white70),
              AppStyle.vGap8,
              Text(
                "点击添加分屏 (${index + 1})",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayControls(
    BuildContext context,
    MultiViewItemController item,
    int index,
    bool isFocused,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black87],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            // 主播名字
            Expanded(
              child: Text(
                item.detail.value?.userName ?? (item.roomId ?? ""),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 静音/音量控制
            IconButton(
              icon: Icon(
                item.isMuted.value || item.volume.value == 0
                    ? Remix.volume_mute_line
                    : Remix.volume_up_line,
                size: 16,
                color: item.isMuted.value ? Colors.redAccent : Colors.white,
              ),
              onPressed: () => item.toggleMute(),
            ),
            // 设为主屏
            if (index != 0)
              IconButton(
                icon: const Icon(Remix.exchange_line, size: 16, color: Colors.white70),
                tooltip: "设为主屏视角",
                onPressed: () => controller.makePrimary(index),
              ),
            // 更多操作 (画质、更换、移除)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: Colors.white70),
              onSelected: (val) {
                if (val == "replace") {
                  controller.selectRoomForItem(index);
                } else if (val == "refresh") {
                  item.refreshStream();
                } else if (val == "toggle_danmaku") {
                  item.toggleDanmaku();
                } else if (val == "reconnect_danmaku") {
                  item.reconnectDanmaku();
                } else if (val == "close") {
                  item.clearRoom();
                } else if (val.startsWith("quality_")) {
                  int qIndex = int.parse(val.split("_")[1]);
                  item.switchQuality(qIndex);
                }
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem(
                    value: "replace",
                    child: Text("更换直播间"),
                  ),
                  const PopupMenuItem(
                    value: "refresh",
                    child: Text("刷新当前画面"),
                  ),
                  PopupMenuItem(
                    value: "toggle_danmaku",
                    child: Text(item.showDanmaku.value ? "关闭此屏弹幕" : "开启此屏弹幕"),
                  ),
                  const PopupMenuItem(
                    value: "reconnect_danmaku",
                    child: Text("重连弹幕服务器"),
                  ),
                  const PopupMenuItem(
                    value: "close",
                    child: Text("关闭此分屏"),
                  ),
                  if (item.qualities.isNotEmpty) const PopupMenuDivider(),
                  if (item.qualities.isNotEmpty)
                    ...List.generate(item.qualities.length, (qI) {
                      var q = item.qualities[qI];
                      bool isCurrent = item.currentQualityIndex.value == qI;
                      return PopupMenuItem(
                        value: "quality_$qI",
                        child: Text(
                          "${q.quality}${isCurrent ? ' ✓' : ''}",
                          style: TextStyle(
                            color: isCurrent ? Colors.blueAccent : null,
                            fontWeight: isCurrent ? FontWeight.bold : null,
                          ),
                        ),
                      );
                    }),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
