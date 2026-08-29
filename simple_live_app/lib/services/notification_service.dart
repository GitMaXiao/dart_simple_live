import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/routes/route_path.dart';

class NotificationService extends GetxService {
  static NotificationService get instance => Get.find<NotificationService>();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String kChannelId = 'simple_live_anchor_notify';
  static const String kChannelName = '主播开播提醒';
  static const String kChannelDescription = '关注的主播开播时弹出系统桌面通知提醒';

  Future<NotificationService> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 创建 Android 高优先级通知渠道
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        kChannelId,
        kChannelName,
        description: kChannelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    return this;
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// 发送主播开播系统通知
  Future<void> showLiveNotification({
    required String siteId,
    required String roomId,
    required String userName,
    required String title,
    String? platformName,
  }) async {
    try {
      final int notificationId = "${siteId}_$roomId".hashCode;
      final String siteDisplay = platformName ??
          (Sites.allSites[siteId]?.name ?? siteId.toUpperCase());

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        kChannelId,
        kChannelName,
        channelDescription: kChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        styleInformation: BigTextStyleInformation(
          title.isNotEmpty ? title : "开播啦，快来围观！",
          contentTitle: "【$siteDisplay】$userName 开播啦！",
          summaryText: "开播提醒",
        ),
      );

      const DarwinNotificationDetails darwinDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final payload = jsonEncode({
        'siteId': siteId,
        'roomId': roomId,
      });

      await _notificationsPlugin.show(
        notificationId,
        "【$siteDisplay】$userName 开播啦！",
        title.isNotEmpty ? title : "主播开播啦，点击进入直播间",
        notificationDetails,
        payload: payload,
      );

      Log.d("已发送开播通知: $userName ($siteDisplay)");
    } catch (e) {
      Log.e("发送开播系统通知失败: $e", StackTrace.current);
    }
  }

  /// 点击系统通知时的回调
  void _onNotificationTapped(NotificationResponse response) {
    try {
      final String? payloadStr = response.payload;
      if (payloadStr == null || payloadStr.isEmpty) return;

      final Map<String, dynamic> data = jsonDecode(payloadStr);
      final String? siteId = data['siteId'];
      final String? roomId = data['roomId'];

      if (siteId != null && roomId != null) {
        final site = Sites.allSites[siteId];
        if (site != null) {
          Log.d("点击开播通知，正在跳转到直播间: ${site.name} - $roomId");
          Get.toNamed(
            RoutePath.kLiveRoomDetail,
            arguments: site,
            parameters: {"roomId": roomId},
          );
        }
      }
    } catch (e) {
      Log.e("解析开播通知 Payload 跳转失败: $e", StackTrace.current);
    }
  }
}
