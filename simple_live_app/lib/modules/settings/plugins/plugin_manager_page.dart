import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/settings/plugins/plugin_manager_controller.dart';
import 'package:simple_live_app/services/plugin_service.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_core/simple_live_core.dart';

class PluginManagerPage extends GetView<PluginManagerController> {
  const PluginManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("插件与规则引擎"),
        actions: [
          IconButton(
            onPressed: controller.checkUpdates,
            icon: const Icon(Remix.refresh_line),
            tooltip: "检查更新",
          ),
          IconButton(
            onPressed: controller.showImportDialog,
            icon: const Icon(Remix.add_line),
            tooltip: "导入插件",
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'export_all') {
                controller.exportAllPlugins();
              } else if (action == 'preset') {
                controller.loadPresetPlugins();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Remix.export_line, size: 16),
                    SizedBox(width: 8),
                    Text("导出全部插件"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'preset',
                child: Row(
                  children: [
                    Icon(Remix.apps_line, size: 16),
                    SizedBox(width: 8),
                    Text("载入示例插件"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        final plugins = controller.plugins;
        return ListView(
          padding: AppStyle.edgeInsetsA12,
          children: [
            SettingsCard(
              child: Padding(
                padding: AppStyle.edgeInsetsA12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.puzzle_line, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          "在线解析插件（Plugin & Rule Engine）",
                          style: Get.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "支持通过 JavaScript 脚本沙箱或 JSON DSL 规则动态加载与更新直播站点，无需重新安装 App 即可修复平台接口变更。",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: controller.showImportDialog,
                            icon: const Icon(Remix.download_cloud_line, size: 16),
                            label: const Text("导入插件 / 订阅"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: controller.loadPresetPlugins,
                          icon: const Icon(Remix.apps_line, size: 16),
                          label: const Text("示例插件"),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: controller.exportAllPlugins,
                          icon: const Icon(Remix.export_line, size: 16),
                          tooltip: "导出全部插件",
                        ),
                        const SizedBox(width: 4),
                        IconButton.outlined(
                          onPressed: controller.checkUpdates,
                          icon: const Icon(Remix.refresh_line, size: 16),
                          tooltip: "检查更新",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: AppStyle.edgeInsetsA12.copyWith(top: 20, bottom: 8),
              child: Text(
                "已安装插件 (${plugins.length})",
                style: Get.textTheme.titleSmall,
              ),
            ),
            if (plugins.isEmpty)
              SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Remix.inbox_line, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          "暂无已安装的插件",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: controller.loadPresetPlugins,
                              child: const Text("一键载入示例插件"),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: controller.showImportDialog,
                              child: const Text("手动导入插件"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SettingsCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: plugins.length,
                  separatorBuilder: (context, index) => AppStyle.divider,
                  itemBuilder: (context, index) {
                    final item = plugins[index];
                    return Obx(() {
                      final enabled = controller.isEnabled(item.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: Text(
                            item.type == LivePluginType.dsl ? "DSL" : "JS",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "v${item.version}",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.description,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "ID: ${item.id}${item.author.isNotEmpty ? ' · 作者: ${item.author}' : ''}",
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: enabled,
                              onChanged: (val) => controller.togglePlugin(item.id, val),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'view') {
                                  controller.viewPluginSource(item);
                                } else if (action == 'export') {
                                  controller.exportPlugin(item);
                                } else if (action == 'update') {
                                  PluginService.instance.updatePlugin(item.id);
                                } else if (action == 'delete') {
                                  controller.deletePlugin(item);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Remix.code_line, size: 16),
                                      SizedBox(width: 8),
                                      Text("查看规则/代码"),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'export',
                                  child: Row(
                                    children: [
                                      Icon(Remix.export_line, size: 16),
                                      SizedBox(width: 8),
                                      Text("导出插件"),
                                    ],
                                  ),
                                ),
                                if (item.updateUrl != null && item.updateUrl!.isNotEmpty)
                                  const PopupMenuItem(
                                    value: 'update',
                                    child: Row(
                                      children: [
                                        Icon(Remix.refresh_line, size: 16),
                                        SizedBox(width: 8),
                                        Text("检查更新"),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Remix.delete_bin_line, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text("删除插件", style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    });
                  },
                ),
              ),
          ],
        );
      }),
    );
  }
}
