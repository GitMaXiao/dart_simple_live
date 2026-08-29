import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/multi_view/multi_view_controller.dart';
import 'package:simple_live_tv_app/modules/multi_view/multi_view_item_controller.dart';
import 'package:simple_live_tv_app/modules/multi_view/widgets/multi_view_action_dialog.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';

class TVMultiViewPage extends GetView<TVMultiViewController> {
  const TVMultiViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: Column(
        children: [
          // 顶部遥控器控制栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF14141B),
              border: Border(bottom: BorderSide(color: Colors.white.withAlpha(15), width: 1.w)),
            ),
            child: Row(
              children: [
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.arrow_back,
                  text: "退出",
                  onTap: () => Get.back(),
                ),
                AppStyle.hGap20,
                // 页面标题徽章
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.amberAccent, Colors.orangeAccent],
                        ),
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                      child: Icon(Remix.tv_2_line, color: Colors.black, size: 20.sp),
                    ),
                    AppStyle.hGap12,
                    Text(
                      "多屏同播 / 多视角",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                AppStyle.hGap20,
                // 操作提示胶囊
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(6.w),
                  ),
                  child: Text(
                    "按遥控器 OK 键呼出分屏菜单",
                    style: TextStyle(color: Colors.amberAccent.withAlpha(200), fontSize: 13.sp),
                  ),
                ),
                const Spacer(),
                // 布局切换
                Obx(
                  () => HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Remix.layout_grid_line,
                    text: _getLayoutName(controller.layout.value),
                    onTap: () => controller.cycleLayout(),
                  ),
                ),
                AppStyle.hGap16,
                // 音频模式
                Obx(
                  () => HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: controller.isSoloAudioMode.value
                        ? Remix.volume_up_line
                        : Remix.sound_module_line,
                    text: controller.isSoloAudioMode.value ? "焦点发声" : "多路混音",
                    selected: !controller.isSoloAudioMode.value,
                    onTap: () => controller.toggleAudioMode(),
                  ),
                ),
              ],
            ),
          ),
          // 分屏展示区
          Expanded(
            child: Obx(() => _buildLayout(context)),
          ),
        ],
      ),
    );
  }

  String _getLayoutName(TVMultiViewLayout l) {
    switch (l) {
      case TVMultiViewLayout.two:
        return "2 分屏";
      case TVMultiViewLayout.three:
        return "3 分屏 (1主+2副)";
      case TVMultiViewLayout.four:
        return "4 宫格";
    }
  }

  Widget _buildLayout(BuildContext context) {
    switch (controller.layout.value) {
      case TVMultiViewLayout.two:
        return Row(
          children: [
            Expanded(child: _buildItemView(context, 0)),
            Container(width: 4.w, color: Colors.black),
            Expanded(child: _buildItemView(context, 1)),
          ],
        );
      case TVMultiViewLayout.three:
        return Row(
          children: [
            Expanded(flex: 2, child: _buildItemView(context, 0)),
            Container(width: 4.w, color: Colors.black),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _buildItemView(context, 1)),
                  Container(height: 4.h, color: Colors.black),
                  Expanded(child: _buildItemView(context, 2)),
                ],
              ),
            ),
          ],
        );
      case TVMultiViewLayout.four:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildItemView(context, 0)),
                  Container(width: 4.w, color: Colors.black),
                  Expanded(child: _buildItemView(context, 1)),
                ],
              ),
            ),
            Container(height: 4.h, color: Colors.black),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildItemView(context, 2)),
                  Container(width: 4.w, color: Colors.black),
                  Expanded(child: _buildItemView(context, 3)),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildItemView(BuildContext context, int index) {
    var item = controller.items[index];
    var focusNode = controller.focusNodes[index];

    return HighlightWidget(
      focusNode: focusNode,
      autofocus: index == 0,
      foucsedColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12.w),
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          controller.setFocus(index);
        }
      },
      onTap: () {
        _handleItemClick(context, item, index);
      },
      child: Obx(
        () {
          final isFocused = focusNode.isFoucsed.value;
          final isPlayingAudio = !item.isMuted.value && item.volume.value > 0;

          return Container(
            margin: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F14),
              borderRadius: BorderRadius.circular(12.w),
              border: Border.all(
                color: isFocused ? Colors.amberAccent : Colors.white.withAlpha(25),
                width: isFocused ? 3.5.w : 1.w,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.amberAccent.withAlpha(90),
                        blurRadius: 16.w,
                        spreadRadius: 2.w,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9.w),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 视频画面
                  if (item.hasRoom.value)
                    Video(
                      controller: item.videoController,
                      controls: NoVideoControls,
                    )
                  else
                    _buildEmptySlot(index, isFocused),

                  // 加载状态
                  if (item.isLoading.value)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10.w),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.amberAccent,
                              ),
                            ),
                            AppStyle.hGap16,
                            Text(
                              "正在加载流媒体...",
                              style: TextStyle(color: Colors.white, fontSize: 16.sp),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 错误状态
                  if (item.isError.value)
                    Center(
                      child: Container(
                        padding: AppStyle.edgeInsetsA20,
                        margin: EdgeInsets.symmetric(horizontal: 20.w),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(220),
                          borderRadius: BorderRadius.circular(14.w),
                          border: Border.all(color: Colors.redAccent.withAlpha(120), width: 1.w),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.redAccent, size: 36.w),
                            AppStyle.vGap8,
                            Text(
                              item.errorMsg.value,
                              style: TextStyle(color: Colors.white, fontSize: 16.sp),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppStyle.vGap12,
                            Text(
                              "按 OK 键重新选房 / 换源",
                              style: TextStyle(color: Colors.amberAccent, fontSize: 13.sp),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 左上角角标 (视角标识与音量状态)
                  if (item.hasRoom.value)
                    Positioned(
                      top: 10.h,
                      left: 10.w,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 视角标签
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              gradient: index == 0
                                  ? const LinearGradient(
                                      colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
                                    )
                                  : LinearGradient(
                                      colors: [Colors.black87, Colors.grey.shade900],
                                    ),
                              borderRadius: BorderRadius.circular(6.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(120),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              index == 0 ? "⭐ 主视角" : "视角 ${index + 1}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          AppStyle.hGap8,
                          // 声音状态
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: isPlayingAudio
                                  ? Colors.green.withAlpha(200)
                                  : Colors.redAccent.withAlpha(200),
                              borderRadius: BorderRadius.circular(6.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(120),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPlayingAudio ? Remix.volume_up_line : Remix.volume_mute_line,
                                  color: Colors.white,
                                  size: 13.sp,
                                ),
                                AppStyle.hGap4,
                                Text(
                                  isPlayingAudio ? "发声中" : "静音",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 底部半透明主播信息浮层
                  if (item.hasRoom.value)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26.w,
                              height: 26.w,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13.w),
                                child: NetImage(item.detail.value?.userAvatar ?? ''),
                              ),
                            ),
                            AppStyle.hGap12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${item.detail.value?.userName ?? item.roomId}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item.detail.value?.title ?? '',
                                    style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isFocused)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent,
                                  borderRadius: BorderRadius.circular(4.w),
                                ),
                                child: Text(
                                  "OK 控制",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleItemClick(BuildContext context, MultiViewItemController item, int index) async {
    if (!item.hasRoom.value) {
      await controller.selectRoomForItem(index);
    } else {
      await TVMultiViewActionDialog.show(
        item: item,
        onMakePrimary: () => controller.makePrimary(index),
        onReplace: () => controller.selectRoomForItem(index),
        onCloseScreen: () => item.clearRoom(),
      );
    }
    // 对话框关闭后，还原遥控器焦点至当前分屏
    controller.focusNodes[index].requestFocus();
  }

  Widget _buildEmptySlot(int index, bool hasFocus) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: hasFocus ? Colors.amberAccent.withAlpha(20) : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(16.w),
          border: Border.all(
            color: hasFocus ? Colors.amberAccent : Colors.white12,
            width: hasFocus ? 2.w : 1.w,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Remix.add_circle_line,
              size: 44.w,
              color: hasFocus ? Colors.amberAccent : Colors.white38,
            ),
            AppStyle.vGap12,
            Text(
              "按 OK 键添加视角 (${index + 1})",
              style: TextStyle(
                color: hasFocus ? Colors.amberAccent : Colors.white60,
                fontSize: 18.sp,
                fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            AppStyle.vGap4,
            Text(
              "支持从关注列表或观看历史添加",
              style: TextStyle(color: Colors.white30, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}
