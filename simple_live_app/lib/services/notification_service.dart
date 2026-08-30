import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:window_manager/window_manager.dart';

class NotificationService extends GetxService {
  static NotificationService get instance => Get.find<NotificationService>();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String kChannelId = 'simple_live_anchor_notify';
  static const String kChannelName = '主播开播提醒';
  static const String kChannelDescription = '关注的主播开播时弹出系统桌面通知提醒';
  static const String kGroupKey = 'com.xycz.simple_live.live_notifications';

  Future<NotificationService> init() async {
    // Windows 端初始化 local_notifier
    if (Platform.isWindows) {
      try {
        await localNotifier.setup(
          appName: 'Simple Live',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
        Log.d("Windows localNotifier 初始化成功");
      } catch (e) {
        Log.e("Windows localNotifier 初始化失败: $e", StackTrace.current);
      }
      return this;
    }

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

    // 检查应用冷启动时是否由点击通知触发
    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onNotificationTapped(response);
        });
      }
    }

    return this;
  }

  /// 检查通知权限是否已授权
  Future<bool> checkPermission() async {
    if (Platform.isWindows) {
      return true;
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true;
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    if (Platform.isWindows) {
      return true;
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// 打开系统应用通知设置
  Future<void> openNotificationSettings() async {
    if (Platform.isWindows) {
      SmartDialog.showToast("Windows 通知请在系统设置 -> 系统 -> 通知中进行配置");
      return;
    }
    await openAppSettings();
  }

  /// 下载网络头像字节流（带3秒超时，失败优雅回退）
  Future<Uint8List?> _downloadImageBytes(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final client = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse(url.trim()));
      final response =
          await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        return bytes;
      }
    } catch (e) {
      Log.d("下载通知头像失败: $e");
    }
    return null;
  }

  /// 发送主播开播系统通知
  Future<void> showLiveNotification({
    required String siteId,
    required String roomId,
    required String userName,
    required String title,
    String? avatarUrl,
    String? platformName,
  }) async {
    try {
      final String siteDisplay = platformName ??
          (Sites.allSites[siteId]?.name ?? siteId.toUpperCase());
      final String notificationTitle = "【$siteDisplay】$userName 开播啦！";
      final String notificationBody =
          title.isNotEmpty ? title : "主播开播啦，点击进入直播间";

      // Windows 平台使用 local_notifier 发送原生系统 Toast 通知
      if (Platform.isWindows) {
        final notification = LocalNotification(
          identifier: "${siteId}_$roomId",
          title: notificationTitle,
          body: notificationBody,
          actions: [
            LocalNotificationAction(text: '进入直播间'),
          ],
        );

        notification.onClick = () async {
          try {
            await windowManager.show();
            await windowManager.focus();
          } catch (e) {
            Log.d("唤醒窗口异常: $e");
          }
          _handleLiveRoomNavigation(siteId, roomId);
        };

        notification.onClickAction = (actionIndex) async {
          try {
            await windowManager.show();
            await windowManager.focus();
          } catch (e) {
            Log.d("唤醒窗口异常: $e");
          }
          _handleLiveRoomNavigation(siteId, roomId);
        };

        await notification.show();
        Log.d("已发送 Windows 开播通知: $userName ($siteDisplay)");
        return;
      }

      // Android / iOS / macOS / Linux 使用 flutter_local_notifications
      final int notificationId = "${siteId}_$roomId".hashCode;

      // 尝试下载头像作为通知大图标
      ByteArrayAndroidBitmap? largeIconBitmap;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        final bytes = await _downloadImageBytes(avatarUrl);
        if (bytes != null && bytes.isNotEmpty) {
          largeIconBitmap = ByteArrayAndroidBitmap(bytes);
        }
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        kChannelId,
        kChannelName,
        channelDescription: kChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        largeIcon: largeIconBitmap,
        groupKey: kGroupKey,
        styleInformation: BigTextStyleInformation(
          title.isNotEmpty ? title : "开播啦，快来围观！",
          contentTitle: notificationTitle,
          summaryText: "开播提醒",
        ),
      );

      final DarwinNotificationDetails darwinDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: siteDisplay,
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
        notificationTitle,
        notificationBody,
        notificationDetails,
        payload: payload,
      );

      Log.d("已发送开播通知: $userName ($siteDisplay)");
    } catch (e) {
      Log.e("发送开播系统通知失败: $e", StackTrace.current);
    }
  }

  /// 发送测试通知
  Future<void> showTestNotification() async {
    final granted = await requestPermission();
    if (!granted) {
      SmartDialog.showToast("通知权限未开启，请先在系统设置中允许通知");
      return;
    }
    await showLiveNotification(
      siteId: "bilibili",
      roomId: "0",
      userName: "Simple Live 测试主播",
      title: "恭喜！开播系统通知功能运行正常 🎉",
      platformName: "系统测试",
    );
    SmartDialog.showToast(
      Platform.isWindows
          ? "已发送 Windows 桌面通知，请查看屏幕右下角通知横幅"
          : "已发送测试通知，请查看系统通知栏",
    );
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
        _handleLiveRoomNavigation(siteId, roomId);
      }
    } catch (e) {
      Log.e("解析开播通知 Payload 跳转失败: $e", StackTrace.current);
    }
  }

  /// 统一处理跳转至直播间
  void _handleLiveRoomNavigation(String siteId, String roomId) {
    if (roomId != "0") {
      final site = Sites.allSites[siteId];
      if (site != null) {
        Log.d("点击开播通知，正在跳转到直播间: ${site.name} - $roomId");
        Future.delayed(const Duration(milliseconds: 300), () {
          Get.toNamed(
            RoutePath.kLiveRoomDetail,
            arguments: site,
            parameters: {"roomId": roomId},
          );
        });
      }
    }
  }
}
