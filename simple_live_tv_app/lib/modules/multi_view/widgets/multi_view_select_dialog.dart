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
import 'package:simple_live_tv_app/widgets/highlight_widget.dart';
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
      backgroundColor: const Color(0xFF14141B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.w),
        side: BorderSide(color: Colors.white.withAlpha(25), width: 1.w),
      ),
      child: Container(
        width: 1150.w,
        height: 720.h,
        padding: AppStyle.edgeInsetsA32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题与标签栏
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.amberAccent, Colors.orangeAccent],
                        ),
                        borderRadius: BorderRadius.circular(10.w),
                      ),
                      child: Icon(Remix.tv_2_line, color: Colors.black, size: 24.sp),
                    ),
                    AppStyle.hGap16,
                    Text(
                      "选择分屏直播间",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
                AppStyle.hGap16,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: _currentTab == 1 ? Icons.history : Icons.history_toggle_off,
                  text: "观看记录",
                  selected: _currentTab == 1,
                  onTap: () {
                    setState(() => _currentTab = 1);
                  },
                ),
                AppStyle.hGap16,
                HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: Icons.close,
                  text: "关闭",
                  onTap: () => Get.back(),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 64.w, color: Colors.white24),
              AppStyle.vGap16,
              Text("暂无关注的主播", style: TextStyle(color: Colors.white38, fontSize: 20.sp)),
            ],
          ),
        );
      }

      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 2.8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          var user = items[index];
          var site = Sites.allSites[user.siteId];
          bool isLive = user.liveStatus.value == 2;
          return _buildGridCard(
            index: index,
            face: user.face,
            userName: user.userName,
            roomId: user.roomId,
            site: site,
            siteId: user.siteId,
            isLive: isLive,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 64.w, color: Colors.white24),
            AppStyle.vGap16,
            Text("暂无观看记录", style: TextStyle(color: Colors.white38, fontSize: 20.sp)),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16.h,
        crossAxisSpacing: 16.w,
        childAspectRatio: 2.8,
      ),
      itemCount: historyList.length,
      itemBuilder: (context, index) {
        var his = historyList[index];
        var site = Sites.allSites[his.siteId];
        return _buildGridCard(
          index: index,
          face: his.face,
          userName: his.userName,
          roomId: his.roomId,
          site: site,
          siteId: his.siteId,
          isLive: false,
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

  Widget _buildGridCard({
    required int index,
    required String face,
    required String userName,
    required String roomId,
    required Site? site,
    required String siteId,
    required bool isLive,
    required VoidCallback onTap,
  }) {
    var focusNode = AppFocusNode();
    Color siteColor = _getSiteColor(siteId);

    return HighlightWidget(
      autofocus: index == 0,
      focusNode: focusNode,
      borderRadius: BorderRadius.circular(14.w),
      color: const Color(0xFF1E1E28),
      foucsedColor: Colors.amberAccent.withAlpha(50),
      onTap: onTap,
      child: Obx(
        () {
          final isFocused = focusNode.isFoucsed.value;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.w),
              border: Border.all(
                color: isFocused ? Colors.amberAccent : Colors.white.withAlpha(20),
                width: isFocused ? 3.w : 1.w,
              ),
            ),
            child: Row(
              children: [
                // 头像与开播红点
                Stack(
                  children: [
                    SizedBox(
                      width: 58.w,
                      height: 58.w,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(29.w),
                        child: NetImage(face),
                      ),
                    ),
                    if (isLive)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14.w,
                          height: 14.w,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2.w),
                          ),
                        ),
                      ),
                  ],
                ),
                AppStyle.hGap12,
                // 信息区
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          color: isFocused ? Colors.amberAccent : Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppStyle.vGap4,
                      Row(
                        children: [
                          // 平台徽章
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: siteColor.withAlpha(50),
                              borderRadius: BorderRadius.circular(4.w),
                              border: Border.all(color: siteColor.withAlpha(120), width: 1.w),
                            ),
                            child: Text(
                              site?.name ?? siteId.toUpperCase(),
                              style: TextStyle(
                                color: siteColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          AppStyle.hGap8,
                          Expanded(
                            child: Text(
                              "房号: $roomId",
                              style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLive)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.deepOrangeAccent],
                      ),
                      borderRadius: BorderRadius.circular(6.w),
                    ),
                    child: Text(
                      "直播中",
                      style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getSiteColor(String siteId) {
    switch (siteId.toLowerCase()) {
      case 'bilibili':
        return const Color(0xFFFB7299);
      case 'douyu':
        return const Color(0xFFFF5D23);
      case 'huya':
        return const Color(0xFFFF9600);
      case 'douyin':
        return const Color(0xFF00F0FF);
      case 'kuaishou':
        return const Color(0xFFFF4906);
      default:
        return Colors.blueAccent;
    }
  }
}
