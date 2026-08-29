import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/multi_view/multi_view_item_controller.dart';
import 'package:simple_live_app/modules/multi_view/widgets/multi_view_select_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum MultiViewLayout {
  two, // 2分屏
  three, // 3分屏 (1主屏 + 2小屏)
  four, // 4宫格
}

class MultiViewController extends GetxController {
  final Rx<MultiViewLayout> layout = MultiViewLayout.four.obs;
  final RxInt focusedIndex = 0.obs;
  final RxBool isSoloAudioMode = true.obs; // 默认仅主焦点发声
  final RxBool isFullScreen = false.obs;

  late final List<MultiViewItemController> items;

  @override
  void onInit() {
    super.onInit();
    WakelockPlus.enable();

    // 初始化4个分屏控制器
    items = List.generate(
      4,
      (index) => MultiViewItemController(
        index: index,
        onFocusRequested: (i) => setFocus(i),
      ),
    );

    // 处理初始传入的直播间参数
    _handleInitialArguments();
  }

  void _handleInitialArguments() {
    var args = Get.arguments;
    if (args is Map && args.containsKey('site') && args.containsKey('roomId')) {
      Site? site = args['site'] is Site
          ? args['site']
          : Sites.allSites[args['site']?.toString()];
      String? roomId = args['roomId']?.toString();
      if (site != null && roomId != null && roomId.isNotEmpty) {
        items[0].loadRoom(site, roomId);
      }
    }
  }

  /// 切换分屏布局模式
  void setLayout(MultiViewLayout newLayout) {
    layout.value = newLayout;
    // 如果焦点超出了当前可见分屏数，重置为0
    int maxVisible = getVisibleCount();
    if (focusedIndex.value >= maxVisible) {
      setFocus(0);
    }
  }

  int getVisibleCount() {
    switch (layout.value) {
      case MultiViewLayout.two:
        return 2;
      case MultiViewLayout.three:
        return 3;
      case MultiViewLayout.four:
        return 4;
    }
  }

  /// 设置主焦点分屏
  void setFocus(int index) {
    if (index < 0 || index >= 4) return;
    focusedIndex.value = index;

    if (isSoloAudioMode.value) {
      // 独占音频模式：仅焦点窗口发声，其余静音
      for (int i = 0; i < 4; i++) {
        if (i == index) {
          items[i].mute(false);
        } else {
          items[i].mute(true);
        }
      }
    }
  }

  /// 切换音频模式（独占发声 vs 独立混音）
  void toggleAudioMode() {
    isSoloAudioMode.value = !isSoloAudioMode.value;
    if (isSoloAudioMode.value) {
      // 启用独占模式
      setFocus(focusedIndex.value);
      SmartDialog.showToast("已开启【焦点独占发声】模式");
    } else {
      // 启用混音模式：解静音所有有直播间的窗口
      for (var item in items) {
        if (item.hasRoom.value) {
          item.mute(false);
        }
      }
      SmartDialog.showToast("已开启【多路混音】模式");
    }
  }

  /// 选择并添加/替换直播间
  Future<void> selectRoomForItem(int index) async {
    var result = await MultiViewSelectDialog.show();
    if (result != null) {
      await items[index].loadRoom(result.site, result.roomId);
      if (isSoloAudioMode.value) {
        setFocus(index);
      }
    }
  }

  /// 互换两个屏幕的位置
  void swapScreen(int a, int b) {
    if (a == b || a < 0 || a >= 4 || b < 0 || b >= 4) return;
    var siteA = items[a].site;
    var roomA = items[a].roomId;
    var hasRoomA = items[a].hasRoom.value;

    var siteB = items[b].site;
    var roomB = items[b].roomId;
    var hasRoomB = items[b].hasRoom.value;

    items[a].clearRoom();
    items[b].clearRoom();

    if (hasRoomA && siteA != null && roomA != null) {
      items[b].loadRoom(siteA, roomA);
    }
    if (hasRoomB && siteB != null && roomB != null) {
      items[a].loadRoom(siteB, roomB);
    }

    setFocus(b);
  }

  /// 将当前分屏与主屏(0号屏)互换
  void makePrimary(int index) {
    if (index == 0) return;
    swapScreen(0, index);
  }

  /// 切换全屏/横屏模式
  void toggleFullScreen() {
    isFullScreen.value = !isFullScreen.value;
    if (isFullScreen.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void onClose() {
    WakelockPlus.disable();
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    for (var item in items) {
      item.dispose();
    }
    super.onClose();
  }
}
