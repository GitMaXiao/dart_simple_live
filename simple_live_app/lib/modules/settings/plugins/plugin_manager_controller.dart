import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:remixicon/remixicon.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/utils.dart';
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

  /// 导出单个插件
  void exportPlugin(LivePluginManifest plugin) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(plugin.toJson());
    Get.dialog(
      SimpleDialog(
        title: Text("导出插件 - ${plugin.name}"),
        children: [
          ListTile(
            leading: const Icon(Remix.clipboard_line),
            title: const Text("复制完整 JSON 到剪贴板"),
            subtitle: const Text("包含清单配置与源码"),
            onTap: () {
              Get.back();
              Utils.copyToClipboard(jsonStr);
              SmartDialog.showToast("已复制插件 JSON 到剪贴板");
            },
          ),
          if (plugin.scriptContent != null && plugin.scriptContent!.isNotEmpty)
            ListTile(
              leading: const Icon(Remix.file_code_line),
              title: const Text("复制脚本/规则源码"),
              subtitle: const Text("仅复制 JS 脚本或 DSL 规则内容"),
              onTap: () {
                Get.back();
                Utils.copyToClipboard(plugin.scriptContent!);
                SmartDialog.showToast("已复制源码到剪贴板");
              },
            ),
          ListTile(
            leading: const Icon(Remix.download_line),
            title: const Text("保存/分享为文件"),
            subtitle: Text("${plugin.id}.plugin.json"),
            onTap: () async {
              Get.back();
              await _saveOrShareFile(
                fileName: "${plugin.id}.plugin.json",
                content: jsonStr,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 批量导出所有插件
  Future<void> exportAllPlugins() async {
    if (plugins.isEmpty) {
      SmartDialog.showToast("当前暂无安装的插件可导出");
      return;
    }

    final data = {
      "name": "Simple Live 插件备份",
      "version": "1.0.0",
      "exportTime": DateTime.now().toIso8601String(),
      "plugins": plugins.map((e) => e.toJson()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    Get.dialog(
      SimpleDialog(
        title: const Text("导出全部插件"),
        children: [
          ListTile(
            leading: const Icon(Remix.clipboard_line),
            title: const Text("复制全部插件 JSON 到剪贴板"),
            subtitle: Text("共 ${plugins.length} 个插件"),
            onTap: () {
              Get.back();
              Utils.copyToClipboard(jsonStr);
              SmartDialog.showToast("已复制全部插件到剪贴板");
            },
          ),
          ListTile(
            leading: const Icon(Remix.download_line),
            title: const Text("保存/分享为备份文件"),
            subtitle: const Text("simple_live_plugins_backup.json"),
            onTap: () async {
              Get.back();
              await _saveOrShareFile(
                fileName: "simple_live_plugins_backup.json",
                content: jsonStr,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 内部文件保存或分享辅助方法
  Future<void> _saveOrShareFile({
    required String fileName,
    required String content,
  }) async {
    try {
      SmartDialog.showLoading(msg: "正在导出文件...");
      final bytes = Uint8List.fromList(utf8.encode(content));

      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        SmartDialog.dismiss();
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/json', name: fileName)],
          subject: 'Simple Live 插件导出',
        ));
        SmartDialog.showToast("已调起分享/保存");
        return;
      }

      var path = await FilePicker.platform.saveFile(
        allowedExtensions: ['json'],
        type: FileType.custom,
        fileName: fileName,
        bytes: bytes,
      );

      SmartDialog.dismiss();
      if (path != null) {
        SmartDialog.showToast("文件已保存至: $path");
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast("导出失败: $e");
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
            onPressed: () {
              if (plugin.scriptContent != null) {
                Utils.copyToClipboard(plugin.scriptContent!);
                SmartDialog.showToast("已复制代码");
              }
            },
            child: const Text("复制代码"),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }
}
