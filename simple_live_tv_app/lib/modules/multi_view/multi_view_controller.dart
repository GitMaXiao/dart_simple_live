import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/multi_view/multi_view_item_controller.dart';
import 'package:simple_live_tv_app/modules/multi_view/widgets/multi_view_select_dialog.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum TVMultiViewLayout {
  two, // 2分屏
  three, // 3分屏 (1主屏 + 2小屏)
  four, // 4宫格
}

enum TVMultiViewDanmakuMode {
  none, // 关闭弹幕
  primary, // 仅主视角(1)
  focused, // 仅当前焦点视角
  all, // 全部视角
}

class TVMultiViewController extends GetxController {
  static const maxConcurrentDecoders = 3;

  final Rx<TVMultiViewLayout> layout = TVMultiViewLayout.four.obs;
  final RxInt focusedIndex = 0.obs;
  final RxBool isSoloAudioMode = true.obs; // 默认仅主焦点发声
  final Rx<TVMultiViewDanmakuMode> danmakuMode = TVMultiViewDanmakuMode.primary.obs; // 默认开启主视角弹幕
  bool _isApplyingPlaybackPolicy = false;
  bool _playbackPolicyPending = false;

  DanmakuController? globalDanmakuController;

  void initGlobalDanmakuController(DanmakuController c) {
    globalDanmakuController = c;
  }

  late final List<MultiViewItemController> items;
  late final List<AppFocusNode> focusNodes = List.generate(
    4,
    (_) => AppFocusNode(),
  );

  @override
  void onInit() {
    super.onInit();
    WakelockPlus.enable();

    // 初始化4个分屏控制器
    items = List.generate(
      4,
      (index) => MultiViewItemController(
        index: index,
        onPlaybackStateChanged: _schedulePlaybackPolicy,
      ),
    );

    // 处理初始传入的直播间参数
    _handleInitialArguments();
    _schedulePlaybackPolicy();
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
    _schedulePlaybackPolicy();
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

  /// 切换弹幕显示模式
  void cycleDanmakuMode() {
    globalDanmakuController?.clear();
    if (danmakuMode.value == TVMultiViewDanmakuMode.primary) {
      danmakuMode.value = TVMultiViewDanmakuMode.focused;
      SmartDialog.showToast("全屏弹幕: 仅当前焦点视角");
    } else if (danmakuMode.value == TVMultiViewDanmakuMode.focused) {
      danmakuMode.value = TVMultiViewDanmakuMode.all;
      SmartDialog.showToast("全屏弹幕: 全部视角混排");
    } else if (danmakuMode.value == TVMultiViewDanmakuMode.all) {
      danmakuMode.value = TVMultiViewDanmakuMode.none;
      SmartDialog.showToast("已关闭全屏弹幕");
    } else {
      danmakuMode.value = TVMultiViewDanmakuMode.primary;
      SmartDialog.showToast("全屏弹幕: 仅主视角 (1)");
    }
  }

  /// 分发来自各分屏的弹幕至大屏全屏弹幕层
  void dispatchDanmaku(int itemIndex, String message, Color color) {
    if (danmakuMode.value == TVMultiViewDanmakuMode.none) return;
    if (itemIndex < 0 || itemIndex >= items.length) return;
    if (!items[itemIndex].showDanmaku.value) return;

    bool shouldDispatch = false;
    switch (danmakuMode.value) {
      case TVMultiViewDanmakuMode.none:
        shouldDispatch = false;
        break;
      case TVMultiViewDanmakuMode.primary:
        shouldDispatch = (itemIndex == 0);
        break;
      case TVMultiViewDanmakuMode.focused:
        shouldDispatch = (itemIndex == focusedIndex.value);
        break;
      case TVMultiViewDanmakuMode.all:
        shouldDispatch = true;
        break;
    }

    if (shouldDispatch) {
      // 多路混排时，给非主视角加上视角编号前缀，方便区分
      String text = (danmakuMode.value == TVMultiViewDanmakuMode.all && items.length > 1)
          ? "[${itemIndex + 1}] $message"
          : message;
      globalDanmakuController?.addDanmaku(DanmakuContentItem(
        text,
        color: color,
      ));
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
    _schedulePlaybackPolicy();
  }

  /// 切换音频模式（独占发声 vs 独立混音）
  void toggleAudioMode() {
    isSoloAudioMode.value = true;
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
  void _schedulePlaybackPolicy() {
    if (_isApplyingPlaybackPolicy) {
      _playbackPolicyPending = true;
      return;
    }
    unawaited(_applyPlaybackPolicy());
  }

  Future<void> _applyPlaybackPolicy() async {
    if (_isApplyingPlaybackPolicy) return;
    _isApplyingPlaybackPolicy = true;
    try {
      final visibleIndexes = List.generate(getVisibleCount(), (index) => index);
      final primaryIndex = visibleIndexes.contains(focusedIndex.value)
          ? focusedIndex.value
          : visibleIndexes.first;
      final decodedIndexes = <int>[primaryIndex];
      for (final index in visibleIndexes) {
        if (index != primaryIndex &&
            decodedIndexes.length < maxConcurrentDecoders) {
          decodedIndexes.add(index);
        }
      }

      await Future.wait(
        List.generate(
          items.length,
          (index) => items[index].applyPlaybackPolicy(
            shouldDecode: decodedIndexes.contains(index),
            isPrimary: index == primaryIndex,
          ),
        ),
      );
    } finally {
      _isApplyingPlaybackPolicy = false;
      if (_playbackPolicyPending) {
        _playbackPolicyPending = false;
        _schedulePlaybackPolicy();
      }
    }
  }

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
    for (var node in focusNodes) {
      node.dispose();
    }
    super.onClose();
  }
}
