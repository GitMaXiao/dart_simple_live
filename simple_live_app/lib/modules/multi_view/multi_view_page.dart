import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_item_controller.dart';
import 'package:simple_live_app/widgets/net_image.dart';

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

  String _getLayoutName(MultiViewLayout l) {
    switch (l) {
      case MultiViewLayout.two:
        return "2 分屏";
      case MultiViewLayout.three:
        return "3 分屏";
      case MultiViewLayout.four:
        return "4 宫格";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(
          () => controller.isFullScreen.value
              ? const SizedBox.shrink()
              : AppBar(
                  backgroundColor: const Color(0xFF101018),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  titleSpacing: 0,
                  leading: IconButton(
                    icon: const Icon(Remix.arrow_left_line),
                    onPressed: () => Get.back(),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.cyanAccent],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Remix.tv_2_line,
                          color: Colors.black,
                          size: 16,
                        ),
                      ),
                      AppStyle.hGap8,
                      const Text(
                        "多屏同播",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    // 布局切换胶囊
                    Obx(
                      () => TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Remix.layout_grid_line, size: 16),
                        label: Text(
                          _getLayoutName(controller.layout.value),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _showLayoutSheet(context),
                      ),
                    ),
                    // 音频模式
                    Obx(
                      () => IconButton(
                        icon: Icon(
                          controller.isSoloAudioMode.value
                              ? Remix.volume_up_line
                              : Remix.sound_module_line,
                          size: 19,
                          color: controller.isSoloAudioMode.value
                              ? Colors.blueAccent
                              : Colors.orangeAccent,
                        ),
                        tooltip: controller.isSoloAudioMode.value
                            ? "焦点独占音频 (点击切混音)"
                            : "多路混音模式 (点击切独占)",
                        onPressed: () => controller.toggleAudioMode(),
                      ),
                    ),
                    // 弹幕模式
                    Obx(
                      () => IconButton(
                        icon: Icon(
                          controller.danmakuMode.value != MultiViewDanmakuMode.none
                              ? Remix.chat_1_line
                              : Remix.chat_off_line,
                          size: 19,
                          color: controller.danmakuMode.value != MultiViewDanmakuMode.none
                              ? Colors.blueAccent
                              : Colors.white60,
                        ),
                        tooltip: _getDanmakuTooltip(controller.danmakuMode.value),
                        onPressed: () => controller.cycleDanmakuMode(),
                      ),
                    ),
                    // 全屏/横屏
                    IconButton(
                      icon: const Icon(Remix.fullscreen_line, size: 19),
                      tooltip: "全屏横屏",
                      onPressed: () => controller.toggleFullScreen(),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // 底层分屏播放画面
            Positioned.fill(
              child: Obx(() => _buildLayout(context)),
            ),

            // 顶层全局跨全屏弹幕层
            Positioned.fill(
              child: Obx(
                () => Offstage(
                  offstage: controller.danmakuMode.value == MultiViewDanmakuMode.none,
                  child: IgnorePointer(
                    child: DanmakuScreen(
                      key: const Key("mobile_multiview_global_danmaku"),
                      createdController: controller.initGlobalDanmakuController,
                      option: DanmakuOption(
                        fontSize: AppSettingsController.instance.danmuSize.value > 0
                            ? AppSettingsController.instance.danmuSize.value
                            : 14.0,
                        area: AppSettingsController.instance.danmuArea.value,
                        duration: AppSettingsController.instance.danmuSpeed.value.toInt() > 0
                            ? AppSettingsController.instance.danmuSpeed.value.toInt()
                            : 8,
                        opacity: AppSettingsController.instance.danmuOpacity.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 全屏模式下的悬浮胶囊控制条
            Obx(
              () => controller.isFullScreen.value
                  ? Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Remix.layout_grid_line, color: Colors.white, size: 17),
                              tooltip: "切换布局",
                              onPressed: () => controller.cycleLayout(),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                controller.isSoloAudioMode.value
                                    ? Remix.volume_up_line
                                    : Remix.sound_module_line,
                                color: controller.isSoloAudioMode.value
                                    ? Colors.blueAccent
                                    : Colors.orangeAccent,
                                size: 17,
                              ),
                              tooltip: controller.isSoloAudioMode.value ? "焦点独占音频" : "多路混音",
                              onPressed: () => controller.toggleAudioMode(),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                controller.danmakuMode.value != MultiViewDanmakuMode.none
                                    ? Remix.chat_1_line
                                    : Remix.chat_off_line,
                                color: controller.danmakuMode.value != MultiViewDanmakuMode.none
                                    ? Colors.blueAccent
                                    : Colors.white60,
                                size: 17,
                              ),
                              tooltip: _getDanmakuTooltip(controller.danmakuMode.value),
                              onPressed: () => controller.cycleDanmakuMode(),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Remix.fullscreen_exit_line, color: Colors.white, size: 17),
                              tooltip: "退出全屏",
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

  void _showLayoutSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Remix.layout_grid_line, size: 18),
                  AppStyle.hGap8,
                  Text(
                    "切换分屏布局",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Divider(),
            _buildLayoutOption(
              context,
              layout: MultiViewLayout.two,
              title: "2 分屏 (双画面)",
              subtitle: "左右或上下并排展示 2 个直播视角",
              icon: Remix.layout_column_line,
            ),
            _buildLayoutOption(
              context,
              layout: MultiViewLayout.three,
              title: "3 分屏 (1主+2副)",
              subtitle: "大主屏居左/居上，2个小副屏居侧",
              icon: Remix.layout_masonry_line,
            ),
            _buildLayoutOption(
              context,
              layout: MultiViewLayout.four,
              title: "4 宫格分屏",
              subtitle: "4个直播间等比例四分屏同播",
              icon: Remix.layout_grid_line,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOption(
    BuildContext context, {
    required MultiViewLayout layout,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    bool isSelected = controller.layout.value == layout;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withAlpha(25) : Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? primaryColor : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: isSelected
          ? Icon(Remix.check_line, color: primaryColor)
          : null,
      onTap: () {
        controller.setLayout(layout);
        Get.back();
      },
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
              Expanded(child: _buildItemView(context, 1)),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(child: _buildItemView(context, 0)),
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
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(child: _buildItemView(context, 1)),
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
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(child: _buildItemView(context, 1)),
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
              Expanded(child: _buildItemView(context, 1)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildItemView(context, 2)),
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
      bool isPlayingAudio = !item.isMuted.value && item.volume.value > 0;
      var site = item.site;

      return GestureDetector(
        onTap: () => controller.setFocus(index),
        child: Container(
          margin: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused ? Colors.blueAccent : Colors.white.withAlpha(20),
              width: isFocused ? 2.2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withAlpha(80),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
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

                // 加载中
                if (item.isLoading.value)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blueAccent,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "加载中...",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 错误提示
                if (item.isError.value)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withAlpha(100)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Remix.error_warning_line, color: Colors.redAccent, size: 26),
                          const SizedBox(height: 6),
                          Text(
                            item.errorMsg.value,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          AppStyle.vGap8,
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: () => item.refreshStream(),
                                child: const Text("重试", style: TextStyle(fontSize: 11)),
                              ),
                              AppStyle.hGap8,
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: () => controller.selectRoomForItem(index),
                                child: const Text("换房间", style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // 左上角综合信息 HUD 胶囊
                if (item.hasRoom.value)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 视角徽章
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: index == 0
                                ? const LinearGradient(
                                    colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
                                  )
                                : LinearGradient(
                                    colors: [Colors.black.withAlpha(190), Colors.grey.shade900],
                                  ),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(120),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            index == 0 ? "⭐ 主视角" : "视角 ${index + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 平台徽章
                        if (site != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(site.logo, width: 11, height: 11),
                                const SizedBox(width: 3),
                                Text(
                                  site.name,
                                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // 音频状态
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPlayingAudio
                                ? Colors.green.withAlpha(200)
                                : Colors.redAccent.withAlpha(200),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Icon(
                            isPlayingAudio ? Remix.volume_up_fill : Remix.volume_mute_fill,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 底部控制浮层（有房间时）
                if (item.hasRoom.value)
                  _buildOverlayControls(context, item, index, isFocused),
              ],
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            border: Border.all(color: Colors.white.withAlpha(30), width: 1.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Remix.add_line, size: 20, color: Colors.blueAccent),
              ),
              const SizedBox(height: 6),
              Text(
                "点击添加视角 (${index + 1})",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "关注 · 历史 · 搜索 · 链接",
                style: TextStyle(color: Colors.white38, fontSize: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black.withAlpha(160),
              Colors.black.withAlpha(220),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            // 主播头像与名称
            if (item.detail.value?.userAvatar != null &&
                item.detail.value!.userAvatar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: NetImage(
                    item.detail.value!.userAvatar,
                    width: 18,
                    height: 18,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                item.detail.value?.userName ?? (item.roomId ?? ""),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 静音/音量控制
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: Icon(
                item.isMuted.value || item.volume.value == 0
                    ? Remix.volume_mute_line
                    : Remix.volume_up_line,
                size: 15,
                color: item.isMuted.value ? Colors.redAccent : Colors.white,
              ),
              onPressed: () => item.toggleMute(),
            ),
            // 设为主屏
            if (index != 0)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Remix.exchange_line, size: 15, color: Colors.white70),
                tooltip: "设为主屏视角",
                onPressed: () => controller.makePrimary(index),
              ),
            // 画质选择胶囊
            if (item.qualities.isNotEmpty && item.currentQualityIndex.value >= 0)
              InkWell(
                onTap: () => _showQualitySheet(context, item),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Text(
                    item.qualities[item.currentQualityIndex.value].quality,
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ),
              ),
            // 更多操作
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 15, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "replace",
                  child: Row(
                    children: [
                      Icon(Remix.exchange_box_line, size: 16),
                      SizedBox(width: 8),
                      Text("更换直播间"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "refresh",
                  child: Row(
                    children: [
                      Icon(Remix.refresh_line, size: 16),
                      SizedBox(width: 8),
                      Text("刷新当前画面"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: "toggle_danmaku",
                  child: Row(
                    children: [
                      Icon(
                        item.showDanmaku.value ? Remix.chat_off_line : Remix.chat_1_line,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(item.showDanmaku.value ? "关闭此屏弹幕" : "开启此屏弹幕"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "reconnect_danmaku",
                  child: Row(
                    children: [
                      Icon(Remix.plug_line, size: 16),
                      SizedBox(width: 8),
                      Text("重连弹幕服务器"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "close",
                  child: Row(
                    children: [
                      Icon(Remix.close_circle_line, size: 16, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text("关闭此分屏", style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySheet(BuildContext context, MultiViewItemController item) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "选择清晰度 (${item.detail.value?.userName ?? '分屏'})",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const Divider(),
            ...List.generate(item.qualities.length, (qI) {
              var q = item.qualities[qI];
              bool isCurrent = item.currentQualityIndex.value == qI;
              return ListTile(
                title: Text(
                  q.quality,
                  style: TextStyle(
                    color: isCurrent ? Colors.blueAccent : null,
                    fontWeight: isCurrent ? FontWeight.bold : null,
                  ),
                ),
                trailing: isCurrent ? const Icon(Remix.check_line, color: Colors.blueAccent) : null,
                onTap: () {
                  item.switchQuality(qI);
                  Get.back();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
