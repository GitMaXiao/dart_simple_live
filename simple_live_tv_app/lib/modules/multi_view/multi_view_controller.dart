import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/multi_view/multi_view_item_controller.dart';
import 'package:simple_live_tv_app/modules/multi_view/widgets/multi_view_select_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum TVMultiViewLayout {
  two, // 2分屏
  three, // 3分屏 (1主屏 + 2小屏)
  four, // 4宫格
}

class TVMultiViewController extends GetxController {
  final Rx<TVMultiViewLayout> layout = TVMultiViewLayout.four.obs;
  final RxInt focusedIndex = 0.obs;
  final RxBool isSoloAudioMode = true.obs; // 默认仅主焦点发声

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
  void setLayout(TVMultiViewLayout newLayout) {
    layout.value = newLayout;
    int maxVisible = getVisibleCount();
    if (focusedIndex.value >= maxVisible) {
      setFocus(0);
    }
  }

  int getVisibleCount() {
    switch (layout.value) {
      case TVMultiViewLayout.two:
        return 2;
      case TVMultiViewLayout.three:
        return 3;
      case TVMultiViewLayout.four:
        return 4;
    }
  }

  /// 切换布局循环
  void cycleLayout() {
    if (layout.value == TVMultiViewLayout.two) {
      setLayout(TVMultiViewLayout.three);
    } else if (layout.value == TVMultiViewLayout.three) {
      setLayout(TVMultiViewLayout.four);
    } else {
      setLayout(TVMultiViewLayout.two);
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
      setFocus(focusedIndex.value);
      SmartDialog.showToast("已开启【焦点独占发声】");
    } else {
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
    var result = await TVMultiViewSelectDialog.show();
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

  @override
  void onClose() {
    WakelockPlus.disable();
    for (var item in items) {
      item.dispose();
    }
    super.onClose();
  }
}

