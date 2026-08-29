import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/sync/local_sync/device/sync_device_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class SyncDevicePage extends GetView<SyncDeviceController> {
  const SyncDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("双向数据同步"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
        children: [
          SettingsCard(
            child: ListTile(
              leading: buildIcon(),
              title: Text(controller.info.name),
              subtitle: Text(
                  "${controller.info.type.toUpperCase()}   ${controller.info.address}"),
              trailing: FilledButton.tonalIcon(
                onPressed: () {
                  controller.pullAll();
                },
                icon: const Icon(Remix.download_2_line, size: 18),
                label: const Text("一键拉取全部"),
              ),
            ),
          ),
          AppStyle.vGap12,
          // 从设备导入至手机 (TV -> 手机)
          Padding(
            padding: AppStyle.edgeInsetsH12.copyWith(bottom: 8),
            child: Row(
              children: [
                const Icon(Remix.download_cloud_2_line, size: 18, color: Colors.blueAccent),
                AppStyle.hGap8,
                Text(
                  "从 TV/设备端 导入数据至手机",
                  style: Get.textTheme.titleSmall?.copyWith(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Remix.heart_add_line, color: Colors.pinkAccent),
                  title: const Text("从设备导入关注列表"),
                  subtitle: const Text("将 TV 端的关注主播同步到手机"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.pullFollow();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Icons.history_toggle_off, color: Colors.orangeAccent),
                  title: const Text("从设备导入观看历史"),
                  subtitle: const Text("将 TV 端的播放记录同步到手机"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.pullHistory();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.shield_check_line, color: Colors.green),
                  title: const Text("从设备导入弹幕屏蔽词"),
                  subtitle: const Text("将 TV 端的屏蔽词同步到手机"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.pullBlockedWord();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.bilibili_line, color: Colors.pink),
                  title: const Text("从设备导入哔哩哔哩账号"),
                  subtitle: const Text("将 TV 端的登录凭证同步到手机"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.pullBiliAccount();
                  },
                ),
              ],
            ),
          ),
          AppStyle.vGap12,
          // 发送数据至设备 (手机 -> TV)
          Padding(
            padding: AppStyle.edgeInsetsH12.copyWith(bottom: 8),
            child: Row(
              children: [
                const Icon(Remix.upload_cloud_2_line, size: 18, color: Colors.teal),
                AppStyle.hGap8,
                Text(
                  "从手机 发送数据至 TV/设备端",
                  style: Get.textTheme.titleSmall?.copyWith(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Remix.heart_line),
                  title: const Text("发送关注列表至设备"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncFollowAndTag();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text("发送观看记录至设备"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncHistory();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.shield_keyhole_line),
                  title: const Text("发送弹幕屏蔽词至设备"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncBlockedWord();
                  },
                ),
                AppStyle.divider,
                ListTile(
                  leading: const Icon(Remix.account_circle_line),
                  title: const Text("发送哔哩哔哩账号至设备"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    controller.syncBiliAccount();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildIcon() {
    var icon = controller.info.type.toLowerCase();

    if (icon == "android") {
      return const Icon(Remix.android_line);
    } else if (icon == "ios") {
      return const Icon(Remix.apple_line);
    } else if (icon == "tv") {
      return const Icon(Remix.tv_2_line);
    } else if (icon == "windows") {
      return const Icon(Remix.microsoft_fill);
    } else if (icon == "macos") {
      return const Icon(Remix.mac_line);
    } else if (icon == "linux") {
      return const Icon(Remix.ubuntu_line);
    } else {
      return const Icon(Remix.device_line);
    }
  }
}
