import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/multi_view/multi_view_item_controller.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';

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
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.w)),
      child: Container(
        width: 800.w,
        padding: AppStyle.edgeInsetsA32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${item.detail.value?.userName ?? item.roomId} - 分屏操作",
                    style: AppStyle.titleStyleWhite,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.close,
                  text: "返回",
                  onTap: () => Get.back(),
                ),
              ],
            ),
            AppStyle.vGap24,
            Wrap(
              spacing: 16.w,
              runSpacing: 16.h,
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
            if (item.qualities.isNotEmpty) ...[
              AppStyle.vGap24,
              Text("清晰度选择：", style: TextStyle(color: Colors.white70, fontSize: 20.sp)),
              AppStyle.vGap12,
              SizedBox(
                height: 180.h,
                child: ListView.separated(
                  itemCount: item.qualities.length,
                  separatorBuilder: (_, __) => AppStyle.vGap8,
                  itemBuilder: (context, qIndex) {
                    var q = item.qualities[qIndex];
                    bool isCurrent = item.currentQualityIndex.value == qIndex;
                    return HighlightListTile(
                      focusNode: AppFocusNode(),
                      title: q.quality,
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                          : null,
                      onTap: () {
                        Get.back();
                        item.switchQuality(qIndex);
                      },
                    );
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
