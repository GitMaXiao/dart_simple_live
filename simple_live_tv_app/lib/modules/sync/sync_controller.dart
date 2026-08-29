import 'dart:async';
import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/models/db/history.dart';
import 'package:simple_live_tv_app/services/bilibili_account_service.dart';
import 'package:simple_live_tv_app/services/db_service.dart';
import 'package:simple_live_tv_app/services/signalr_service.dart';
import 'package:simple_live_tv_app/services/sync_service.dart';

class SyncController extends BaseController {
  final SignalRService signalR = SignalRService();
  StreamSubscription? _stateSubscription;
  StreamSubscription? _roomDestroyedSubscription;
  StreamSubscription? _roomUserUpdatedSubscription;
  StreamSubscription? _onFavoriteSubscription;
  StreamSubscription? _onHistorySubscription;
  StreamSubscription? _onShieldWordSubscription;
  StreamSubscription? _onBiliAccountSubscription;
  var currentRoomId = "--".obs;
  RxList<RoomUser> roomUsers = <RoomUser>[].obs;
  Timer? _timer;
  var countDown = 600.obs;

  Rx<SignalRConnectionState> state =
      Rx<SignalRConnectionState>(SignalRConnectionState.connecting);

  final backFocusNode = AppFocusNode();
  final remoteRetryFocusNode = AppFocusNode();
  final localRetryFocusNode = AppFocusNode();
  final sendAllFocusNode = AppFocusNode();
  final sendFollowFocusNode = AppFocusNode();
  final sendHistoryFocusNode = AppFocusNode();

  @override
  void onInit() {
    listenSignalR();
    connect();
    super.onInit();
  }

  void connect() async {
    state.value = SignalRConnectionState.connecting;
    currentRoomId.value = "--";
    try {
      await signalR.connect();
      if (signalR.state == SignalRConnectionState.connected) {
        createRoom();
      } else {
        state.value = SignalRConnectionState.disconnected;
      }
    } catch (e) {
      Log.e("SignalR connect error: $e", StackTrace.current);
      state.value = SignalRConnectionState.disconnected;
    }
  }

  void retryRemote() {
    connect();
  }

  void retryLocal() async {
    SmartDialog.showLoading(msg: "正在刷新局域网服务...");
    await SyncService.instance.restartServer();
    SmartDialog.dismiss();
  }

  void createRoom() async {
    try {
      var resp = await signalR.createRoom();
      if (resp.isSuccess && resp.data != null && resp.data!.isNotEmpty) {
        currentRoomId.value = resp.data!;
        _startTimer();
      } else {
        SmartDialog.showToast(resp.message.isNotEmpty ? resp.message : "创建房间失败");
        state.value = SignalRConnectionState.disconnected;
      }
    } catch (e) {
      SmartDialog.showToast("创建房间失败，请检查网络");
      state.value = SignalRConnectionState.disconnected;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    countDown.value = 600;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countDown--;
      if (countDown <= 0) {
        timer.cancel();
        Get.back();
      }
    });
  }

  void listenSignalR() {
    _stateSubscription = signalR.stateStream.listen((event) {
      state.value = event;
    });
    _roomDestroyedSubscription = signalR.onRoomDestroyedStream.listen((roomId) {
      SmartDialog.showToast("房间已被销毁");
      state.value = SignalRConnectionState.disconnected;
      currentRoomId.value = "--";
    });
    _roomUserUpdatedSubscription = signalR.onRoomUserUpdatedStream.listen(
      (roomUsers) {
        this.roomUsers.assignAll(roomUsers);
      },
    );
    _onFavoriteSubscription = signalR.onFavoriteStream.listen((data) {
      onReceiveFavorite(data.$1, data.$2);
    });
    _onHistorySubscription = signalR.onHistoryStream.listen((data) {
      onReceiveHistory(data.$1, data.$2);
    });
    _onShieldWordSubscription = signalR.onShieldWordStream.listen((data) {
      onReceiveShieldWord(data.$1, data.$2);
    });
    _onBiliAccountSubscription = signalR.onBiliAccountStream.listen((data) {
      onReceiveBiliAccount(data.$1, data.$2);
    });
  }

  // ===================== 接收远端同步数据 =====================

  void onReceiveFavorite(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data);
      if (overlay) {
        await DBService.instance.followBox.clear();
      }
      for (var item in jsonBody) {
        var user = FollowUser.fromJson(item);
        await DBService.instance.followBox.put(user.id, user);
      }
      SmartDialog.showToast('已同步关注用户列表');
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveHistory(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data);
      if (overlay) {
        await DBService.instance.historyBox.clear();
      }
      for (var item in jsonBody) {
        var history = History.fromJson(item);
        if (DBService.instance.historyBox.containsKey(history.id)) {
          var old = DBService.instance.historyBox.get(history.id);
          if (old!.updateTime.isAfter(history.updateTime)) {
            continue;
          }
        }
        await DBService.instance.addOrUpdateHistory(history);
      }
      SmartDialog.showToast('已同步历史记录');
      EventBus.instance.emit(Constant.kUpdateHistory, 0);
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveShieldWord(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data);
      if (overlay) {
        AppSettingsController.instance.clearShieldList();
      }
      for (var item in jsonBody) {
        AppSettingsController.instance.addShieldList(item);
      }
      SmartDialog.showToast('已同步屏蔽词');
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  void onReceiveBiliAccount(bool overlay, String data) async {
    try {
      var jsonBody = json.decode(data);
      var cookie = jsonBody['cookie'];
      BiliBiliAccountService.instance.setCookie(cookie);
      BiliBiliAccountService.instance.loadUserInfo();
      SmartDialog.showToast('已同步哔哩哔哩账号');
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    }
  }

  // ===================== 从 TV 端向房间/手机端发送数据 =====================

  /// 发送 TV 关注列表给房间内的手机
  Future<void> sendFollowToRoom({bool overlay = false}) async {
    if (roomUsers.length <= 1) {
      SmartDialog.showToast("无手机设备连接");
      return;
    }
    try {
      SmartDialog.showLoading(msg: "正在发送关注列表...");
      var follows = DBService.instance.followBox.values.map((e) => e.toJson()).toList();
      var data = json.encode(follows);
      var resp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: "SendFavorite",
        overlay: overlay,
        content: data,
      );
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送 TV 端关注列表至手机");
      } else {
        SmartDialog.showToast("发送失败: ${resp.message}");
      }
    } catch (e) {
      SmartDialog.showToast("发送失败: $e");
    } finally {
      SmartDialog.dismiss();
    }
  }

  /// 发送 TV 播放历史给房间内的手机
  Future<void> sendHistoryToRoom({bool overlay = false}) async {
    if (roomUsers.length <= 1) {
      SmartDialog.showToast("无手机设备连接");
      return;
    }
    try {
      SmartDialog.showLoading(msg: "正在发送历史记录...");
      var histories = DBService.instance.historyBox.values.map((e) => e.toJson()).toList();
      var data = json.encode(histories);
      var resp = await signalR.sendContent(
        roomName: currentRoomId.value,
        action: "SendHistory",
        overlay: overlay,
        content: data,
      );
      if (resp.isSuccess) {
        SmartDialog.showToast("已发送 TV 端历史记录至手机");
      } else {
        SmartDialog.showToast("发送失败: ${resp.message}");
      }
    } catch (e) {
      SmartDialog.showToast("发送失败: $e");
    } finally {
      SmartDialog.dismiss();
    }
  }

  /// 一键将 TV 端全部数据（关注、历史、屏蔽词、B站账号）同步给手机
  Future<void> sendAllToRoom() async {
    if (roomUsers.length <= 1) {
      SmartDialog.showToast("暂无手机设备连接至房间");
      return;
    }
    try {
      SmartDialog.showLoading(msg: "正在同步全量数据至手机...");
      
      // 1. 发送关注
      var follows = DBService.instance.followBox.values.map((e) => e.toJson()).toList();
      if (follows.isNotEmpty) {
        await signalR.sendContent(
          roomName: currentRoomId.value,
          action: "SendFavorite",
          overlay: false,
          content: json.encode(follows),
        );
      }

      // 2. 发送历史
      var histories = DBService.instance.historyBox.values.map((e) => e.toJson()).toList();
      if (histories.isNotEmpty) {
        await signalR.sendContent(
          roomName: currentRoomId.value,
          action: "SendHistory",
          overlay: false,
          content: json.encode(histories),
        );
      }

      // 3. 发送屏蔽词
      var words = AppSettingsController.instance.shieldList.toList();
      if (words.isNotEmpty) {
        await signalR.sendContent(
          roomName: currentRoomId.value,
          action: "SendShieldWord",
          overlay: false,
          content: json.encode(words),
        );
      }

      // 4. 发送 Bilibili 账号
      if (BiliBiliAccountService.instance.logined.value &&
          BiliBiliAccountService.instance.cookie.isNotEmpty) {
        await signalR.sendContent(
          roomName: currentRoomId.value,
          action: "SendBiliAccount",
          overlay: true,
          content: json.encode({
            "cookie": BiliBiliAccountService.instance.cookie,
          }),
        );
      }

      SmartDialog.showToast("已成功将 TV 端全部数据同步至手机！");
    } catch (e) {
      SmartDialog.showToast("同步出错: $e");
    } finally {
      SmartDialog.dismiss();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _stateSubscription?.cancel();
    _roomDestroyedSubscription?.cancel();
    _roomUserUpdatedSubscription?.cancel();
    _onFavoriteSubscription?.cancel();
    _onHistorySubscription?.cancel();
    _onShieldWordSubscription?.cancel();
    _onBiliAccountSubscription?.cancel();
    signalR.dispose();
    super.onClose();
  }
}
