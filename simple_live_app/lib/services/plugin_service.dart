import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class PluginService extends GetxService {
  static PluginService get instance => Get.find<PluginService>();

  static const String kInstalledPluginsKey = "InstalledPlugins";
  static const String kEnabledPluginsKey = "EnabledPlugins";

  /// 当前已安装的插件清单列表
  final RxList<LivePluginManifest> installedPlugins = <LivePluginManifest>[].obs;

  /// 已启用的插件 ID 列表
  final RxSet<String> enabledPluginIds = <String>{}.obs;

  /// 运行时已激活的 DynamicLiveSite 缓存
  final Map<String, DynamicLiveSite> _activeSites = {};

  Future<PluginService> init() async {
    try {
      _loadFromStorage();
      await _loadAllEnabledPlugins();
    } catch (e, s) {
      Log.e("PluginService init failed: $e", s);
    }
    return this;
  }

  void _loadFromStorage() {
    // 读取已启用的插件 ID 集合
    final enabledList = LocalStorageService.instance.getValue<List<dynamic>>(
      kEnabledPluginsKey,
      [],
    );
    enabledPluginIds.assignAll(enabledList.map((e) => e.toString()).toSet());

    // 读取已安装的插件清单与代码列表
    final pluginJsonList = LocalStorageService.instance.getValue<List<dynamic>>(
      kInstalledPluginsKey,
      [],
    );

    installedPlugins.clear();
    for (var item in pluginJsonList) {
      try {
        if (item is String) {
          installedPlugins.add(LivePluginManifest.fromJson(jsonDecode(item)));
        } else if (item is Map) {
          installedPlugins.add(LivePluginManifest.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (e, s) {
        Log.e("Failed to decode stored plugin: $e", s);
      }
    }
  }

  Future<void> _saveToStorage() async {
    final list = installedPlugins.map((e) => e.toJson()).toList();
    await LocalStorageService.instance.setValue(kInstalledPluginsKey, list);
    await LocalStorageService.instance.setValue(kEnabledPluginsKey, enabledPluginIds.toList());
  }

  /// 启动时激活所有已启用的插件
  Future<void> _loadAllEnabledPlugins() async {
    for (var manifest in installedPlugins) {
      if (enabledPluginIds.contains(manifest.id)) {
        await _activatePlugin(manifest);
      }
    }
    AppSettingsController.instance.initSiteSort();
    EventBus.instance.emit(EventBus.kSitesChanged, null);
  }

  /// 激活单个插件并注册到 Sites 全局列表
  Future<bool> _activatePlugin(LivePluginManifest manifest) async {
    try {
      final scriptContent = manifest.scriptContent ?? '';
      if (scriptContent.isEmpty) {
        Log.w("Plugin ${manifest.id} scriptContent is empty");
        return false;
      }

      final dynamicSite = await PluginManagerCore.loadPlugin(
        manifest: manifest,
        content: scriptContent,
      );

      _activeSites[manifest.id] = dynamicSite;

      final site = Site(
        id: manifest.id,
        name: manifest.name,
        logo: manifest.icon ?? "assets/images/logo.png",
        liveSite: dynamicSite,
        isPlugin: true,
        manifest: manifest,
      );

      Sites.registerPluginSite(site);
      return true;
    } catch (e, s) {
      Log.e("Failed to activate plugin ${manifest.id}: $e", s);
      return false;
    }
  }

  /// 卸载/注销单个插件
  void _deactivatePlugin(String id) {
    var dynamicSite = _activeSites.remove(id);
    dynamicSite?.dispose();
    Sites.unregisterPluginSite(id);
  }

  /// 安装/导入插件（支持 Unified JSON、DSL 规则、纯 JS 脚本或批量备份 JSON）
  Future<bool> installPlugin({
    required String rawContent,
    String? sourceUrl,
  }) async {
    try {
      rawContent = rawContent.trim();
      if (rawContent.isEmpty) return false;

      // 1. 检查是否为包含多个插件的备份/订阅列表 JSON
      if (rawContent.startsWith('{') && rawContent.endsWith('}')) {
        try {
          final Map<String, dynamic> map = jsonDecode(rawContent);
          if (map.containsKey('plugins') && map['plugins'] is List) {
            int successCount = 0;
            for (var p in (map['plugins'] as List)) {
              var pJson = jsonEncode(p);
              var ok = await _installSinglePlugin(rawContent: pJson, sourceUrl: sourceUrl);
              if (ok) successCount++;
            }
            if (successCount > 0) {
              await _saveToStorage();
              AppSettingsController.instance.initSiteSort();
              EventBus.instance.emit(EventBus.kSitesChanged, null);
              return true;
            }
            return false;
          }
        } catch (_) {}
      }

      // 2. 安装单个插件
      final ok = await _installSinglePlugin(rawContent: rawContent, sourceUrl: sourceUrl);
      if (ok) {
        await _saveToStorage();
        AppSettingsController.instance.initSiteSort();
        EventBus.instance.emit(EventBus.kSitesChanged, null);
      }
      return ok;
    } catch (e, s) {
      Log.e("Install plugin failed: $e", s);
      return false;
    }
  }

  Future<bool> _installSinglePlugin({
    required String rawContent,
    String? sourceUrl,
  }) async {
    try {
      LivePluginManifest manifest;
      String scriptContent = '';

      if (rawContent.startsWith('{') && rawContent.endsWith('}')) {
        final Map<String, dynamic> map = jsonDecode(rawContent);

        bool isDirectDsl = map.containsKey('categories') ||
            map.containsKey('recommendRooms') ||
            map.containsKey('roomDetail') ||
            map.containsKey('playUrls') ||
            map.containsKey('playQualities');

        if (map['type'] == 'dsl' || (map['type'] == null && isDirectDsl)) {
          var id = map['id']?.toString() ?? "dsl_${DateTime.now().millisecondsSinceEpoch}";
          var name = map['name']?.toString() ?? "自定义DSL规则";
          scriptContent = map['scriptContent']?.toString() ?? rawContent;
          manifest = LivePluginManifest(
            id: id,
            name: name,
            version: map['version']?.toString() ?? "1.0.0",
            type: LivePluginType.dsl,
            author: map['author']?.toString() ?? "User",
            description: map['description']?.toString() ?? "DSL规则插件",
            updateUrl: map['updateUrl']?.toString() ?? sourceUrl,
            scriptContent: scriptContent,
          );
        } else {
          manifest = LivePluginManifest.fromJson(map);
          scriptContent = map['scriptContent']?.toString() ??
              map['content']?.toString() ??
              rawContent;
          manifest.scriptContent = scriptContent;
        }
      } else {
        // 纯 JS 脚本文本 (如 SimpleLive.registerSite({...}))
        var idMatch = RegExp(r'''id\s*:\s*["']([^"']+)["']''').firstMatch(rawContent);
        var nameMatch = RegExp(r'''name\s*:\s*["']([^"']+)["']''').firstMatch(rawContent);
        var id = idMatch?.group(1) ?? "custom_plugin_${DateTime.now().millisecondsSinceEpoch}";
        var name = nameMatch?.group(1) ?? "自定义插件";

        manifest = LivePluginManifest(
          id: id,
          name: name,
          version: "1.0.0",
          type: LivePluginType.js,
          author: "User",
          description: "本地导入脚本",
          updateUrl: sourceUrl,
          scriptContent: rawContent,
        );
        scriptContent = rawContent;
      }

      manifest.scriptContent = scriptContent;

      // 替换或新增
      installedPlugins.removeWhere((e) => e.id == manifest.id);
      installedPlugins.add(manifest);

      // 默认启用
      enabledPluginIds.add(manifest.id);

      _deactivatePlugin(manifest.id);
      final success = await _activatePlugin(manifest);
      return success;
    } catch (e, s) {
      Log.e("_installSinglePlugin error: $e", s);
      return false;
    }
  }

  /// 从远程 URL 导入/订阅插件
  Future<bool> installFromUrl(String url) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.get(url, options: Options(responseType: ResponseType.plain));
      final content = response.data.toString();
      return await installPlugin(rawContent: content, sourceUrl: url);
    } catch (e, s) {
      Log.e("Download plugin from url failed ($url): $e", s);
      return false;
    }
  }

  /// 切换插件启用状态
  Future<void> togglePlugin(String id, bool enable) async {
    final manifest = installedPlugins.firstWhereOrNull((e) => e.id == id);
    if (manifest == null) return;

    if (enable) {
      enabledPluginIds.add(id);
      await _activatePlugin(manifest);
    } else {
      enabledPluginIds.remove(id);
      _deactivatePlugin(id);
    }

    await _saveToStorage();
    AppSettingsController.instance.initSiteSort();
    EventBus.instance.emit(EventBus.kSitesChanged, null);
  }

  /// 检查并更新单个插件
  Future<bool> updatePlugin(String id) async {
    final manifest = installedPlugins.firstWhereOrNull((e) => e.id == id);
    if (manifest == null || manifest.updateUrl == null || manifest.updateUrl!.isEmpty) {
      return false;
    }

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.get(manifest.updateUrl!, options: Options(responseType: ResponseType.plain));
      final content = response.data.toString();
      return await installPlugin(rawContent: content, sourceUrl: manifest.updateUrl);
    } catch (e, s) {
      Log.e("Update plugin failed for $id: $e", s);
      return false;
    }
  }

  /// 检查所有插件更新
  Future<int> checkAllUpdates() async {
    int updatedCount = 0;
    for (var plugin in List.of(installedPlugins)) {
      if (plugin.updateUrl != null && plugin.updateUrl!.isNotEmpty) {
        var updated = await updatePlugin(plugin.id);
        if (updated) updatedCount++;
      }
    }
    return updatedCount;
  }

  /// 删除已安装的插件
  Future<void> deletePlugin(String id) async {
    enabledPluginIds.remove(id);
    _deactivatePlugin(id);
    installedPlugins.removeWhere((e) => e.id == id);
    await _saveToStorage();
    AppSettingsController.instance.initSiteSort();
    EventBus.instance.emit(EventBus.kSitesChanged, null);
  }
}
