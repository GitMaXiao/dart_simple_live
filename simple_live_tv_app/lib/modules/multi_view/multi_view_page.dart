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

class TVMultiViewPage extends GetView<TVMultiViewController> {
  const TVMultiViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 顶部遥控器控制栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
            color: const Color(0xFF141418),
            child: Row(
              children: [
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.arrow_back,
                  text: "退出",
                  onTap: () => Get.back(),
                ),
                AppStyle.hGap24,
                Text(
                  "多屏同播 / 多视角",
                  style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.bold),
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
                AppStyle.hGap24,
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
      foucsedColor: Colors.amberAccent.withAlpha(40),
      borderRadius: BorderRadius.circular(8.w),
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
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              border: Border.all(
                color: isFocused ? Colors.amberAccent : Colors.white12,
                width: isFocused ? 4.w : 1.w,
              ),
              borderRadius: BorderRadius.circular(8.w),
            ),
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
                  const Center(
                    child: CircularProgressIndicator(color: Colors.amberAccent),
                  ),

                // 错误状态
                if (item.isError.value)
                  Center(
                    child: Container(
                      padding: AppStyle.edgeInsetsA16,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12.w),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: Colors.redAccent, size: 40.w),
                          AppStyle.vGap8,
                          Text(
                            item.errorMsg.value,
                            style: TextStyle(color: Colors.white70, fontSize: 18.sp),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                // 角标 (视角标识与音量状态)
                if (item.hasRoom.value)
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.blueAccent : Colors.black87,
                        borderRadius: BorderRadius.circular(6.w),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            index == 0 ? "主视角 (1)" : "视角 (${index + 1})",
                            style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                          ),
                          if (item.isMuted.value || item.volume.value == 0) ...[
                            AppStyle.hGap8,
                            Icon(Remix.volume_mute_line, color: Colors.redAccent, size: 16.sp),
                          ],
                        ],
                      ),
                    ),
                  ),

                // 底部半透明信息浮层
                if (item.hasRoom.value)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      color: Colors.black.withAlpha(180),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${item.detail.value?.userName ?? item.roomId} - ${item.detail.value?.title ?? ''}",
                              style: TextStyle(color: Colors.white, fontSize: 16.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFocused)
                            Text(
                              "按 OK 键打开控制菜单",
                              style: TextStyle(color: Colors.amberAccent, fontSize: 14.sp),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Remix.add_circle_line,
            size: 48.w,
            color: hasFocus ? Colors.amberAccent : Colors.white38,
          ),
          AppStyle.vGap12,
          Text(
            "按 OK 键添加分屏 (${index + 1})",
            style: TextStyle(
              color: hasFocus ? Colors.amberAccent : Colors.white38,
              fontSize: 20.sp,
            ),
          ),
        ],
      ),
    );
  }
}
