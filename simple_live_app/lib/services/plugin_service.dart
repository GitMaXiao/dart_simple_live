import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class PluginService extends GetxService {
  static PluginService get instance => Get.find<PluginService>();

  static const String kInstalledPluginsKey = "InstalledPlugins";
  static const String kEnabledPluginsKey = "EnabledPlugins";

  final RxList<LivePluginManifest> installedPlugins = <LivePluginManifest>[].obs;
  final RxSet<String> enabledPluginIds = <String>{}.obs;

  // 保存插件 ID 到 DynamicLiveSite 实例的映射
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

    List<LivePluginManifest> list = [];
    for (var item in pluginJsonList) {
      try {
        if (item is String) {
          var map = jsonDecode(item) as Map<String, dynamic>;
          list.add(LivePluginManifest.fromJson(map));
        } else if (item is Map) {
          list.add(LivePluginManifest.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (e) {
        Log.e("Error parsing plugin storage item: $e", StackTrace.current);
      }
    }

    installedPlugins.value = list;
  }

  Future<void> _saveToStorage() async {
    final listJson = installedPlugins.map((e) => jsonEncode(e.toJson())).toList();
    LocalStorageService.instance.setValue(kInstalledPluginsKey, listJson);
    LocalStorageService.instance.setValue(
      kEnabledPluginsKey,
      enabledPluginIds.toList(),
    );
  }

  /// 加载所有已启用的插件
  Future<void> _loadAllEnabledPlugins() async {
    for (var manifest in installedPlugins) {
      if (enabledPluginIds.contains(manifest.id)) {
        await _activatePlugin(manifest);
      }
    }
  }

  /// 激活并注册单个插件到 Sites
  Future<bool> _activatePlugin(LivePluginManifest manifest) async {
    try {
      var scriptContent = manifest.scriptContent ?? '';
      if (scriptContent.isEmpty) {
        Log.w("Plugin ${manifest.id} has empty script content, skipping activation");
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

  /// 安装/导入插件（传入 JSON 或 JS 代码）
  Future<bool> installPlugin({
    required String rawContent,
    String? sourceUrl,
  }) async {
    try {
      rawContent = rawContent.trim();
      LivePluginManifest manifest;
      String scriptContent = '';

      if (rawContent.startsWith('{') && rawContent.endsWith('}')) {
        // Unified JSON format: contains manifest and scriptContent/content
        final Map<String, dynamic> map = jsonDecode(rawContent);
        manifest = LivePluginManifest.fromJson(map);
        scriptContent = map['scriptContent']?.toString() ??
            map['content']?.toString() ??
            rawContent;
      } else {
        // Plain JS script or DSL
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

      // 检查是否已有同名插件，若有则替换
      installedPlugins.removeWhere((e) => e.id == manifest.id);
      installedPlugins.add(manifest);

      // 默认启用新安装的插件
      enabledPluginIds.add(manifest.id);
      await _saveToStorage();

      _deactivatePlugin(manifest.id);
      final success = await _activatePlugin(manifest);

      if (success) {
        AppSettingsController.instance.initSiteSort();
      }

      return success;
    } catch (e, s) {
      Log.e("Install plugin failed: $e", s);
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
    installedPlugins.removeWhere((e) => e.id == id);
    _deactivatePlugin(id);
    await _saveToStorage();
    AppSettingsController.instance.initSiteSort();
  }
}
