import 'dart:convert';
import 'dsl_plugin_engine.dart';
import 'dynamic_live_site.dart';
import 'js_plugin_engine.dart';
import 'live_plugin_manifest.dart';
import 'plugin_runtime_engine.dart';

class PluginManagerCore {
  /// 创建对应的运行时引擎
  static PluginRuntimeEngine createEngine(LivePluginManifest manifest) {
    switch (manifest.type) {
      case LivePluginType.dsl:
        return DslPluginEngine(manifest);
      case LivePluginType.js:
        return JsPluginEngine(manifest);
    }
  }

  /// 加载并初始化一个插件，生成 DynamicLiveSite
  static Future<DynamicLiveSite> loadPlugin({
    required LivePluginManifest manifest,
    required String content,
  }) async {
    manifest.scriptContent = content;
    final engine = createEngine(manifest);
    await engine.init(content);
    return DynamicLiveSite(manifest: manifest, engine: engine);
  }

  /// 从完整 JSON 字符串解析并加载插件（适用于一体化 manifest + content 格式）
  static Future<DynamicLiveSite> loadPluginFromUnifiedJson(String jsonString) async {
    final Map<String, dynamic> map = jsonDecode(jsonString);
    final manifest = LivePluginManifest.fromJson(map);
    final content = map['scriptContent']?.toString() ?? map['content']?.toString() ?? jsonString;
    return loadPlugin(manifest: manifest, content: content);
  }
}

