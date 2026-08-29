import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/notification_service.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'dart:io';

class FollowSettingsPage extends GetView<AppSettingsController> {
  const FollowSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("关注设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsSwitch(
                    value: controller.autoUpdateFollowEnable.value,
                    title: "自动更新关注直播状态",
                    onChanged: (e) {
                      controller.setAutoUpdateFollowEnable(e);
                      FollowService.instance.initTimer();
                    },
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: controller.autoUpdateFollowEnable.value,
                    child: AppStyle.divider,
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: controller.autoUpdateFollowEnable.value,
                    child: SettingsAction(
                      title: "自动更新间隔",
                      value:
                          "${controller.autoUpdateFollowDuration.value ~/ 60}小时${controller.autoUpdateFollowDuration.value % 60}分钟",
                      onTap: () {
                        setTimer(context);
                      },
                    ),
                  ),
                ),
                AppStyle.divider,
                Obx(
                  () {
                    var threadCount = controller.updateFollowThreadCount.value;
                    var displayValue = threadCount == 0
                        ? "自动 (根据 CPU 核心数)"
                        : "$threadCount";

                    return SettingsAction(
                      title: "更新并发数",
                      subtitle: "0 = 自动根据 CPU 核心数优化（推荐），或手动设置 1-20",
                      value: displayValue,
                      onTap: () {
                        showConcurrencyDialog();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          AppStyle.vGap12,
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsSwitch(
                    value: controller.liveNotificationEnable.value,
                    title: "开播桌面通知提醒",
                    subtitle: "开启后，在关注列表中被标为提醒的主播开播时弹出系统通知",
                    onChanged: (e) {
                      controller.setLiveNotificationEnable(e);
                    },
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: controller.liveNotificationEnable.value,
                    child: Column(
                      children: [
                        AppStyle.divider,
                        SettingsSwitch(
                          value: controller.autoEnableNotifyOnFollow.value,
                          title: "关注主播时默认开启提醒",
                          subtitle: "新关注主播时自动开启开播通知",
                          onChanged: (e) {
                            controller.setAutoEnableNotifyOnFollow(e);
                          },
                        ),
                        AppStyle.divider,
                        SettingsAction(
                          title: "一键开启全部主播提醒",
                          subtitle: "将当前关注列表中的所有主播全部开启开播提醒",
                          onTap: () async {
                            var confirm = await Utils.showAlertDialog(
                              "确定要为关注列表中的全部主播开启开播提醒吗？",
                              title: "一键开启提醒",
                            );
                            if (confirm) {
                              FollowService.instance.enableAllNotify();
                            }
                          },
                        ),
                        AppStyle.divider,
                        SettingsAction(
                          title: "一键关闭全部主播提醒",
                          subtitle: "将当前所有已开启提醒的主播全部关闭",
                          onTap: () async {
                            var confirm = await Utils.showAlertDialog(
                              "确定要关闭所有关注主播的开播提醒吗？",
                              title: "一键关闭提醒",
                            );
                            if (confirm) {
                              FollowService.instance.disableAllNotify();
                            }
                          },
                        ),
                        AppStyle.divider,
                        SettingsAction(
                          title: "发送测试通知",
                          subtitle: "测试手机系统通知渠道与权限是否正常运行",
                          onTap: () {
                            NotificationService.instance.showTestNotification();
                          },
                        ),
                        AppStyle.divider,
                        SettingsAction(
                          title: "系统通知权限管理",
                          subtitle: "前往系统设置管理应用的通知权限与横幅样式",
                          onTap: () {
                            NotificationService.instance
                                .openNotificationSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void setTimer(BuildContext context) async {
    var value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.autoUpdateFollowDuration.value ~/ 60,
        minute: controller.autoUpdateFollowDuration.value % 60,
      ),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (_, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    if (value == null || (value.hour == 0 && value.minute == 0)) {
      return;
    }
    var duration = Duration(hours: value.hour, minutes: value.minute);
    controller.setAutoUpdateFollowDuration(duration.inMinutes);
    FollowService.instance.initTimer();
  }

  void showConcurrencyDialog() {
    var currentValue = controller.updateFollowThreadCount.value;
    var cpuCount = Platform.numberOfProcessors;
    var autoValue = (cpuCount * 2.5).round().clamp(4, 20);

    Get.dialog(
      AlertDialog(
        title: const Text("设置更新并发数"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CPU 核心数: $cpuCount",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              "自动推荐值: $autoValue",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              "选择并发数：",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            // 快捷选项
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickOption(0, "自动 ($autoValue)", currentValue),
                _buildQuickOption(4, "4", currentValue),
                _buildQuickOption(8, "8", currentValue),
                _buildQuickOption(12, "12", currentValue),
                _buildQuickOption(16, "16", currentValue),
                _buildQuickOption(20, "20", currentValue),
              ],
            ),
            const SizedBox(height: 16),
            // 自定义输入
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "自定义 (1-20)",
                border: OutlineInputBorder(),
                hintText: "输入 1-20 之间的数字",
              ),
              onSubmitted: (value) {
                var num = int.tryParse(value);
                if (num != null && num >= 0 && num <= 20) {
                  controller.setUpdateFollowThreadCount(num);
                  Get.back();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOption(int value, String label, int currentValue) {
    var isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          controller.setUpdateFollowThreadCount(value);
          Get.back();
        }
      },
    );
  }
}
