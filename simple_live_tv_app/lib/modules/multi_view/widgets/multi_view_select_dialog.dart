import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_list_tile.dart';
import 'package:simple_live_tv_app/widgets/net_image.dart';

class TVMultiViewSelectResult {
  final Site site;
  final String roomId;
  final String title;
  final String userName;
  final String cover;

  TVMultiViewSelectResult({
    required this.site,
    required this.roomId,
    required this.title,
    required this.userName,
    required this.cover,
  });
}

class TVMultiViewSelectDialog extends StatefulWidget {
  const TVMultiViewSelectDialog({super.key});

  static Future<TVMultiViewSelectResult?> show() async {
    return await Get.dialog<TVMultiViewSelectResult?>(
      const TVMultiViewSelectDialog(),
      barrierDismissible: true,
    );
  }

  @override
  State<TVMultiViewSelectDialog> createState() => _TVMultiViewSelectDialogState();
}

class _TVMultiViewSelectDialogState extends State<TVMultiViewSelectDialog> {
  int _currentTab = 0; // 0: 我的关注, 1: 观看记录

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.w)),
      child: Container(
        width: 1100.w,
        height: 700.h,
        padding: AppStyle.edgeInsetsA32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("选择分屏直播间", style: AppStyle.titleStyleWhite),
                const Spacer(),
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: _currentTab == 0 ? Remix.heart_fill : Remix.heart_line,
                  text: "我的关注",
                  selected: _currentTab == 0,
                  onTap: () {
                    setState(() => _currentTab = 0);
                  },
                ),
                AppStyle.hGap24,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: _currentTab == 1 ? Icons.history : Icons.history_toggle_off,
                  text: "观看记录",
                  selected: _currentTab == 1,
                  onTap: () {
                    setState(() => _currentTab = 1);
                  },
                ),
              ],
            ),
            AppStyle.vGap24,
            Expanded(
              child: _currentTab == 0 ? _buildFollowList() : _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowList() {
    return Obx(() {
      var living = FollowUserService.instance.livingList;
      var all = FollowUserService.instance.list;
      var items = living.isNotEmpty ? living : all;

      if (items.isEmpty) {
        return Center(
          child: Text("暂无关注的主播", style: TextStyle(color: Colors.white70, fontSize: 24.sp)),
        );
      }

      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => AppStyle.vGap12,
        itemBuilder: (context, index) {
          var user = items[index];
          var site = Sites.allSites[user.siteId];
          return HighlightListTile(
            autofocus: index == 0,
            focusNode: AppFocusNode(),
            leading: SizedBox(
              width: 56.w,
              height: 56.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28.w),
                child: NetImage(user.face),
              ),
            ),
            title: "${user.userName} (${site?.name ?? user.siteId.toUpperCase()})",
            subtitle: "房间号: ${user.roomId}",
            trailing: user.liveStatus.value == 2
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6.w),
                    ),
                    child: Text("直播中", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                  )
                : null,
            onTap: () {
              if (site != null) {
                Get.back(
                  result: TVMultiViewSelectResult(
                    site: site,
                    roomId: user.roomId,
                    title: user.userName,
                    userName: user.userName,
                    cover: user.face,
                  ),
                );
              }
            },
          );
        },
      );
    });
  }

  Widget _buildHistoryList() {
    var historyList = DBService.instance.getHistores().reversed.toList();
    if (historyList.isEmpty) {
      return Center(
        child: Text("暂无观看记录", style: TextStyle(color: Colors.white70, fontSize: 24.sp)),
      );
    }

    return ListView.separated(
      itemCount: historyList.length,
      separatorBuilder: (_, __) => AppStyle.vGap12,
      itemBuilder: (context, index) {
        var his = historyList[index];
        var site = Sites.allSites[his.siteId];
        return HighlightListTile(
          autofocus: index == 0,
          focusNode: AppFocusNode(),
          leading: SizedBox(
            width: 56.w,
            height: 56.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.w),
              child: NetImage(his.face),
            ),
          ),
          title: "${his.userName} (${site?.name ?? his.siteId.toUpperCase()})",
          subtitle: "房间号: ${his.roomId}",
          onTap: () {
            if (site != null) {
              Get.back(
                result: TVMultiViewSelectResult(
                  site: site,
                  roomId: his.roomId,
                  title: his.userName,
                  userName: his.userName,
                  cover: his.face,
                ),
              );
            }
          },
        );
      },
    );
  }
}
