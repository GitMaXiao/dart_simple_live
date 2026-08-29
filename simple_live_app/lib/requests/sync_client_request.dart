import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/sync_service.dart';

class SyncClientRequest {
  Future<SyncClientInfoModel> getClientInfo(SyncClinet client) async {
    var url = "http://${client.address}:${client.port}/info";
    var data = await HttpClient.instance.getJson(url);

    return SyncClientInfoModel.fromJson(data);
  }

  // ===================== 推送数据至远端设备 =====================

  Future<bool> syncFollow(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var url = "http://${client.address}:${client.port}/sync/follow";
    var data = await HttpClient.instance.postJson(
      url,
      data: body,
      queryParameters: {
        'overlay': overlay ? '1' : '0',
      },
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  Future<bool> syncTag(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var url = "http://${client.address}:${client.port}/sync/tag";
    var data = await HttpClient.instance.postJson(
      url,
      data: body,
      queryParameters: {
        'overlay': overlay ? '1' : '0',
      },
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  Future<bool> syncHistory(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var url = "http://${client.address}:${client.port}/sync/history";
    var data = await HttpClient.instance.postJson(
      url,
      data: body,
      queryParameters: {
        'overlay': overlay ? '1' : '0',
      },
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  Future<bool> syncBlockedWord(
    SyncClinet client,
    dynamic body, {
    bool overlay = false,
  }) async {
    var url = "http://${client.address}:${client.port}/sync/blocked_word";
    var data = await HttpClient.instance.postJson(
      url,
      data: body,
      queryParameters: {
        'overlay': overlay ? '1' : '0',
      },
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  Future<bool> syncBiliAccount(SyncClinet client, String cookie) async {
    var url = "http://${client.address}:${client.port}/sync/account/bilibili";
    var data = await HttpClient.instance.postJson(
      url,
      data: {
        "cookie": cookie,
      },
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  // ===================== 从远端设备拉取数据 =====================

  /// 从设备拉取关注列表
  Future<List<dynamic>> getFollow(SyncClinet client) async {
    var url = "http://${client.address}:${client.port}/export/follow";
    var data = await HttpClient.instance.getJson(url);
    if (data["status"] == true && data["data"] != null) {
      return data["data"] as List<dynamic>;
    } else {
      throw data["message"] ?? "获取关注列表失败";
    }
  }

  /// 从设备拉取播放历史
  Future<List<dynamic>> getHistory(SyncClinet client) async {
    var url = "http://${client.address}:${client.port}/export/history";
    var data = await HttpClient.instance.getJson(url);
    if (data["status"] == true && data["data"] != null) {
      return data["data"] as List<dynamic>;
    } else {
      throw data["message"] ?? "获取历史记录失败";
    }
  }

  /// 从设备拉取屏蔽词
  Future<List<dynamic>> getBlockedWord(SyncClinet client) async {
    var url = "http://${client.address}:${client.port}/export/blocked_word";
    var data = await HttpClient.instance.getJson(url);
    if (data["status"] == true && data["data"] != null) {
      return data["data"] as List<dynamic>;
    } else {
      throw data["message"] ?? "获取屏蔽词失败";
    }
  }

  /// 从设备拉取哔哩哔哩账号
  Future<Map<String, dynamic>> getBiliAccount(SyncClinet client) async {
    var url = "http://${client.address}:${client.port}/export/account/bilibili";
    var data = await HttpClient.instance.getJson(url);
    if (data["status"] == true && data["data"] != null) {
      return data["data"] as Map<String, dynamic>;
    } else {
      throw data["message"] ?? "获取账号失败";
    }
  }

  /// 从设备拉取全部数据
  Future<Map<String, dynamic>> getAll(SyncClinet client) async {
    var url = "http://${client.address}:${client.port}/export/all";
    var data = await HttpClient.instance.getJson(url);
    if (data["status"] == true && data["data"] != null) {
      return data["data"] as Map<String, dynamic>;
    } else {
      throw data["message"] ?? "获取全部数据失败";
    }
  }
}
