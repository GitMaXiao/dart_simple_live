import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/multi_view/multi_view_item_controller.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';

class TVMultiViewActionDialog extends StatelessWidget {
  final MultiViewItemController item;
  final VoidCallback onMakePrimary;
  final VoidCallback onReplace;
  final VoidCallback onCloseScreen;

  const TVMultiViewActionDialog({
    super.key,
    required this.item,
    required this.onMakePrimary,
    required this.onReplace,
    required this.onCloseScreen,
  });

  static Future<void> show({
    required MultiViewItemController item,
    required VoidCallback onMakePrimary,
    required VoidCallback onReplace,
    required VoidCallback onCloseScreen,
  }) async {
    await Get.dialog(
      TVMultiViewActionDialog(
        item: item,
        onMakePrimary: onMakePrimary,
        onReplace: onReplace,
        onCloseScreen: onCloseScreen,
      ),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14141B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.w),
        side: BorderSide(color: Colors.white.withAlpha(25), width: 1.w),
      ),
      child: Container(
        width: 880.w,
        padding: AppStyle.edgeInsetsA32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部主播详情卡片
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E28),
                borderRadius: BorderRadius.circular(14.w),
                border: Border.all(color: Colors.white.withAlpha(15), width: 1.w),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 56.w,
                    height: 56.w,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28.w),
                      child: NetImage(item.detail.value?.userAvatar ?? ''),
                    ),
                  ),
                  AppStyle.hGap16,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${item.detail.value?.userName ?? item.roomId}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppStyle.hGap12,
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: item.index == 0 ? Colors.blueAccent : Colors.white24,
                                borderRadius: BorderRadius.circular(6.w),
                              ),
                              child: Text(
                                item.index == 0 ? "主视角" : "视角 (${item.index + 1})",
                                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        AppStyle.vGap4,
                        Text(
                          item.detail.value?.title ?? '暂无标题',
                          style: TextStyle(color: Colors.white60, fontSize: 14.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.close,
                    text: "关闭菜单",
                    onTap: () => Get.back(),
                  ),
                ],
              ),
            ),
            AppStyle.vGap24,

            // 核心功能操作网格
            Text("快捷操作", style: TextStyle(color: Colors.white70, fontSize: 18.sp, fontWeight: FontWeight.bold)),
            AppStyle.vGap12,
            Wrap(
              spacing: 16.w,
              runSpacing: 14.h,
              children: [
                // 静音切换
                Obx(
                  () => HighlightButton(
                    autofocus: true,
                    focusNode: AppFocusNode(),
                    iconData: item.isMuted.value || item.volume.value == 0
                        ? Remix.volume_mute_line
                        : Remix.volume_up_line,
                    text: item.isMuted.value ? "取消静音" : "静音画面",
                    selected: item.isMuted.value,
                    onTap: () {
                      item.toggleMute();
                    },
                  ),
                ),
                // 设为主屏
                if (item.index != 0)
                  HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Remix.exchange_line,
                    text: "设为主屏 (1)",
                    onTap: () {
                      Get.back();
                      onMakePrimary();
                    },
                  ),
                // 更换直播间
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Remix.edit_line,
                  text: "更换直播间",
                  onTap: () {
                    Get.back();
                    onReplace();
                  },
                ),
                // 刷新画面
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Remix.refresh_line,
                  text: "刷新当前流",
                  onTap: () {
                    Get.back();
                    item.refreshStream();
                  },
                ),
                // 分屏弹幕开关
                Obx(
                  () => HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: item.showDanmaku.value ? Remix.chat_1_line : Remix.chat_off_line,
                    text: item.showDanmaku.value ? "弹幕: 开启" : "弹幕: 关闭",
                    selected: !item.showDanmaku.value,
                    onTap: () {
                      item.toggleDanmaku();
                    },
                  ),
                ),
                // 重连弹幕
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Remix.refresh_line,
                  text: "重连弹幕",
                  onTap: () {
                    Get.back();
                    item.reconnectDanmaku();
                  },
                ),
                // 关闭分屏
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Remix.delete_bin_line,
                  text: "关闭此分屏",
                  onTap: () {
                    Get.back();
                    onCloseScreen();
                  },
                ),
              ],
            ),

            // 清晰度选择区
            if (item.qualities.isNotEmpty) ...[
              AppStyle.vGap24,
              Text("清晰度选择", style: TextStyle(color: Colors.white70, fontSize: 18.sp, fontWeight: FontWeight.bold)),
              AppStyle.vGap12,
              SizedBox(
                height: 56.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.qualities.length,
                  separatorBuilder: (_, __) => AppStyle.hGap12,
                  itemBuilder: (context, qIndex) {
                    var q = item.qualities[qIndex];
                    var focusNode = AppFocusNode();
                    return Obx(() {
                      bool isCurrent = item.currentQualityIndex.value == qIndex;
                      return HighlightWidget(
                        focusNode: focusNode,
                        borderRadius: BorderRadius.circular(10.w),
                        color: isCurrent ? Colors.blueAccent.withAlpha(40) : const Color(0xFF1E1E28),
                        foucsedColor: Colors.amberAccent.withAlpha(60),
                        onTap: () {
                          Get.back();
                          item.switchQuality(qIndex);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.w),
                            border: Border.all(
                              color: isCurrent
                                  ? Colors.blueAccent
                                  : (focusNode.isFoucsed.value ? Colors.amberAccent : Colors.white12),
                              width: 2.w,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                q.quality,
                                style: TextStyle(
                                  color: isCurrent ? Colors.blueAccent : Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (isCurrent) ...[
                                AppStyle.hGap8,
                                Icon(Icons.check, color: Colors.blueAccent, size: 16.sp),
                              ],
                            ],
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
