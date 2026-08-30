import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/services/plugin_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class PluginManagerController extends BaseController {
  RxList<LivePluginManifest> get plugins => PluginService.instance.installedPlugins;
  RxSet<String> get enabledPluginIds => PluginService.instance.enabledPluginIds;

  bool isEnabled(String id) => enabledPluginIds.contains(id);

  Future<void> togglePlugin(String id, bool enable) async {
    await PluginService.instance.togglePlugin(id, enable);
  }

  void showImportDialog() {
    final textController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text("导入插件 / 解析规则"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "支持输入远程订阅 URL（https://...）或直接粘贴插件代码/规则 JSON：",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: "https://... 或 {\"id\": \"...\", ...} 或 JS 脚本代码",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = textController.text.trim();
              if (input.isEmpty) {
                SmartDialog.showToast("请输入内容");
                return;
              }
              Get.back();
              SmartDialog.showLoading(msg: "正在解析与加载插件...");
              bool success = false;
              if (input.startsWith('http://') || input.startsWith('https://')) {
                success = await PluginService.instance.installFromUrl(input);
              } else {
                success = await PluginService.instance.installPlugin(rawContent: input);
              }
              SmartDialog.dismiss();
              if (success) {
                SmartDialog.showToast("插件安装并启用成功");
              } else {
                SmartDialog.showToast("插件安装失败，请检查规则格式");
              }
            },
            child: const Text("导入"),
          ),
        ],
      ),
    );
  }

  /// 一键加载内置示例插件（快手直播、DSL 规则示例）
  Future<void> loadPresetPlugins() async {
    SmartDialog.showLoading(msg: "正在载入示例插件...");
    try {
      final ksJson = await rootBundle.loadString("assets/plugins/kuaishou.plugin.json");
      await PluginService.instance.installPlugin(rawContent: ksJson);

      final dslJson = await rootBundle.loadString("assets/plugins/sample_dsl.plugin.json");
      await PluginService.instance.installPlugin(rawContent: dslJson);

      SmartDialog.dismiss();
      SmartDialog.showToast("示例插件载入成功");
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast("载入示例插件失败: $e");
    }
  }

  Future<void> checkUpdates() async {
    SmartDialog.showLoading(msg: "正在检查更新...");
    var updated = await PluginService.instance.checkAllUpdates();
    SmartDialog.dismiss();
    SmartDialog.showToast("检查完成，已更新 $updated 个插件");
  }

  Future<void> deletePlugin(LivePluginManifest plugin) async {
    Get.dialog(
      AlertDialog(
        title: const Text("提示"),
        content: Text("确定要删除插件【${plugin.name}】吗？"),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await PluginService.instance.deletePlugin(plugin.id);
              SmartDialog.showToast("已删除插件");
            },
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }

  void viewPluginSource(LivePluginManifest plugin) {
    Get.dialog(
      AlertDialog(
        title: Text("插件代码 - ${plugin.name}"),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: SingleChildScrollView(
            child: SelectableText(
              plugin.scriptContent ?? "// 无源代码",
              style: const TextStyle(fontFamily: "monospace", fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }
}
