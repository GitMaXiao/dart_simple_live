import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/sync_client_request.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/sync_service.dart';

class SyncDeviceController extends BaseController {
  final SyncClinet client;
  final SyncClientInfoModel info;
  SyncDeviceController({required this.client, required this.info});
  SyncClientRequest request = SyncClientRequest();

  Future<bool> showOverlayDialog({String title = "是否覆盖远端数据？"}) async {
    var overlay = await Utils.showAlertDialog(
      title,
      title: "数据覆盖",
      confirm: "覆盖",
      cancel: "不覆盖",
    );
    return overlay;
  }

  // ===================== 推送数据至设备 (手机 -> TV) =====================

  void syncFollowAndTag() async {
    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "正在发送至设备...");
      var users = DBService.instance.getFollowList();
      var tags = DBService.instance.getFollowTagList();
      var data = json.encode(users.map((e) => e.toJson()).toList());
      var dataT = json.encode(tags.map((e) => e.toJson()).toList());
      await request.syncFollow(client, data, overlay: overlay);
      await request.syncTag(client, dataT, overlay: overlay);
      SmartDialog.showToast("已同步关注列表至设备");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncHistory() async {
    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "正在发送至设备...");
      var histores = DBService.instance.getHistores();
      var data = json.encode(histores.map((e) => e.toJson()).toList());
      await request.syncHistory(client, data, overlay: overlay);
      SmartDialog.showToast("已同步历史记录至设备");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBlockedWord() async {
    try {
      var overlay = await showOverlayDialog();
      SmartDialog.showLoading(msg: "正在发送至设备...");
      var shieldList = AppSettingsController.instance.shieldList;
      var data = json.encode(shieldList.toList());
      await request.syncBlockedWord(client, data, overlay: overlay);
      SmartDialog.showToast("已同步屏蔽词至设备");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  void syncBiliAccount() async {
    try {
      if (!BiliBiliAccountService.instance.logined.value) {
        SmartDialog.showToast("未登录哔哩哔哩");
        return;
      }
      SmartDialog.showLoading(msg: "正在发送至设备...");

      await request.syncBiliAccount(
          client, BiliBiliAccountService.instance.cookie);
      SmartDialog.showToast("已同步哔哩哔哩账号至设备");
    } catch (e) {
      SmartDialog.showToast("同步失败:$e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  // ===================== 从设备拉取数据 (TV -> 手机) =====================

  /// 从设备拉取关注列表
  void pullFollow() async {
    try {
      var overlay = await showOverlayDialog(title: "是否覆盖手机本地的关注列表？");
      SmartDialog.showLoading(msg: "正在从设备拉取关注列表...");
      var list = await request.getFollow(client);
      if (overlay) {
        await DBService.instance.followBox.clear();
      }
      for (var item in list) {
        var user = FollowUser.fromJson(item);
        await DBService.instance.followBox.put(user.id, user);
      }
      EventBus.instance.emit(Constant.kUpdateFollow, 0);
      SmartDialog.showToast("成功导入 ${list.length} 个关注主播");
    } catch (e) {
      SmartDialog.showToast("从设备导入关注失败: $e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  /// 从设备拉取观看历史
  void pullHistory() async {
    try {
      var overlay = await showOverlayDialog(title: "是否覆盖手机本地的播放历史？");
      SmartDialog.showLoading(msg: "正在从设备拉取播放历史...");
      var list = await request.getHistory(client);
      if (overlay) {
        await DBService.instance.historyBox.clear();
      }
      for (var item in list) {
        var history = History.fromJson(item);
        if (DBService.instance.historyBox.containsKey(history.id)) {
          var old = DBService.instance.historyBox.get(history.id);
          if (old != null && old.updateTime.isAfter(history.updateTime)) {
            continue;
          }
        }
        await DBService.instance.addOrUpdateHistory(history);
      }
      EventBus.instance.emit(Constant.kUpdateHistory, 0);
      SmartDialog.showToast("成功导入 ${list.length} 条观看历史");
    } catch (e) {
      SmartDialog.showToast("从设备导入历史记录失败: $e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  /// 从设备拉取弹幕屏蔽词
  void pullBlockedWord() async {
    try {
      var overlay = await showOverlayDialog(title: "是否覆盖手机本地的屏蔽词？");
      SmartDialog.showLoading(msg: "正在从设备拉取屏蔽词...");
      var list = await request.getBlockedWord(client);
      if (overlay) {
        AppSettingsController.instance.clearShieldList();
      }
      for (var item in list) {
        AppSettingsController.instance.addShieldList(item.toString());
      }
      SmartDialog.showToast("成功导入 ${list.length} 条屏蔽词");
    } catch (e) {
      SmartDialog.showToast("从设备导入屏蔽词失败: $e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  /// 从设备拉取哔哩哔哩账号
  void pullBiliAccount() async {
    try {
      SmartDialog.showLoading(msg: "正在从设备拉取哔哩哔哩账号...");
      var account = await request.getBiliAccount(client);
      var cookie = account['cookie']?.toString() ?? "";
      if (cookie.isEmpty) {
        SmartDialog.showToast("设备端尚未登录哔哩哔哩账号");
        return;
      }
      BiliBiliAccountService.instance.setCookie(cookie);
      await BiliBiliAccountService.instance.loadUserInfo();
      SmartDialog.showToast("已成功导入哔哩哔哩账号");
    } catch (e) {
      SmartDialog.showToast("从设备导入账号失败: $e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }

  /// 从设备一键拉取全部数据
  void pullAll() async {
    try {
      var overlay = await showOverlayDialog(title: "是否覆盖手机本地全部数据？");
      SmartDialog.showLoading(msg: "正在一键导入设备全部数据...");
      var allData = await request.getAll(client);

      // 1. 关注
      if (allData["follows"] != null) {
        var follows = allData["follows"] as List;
        if (overlay) await DBService.instance.followBox.clear();
        for (var item in follows) {
          var user = FollowUser.fromJson(item);
          await DBService.instance.followBox.put(user.id, user);
        }
        EventBus.instance.emit(Constant.kUpdateFollow, 0);
      }

      // 2. 历史
      if (allData["histories"] != null) {
        var histories = allData["histories"] as List;
        if (overlay) await DBService.instance.historyBox.clear();
        for (var item in histories) {
          var history = History.fromJson(item);
          if (DBService.instance.historyBox.containsKey(history.id)) {
            var old = DBService.instance.historyBox.get(history.id);
            if (old != null && old.updateTime.isAfter(history.updateTime)) {
              continue;
            }
          }
          await DBService.instance.addOrUpdateHistory(history);
        }
        EventBus.instance.emit(Constant.kUpdateHistory, 0);
      }

      // 3. 屏蔽词
      if (allData["blocked_words"] != null) {
        var words = allData["blocked_words"] as List;
        if (overlay) AppSettingsController.instance.clearShieldList();
        for (var word in words) {
          AppSettingsController.instance.addShieldList(word.toString());
        }
      }

      // 4. B站账号
      if (allData["bilibili_cookie"] != null &&
          allData["bilibili_cookie"].toString().isNotEmpty) {
        BiliBiliAccountService.instance
            .setCookie(allData["bilibili_cookie"].toString());
        await BiliBiliAccountService.instance.loadUserInfo();
      }

      SmartDialog.showToast("已成功从设备同步全部数据至手机！");
    } catch (e) {
      SmartDialog.showToast("一键导入失败: $e");
      Log.logPrint(e);
    } finally {
      SmartDialog.dismiss();
    }
  }
}
