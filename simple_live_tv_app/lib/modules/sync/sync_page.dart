import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/modules/sync/sync_controller.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';
import 'package:simple_live_tv_app/services/sync_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class SyncPage extends GetView<SyncController> {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap24,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: controller.backFocusNode,
                iconData: Icons.arrow_back,
                text: "返回",
                autofocus: true,
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "数据同步",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
          AppStyle.vGap24,
          Expanded(
            child: Row(
              children: [
                // 远程同步模块
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "远程同步",
                        style: AppStyle.titleStyleWhite.copyWith(
                          fontSize: 32.w,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppStyle.vGap16,
                      Obx(() {
                        var isConnected = controller.state.value ==
                                SignalRConnectionState.connected &&
                            controller.currentRoomId.value.isNotEmpty &&
                            controller.currentRoomId.value != "--";

                        if (isConnected) {
                          return QrImageView(
                            data: controller.currentRoomId.value,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                            padding: AppStyle.edgeInsetsA24,
                            size: 380.0.w,
                          );
                        } else if (controller.state.value ==
                            SignalRConnectionState.connecting) {
                          return Container(
                            width: 380.w,
                            height: 380.w,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: AppStyle.radius16,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            width: 380.w,
                            height: 380.w,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: AppStyle.radius16,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  size: 64.w,
                                  color: Colors.white54,
                                ),
                                AppStyle.vGap16,
                                Text(
                                  "远程连接失败",
                                  style: AppStyle.textStyleWhite,
                                ),
                                AppStyle.vGap16,
                                HighlightButton(
                                  focusNode: controller.remoteRetryFocusNode,
                                  iconData: Icons.refresh,
                                  text: "重新连接",
                                  onTap: () {
                                    controller.retryRemote();
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                      }),
                      AppStyle.vGap24,
                      Obx(() {
                        if (controller.state.value ==
                                SignalRConnectionState.connected &&
                            controller.currentRoomId.value != "--") {
                          return Column(
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: '房间号：',
                                  children: [
                                    TextSpan(
                                      text: controller.currentRoomId.value,
                                      style: AppStyle.textStyleWhite.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 28.w,
                                      ),
                                    )
                                  ],
                                ),
                                style: AppStyle.textStyleWhite,
                                textAlign: TextAlign.center,
                              ),
                              AppStyle.vGap8,
                              Text(
                                "${controller.countDown}秒后自动关闭 | 扫码或输入房间号连接",
                                style: AppStyle.textStyleWhite.copyWith(
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (controller.roomUsers.length > 1) ...[
                                AppStyle.vGap16,
                                HighlightButton(
                                  focusNode: controller.sendAllFocusNode,
                                  iconData: Icons.upload,
                                  text: "一键同步 TV 数据至手机",
                                  onTap: () {
                                    controller.sendAllToRoom();
                                  },
                                ),
                              ],
                            ],
                          );
                        } else if (controller.state.value ==
                            SignalRConnectionState.connecting) {
                          return Text(
                            '正在连接远程服务并创建房间...',
                            style: AppStyle.textStyleWhite,
                            textAlign: TextAlign.center,
                          );
                        } else {
                          return Text(
                            '远程同步服务器连接失败，请检查网络或重试',
                            style: AppStyle.textStyleWhite.copyWith(
                              color: Colors.redAccent,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }
                      }),
                    ],
                  ),
                ),
                VerticalDivider(
                  color: Colors.white.withAlpha(50),
                  thickness: 2.w,
                  endIndent: 120.w,
                  indent: 120.w,
                ),
                // 局域网同步模块
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "局域网同步",
                        style: AppStyle.titleStyleWhite.copyWith(
                          fontSize: 32.w,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppStyle.vGap16,
                      Obx(() {
                        if (SyncService.instance.httpRunning.value &&
                            SyncService.instance.ipAddress.value.isNotEmpty) {
                          return QrImageView(
                            data: SyncService.instance.ipAddress.value,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                            padding: AppStyle.edgeInsetsA24,
                            size: 380.0.w,
                          );
                        } else {
                          return Container(
                            width: 380.w,
                            height: 380.w,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: AppStyle.radius16,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 64.w,
                                  color: Colors.white54,
                                ),
                                AppStyle.vGap16,
                                Text(
                                  "局域网服务未启动",
                                  style: AppStyle.textStyleWhite,
                                ),
                                AppStyle.vGap16,
                                HighlightButton(
                                  focusNode: controller.localRetryFocusNode,
                                  iconData: Icons.refresh,
                                  text: "重新启动",
                                  onTap: () {
                                    controller.retryLocal();
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                      }),
                      AppStyle.vGap24,
                      Obx(() {
                        if (SyncService.instance.httpRunning.value) {
                          return Column(
                            children: [
                              Text(
                                '服务已启动：${SyncService.instance.ipAddress.value.split(';').map((e) => '$e:${SyncService.httpPort}').join('；')}',
                                style: AppStyle.textStyleWhite,
                                textAlign: TextAlign.center,
                              ),
                              AppStyle.vGap8,
                              Text(
                                "请确保手机与电视在同一Wi-Fi下并扫描二维码",
                                style: AppStyle.textStyleWhite.copyWith(
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        } else {
                          return Text(
                            'HTTP服务未启动：${SyncService.instance.httpErrorMsg}，请点击重试',
                            style: AppStyle.textStyleWhite.copyWith(
                              color: Colors.redAccent,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
