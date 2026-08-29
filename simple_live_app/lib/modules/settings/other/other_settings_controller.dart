import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:path/path.dart' as p;
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class OtherSettingsController extends BaseController {
  RxList<LogFileModel> logFiles = <LogFileModel>[].obs;

  var videoOutputDrivers = {
    "gpu": "gpu",
    "gpu-next": "gpu-next",
    "xv": "xv (X11 only)",
    "x11": "x11 (X11 only)",
    "vdpau": "vdpau (X11 only)",
    "direct3d": "direct3d (Windows only)",
    "sdl": "sdl",
    "dmabuf-wayland": "dmabuf-wayland",
    "vaapi": "vaapi",
    "null": "null",
    "libmpv": "libmpv",
    "mediacodec_embed": "mediacodec_embed (Android only)",
  };

  var audioOutputDrivers = {
    "null": "null (No audio output)",
    "pulse": "pulse (Linux, uses PulseAudio)",
    "pipewire": "pipewire (Linux, via Pulse compatibility or native)",
    "alsa": "alsa (Linux only)",
    "oss": "oss (Linux only)",
    "jack": "jack (Linux/macOS, low-latency audio)",
    "directsound": "directsound (Windows only)",
    "wasapi": "wasapi (Windows only)",
    "winmm": "winmm (Windows only, legacy API)",
    "audiounit": "audiounit (iOS only)",
    "coreaudio": "coreaudio (macOS only)",
    "opensles": "opensles (Android only)",
    "audiotrack": "audiotrack (Android only)",
    "aaudio": "aaudio (Android only)",
    "pcm": "pcm (Cross-platform)",
    "sdl": "sdl (Cross-platform, via SDL library)",
    "openal": "openal (Cross-platform, OpenAL backend)",
    "libao": "libao (Cross-platform, uses libao library)",
    "auto": "auto (Not available)"
  };

  var hardwareDecoder = {
    "no": "no",
    "auto": "auto",
    "auto-safe": "auto-safe",
    "yes": "yes",
    "auto-copy": "auto-copy",
    "d3d11va": "d3d11va",
    "d3d11va-copy": "d3d11va-copy",
    "videotoolbox": "videotoolbox",
    "videotoolbox-copy": "videotoolbox-copy",
    "vaapi": "vaapi",
    "vaapi-copy": "vaapi-copy",
    "nvdec": "nvdec",
    "nvdec-copy": "nvdec-copy",
    "drm": "drm",
    "drm-copy": "drm-copy",
    "vulkan": "vulkan",
    "vulkan-copy": "vulkan-copy",
    "dxva2": "dxva2",
    "dxva2-copy": "dxva2-copy",
    "vdpau": "vdpau",
    "vdpau-copy": "vdpau-copy",
    "mediacodec": "mediacodec",
    "mediacodec-copy": "mediacodec-copy",
    "cuda": "cuda",
    "cuda-copy": "cuda-copy",
    "crystalhd": "crystalhd",
    "rkmpp": "rkmpp"
  };

  @override
  void onInit() {
    loadLogFiles();
    super.onInit();
  }

  void setLogEnable(e) {
    AppSettingsController.instance.setLogEnable(e);
    if (e) {
      Log.initWriter();
      Future.delayed(const Duration(milliseconds: 100), () {
        loadLogFiles();
      });
    } else {
      Log.disposeWriter();
    }
  }

  void loadLogFiles() async {
    var supportDir = await getApplicationSupportDirectory();
    var logDir = Directory("${supportDir.path}/log");
    if (!await logDir.exists()) {
      await logDir.create();
    }
    logFiles.clear();
    await logDir.list().forEach((element) {
      var file = element as File;
      var name = p.basename(file.path);
      var time = file.lastModifiedSync();
      var size = file.lengthSync();
      logFiles.add(LogFileModel(name, file.path, time, size));
    });
    //logFiles 名称倒序
    logFiles.sort((a, b) => b.time.compareTo(a.time));
  }

  void cleanLog() async {
    if (AppSettingsController.instance.logEnable.value) {
      SmartDialog.showToast("请先关闭日志记录");
      return;
    }

    var supportDir = await getApplicationSupportDirectory();
    var logDir = Directory("${supportDir.path}/log");
    if (await logDir.exists()) {
      await logDir.delete(recursive: true);
    }
    loadLogFiles();
  }

  void shareLogFile(LogFileModel item) {
    SharePlus.instance.share(ShareParams(
      files: [XFile(item.path)],
    ));
  }

  void saveLogFile(LogFileModel item) async {
    var filePath = await FilePicker.platform.saveFile(
      allowedExtensions: ['log'],
      type: FileType.custom,
      fileName: item.name,
      bytes: Uint8List(0),
    );
    if (filePath != null) {
      var file = File(item.path);
      await file.copy(filePath);
      SmartDialog.showToast("保存成功");
    }
  }

  void exportConfig() async {
    try {
      SmartDialog.showLoading(msg: "正在导出配置...");
      // 组装数据
      var data = {
        "type": "simple_live",
        "platform": Platform.operatingSystem,
        "version": 1,
        "time": DateTime.now().millisecondsSinceEpoch,
        "config": LocalStorageService.instance.settingsBox.toMap(),
        "shield": LocalStorageService.instance.shieldBox.toMap(),
      };

      var jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      var bytes = Uint8List.fromList(utf8.encode(jsonStr));

      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/simple_live_config_${DateTime.now().millisecondsSinceEpoch}.json');
        await file.writeAsBytes(bytes);
        SmartDialog.dismiss();
        await SharePlus.instance.share(ShareParams(
          files: [
            XFile(file.path,
                mimeType: 'application/json', name: 'simple_live_config.json')
          ],
          subject: 'Simple Live 配置文件备份',
        ));
        SmartDialog.showToast("已调起分享/保存");
        return;
      }

      var path = await FilePicker.platform.saveFile(
        allowedExtensions: ['json'],
        type: FileType.custom,
        fileName: "simple_live_config.json",
        bytes: bytes,
      );

      SmartDialog.dismiss();
      if (path == null) {
        SmartDialog.showToast("保存取消");
        return;
      }

      var file = File(path);
      await file.writeAsBytes(bytes);
      SmartDialog.showToast("导出成功");
    } catch (e) {
      SmartDialog.dismiss();
      Log.logPrint(e);
      SmartDialog.showToast("导出失败:$e");
    }
  }

  void importConfig() async {
    try {
      var file = await FilePicker.platform.pickFiles(
        allowedExtensions: ['json'],
        type: FileType.custom,
        withData: true,
      );
      if (file == null || file.files.isEmpty) {
        return;
      }

      String content = "";
      final singleFile = file.files.single;
      if (singleFile.bytes != null && singleFile.bytes!.isNotEmpty) {
        content = utf8.decode(singleFile.bytes!);
      } else if (singleFile.path != null && singleFile.path!.isNotEmpty) {
        content = await File(singleFile.path!).readAsString();
      }

      if (content.trim().isEmpty) {
        SmartDialog.showToast("文件内容为空或无法读取");
        return;
      }

      var data = jsonDecode(content);
      if (data is! Map || data["type"] != "simple_live") {
        SmartDialog.showToast("不支持的配置文件格式");
        return;
      }

      // 检查platform
      if (data["platform"] != Platform.operatingSystem &&
          !await Utils.showAlertDialog("导入配置文件来源平台不一致，是否继续导入?",
              title: "平台不匹配")) {
        return;
      }

      SmartDialog.showLoading(msg: "正在导入配置...");

      // 安全导入 settingsBox
      if (data["config"] != null && data["config"] is Map) {
        await LocalStorageService.instance.settingsBox.clear();
        final configMap = data["config"] as Map;
        for (var entry in configMap.entries) {
          await LocalStorageService.instance.settingsBox
              .put(entry.key, entry.value);
        }
      }

      // 安全导入 shieldBox
      if (data["shield"] != null && data["shield"] is Map) {
        await LocalStorageService.instance.shieldBox.clear();
        final shieldMap = data["shield"] as Map;
        for (var entry in shieldMap.entries) {
          await LocalStorageService.instance.shieldBox
              .put(entry.key.toString(), entry.value.toString());
        }
      }

      SmartDialog.dismiss();
      SmartDialog.showToast("导入成功，重启应用后生效");
    } catch (e, stackTrace) {
      SmartDialog.dismiss();
      Log.e("配置导入失败: $e", stackTrace);
      SmartDialog.showToast("导入失败: $e");
    }
  }

  void resetDefaultConfig() {
    Utils.showAlertDialog("是否重置所有配置为默认值?").then((value) {
      if (value) {
        LocalStorageService.instance.settingsBox.clear();
        LocalStorageService.instance.shieldBox.clear();
        SmartDialog.showToast("重置成功,重启生效");
      }
    });
  }
}

class LogFileModel {
  late String name;
  late String path;
  late DateTime time;
  late int size;
  LogFileModel(this.name, this.path, this.time, this.size);
}
