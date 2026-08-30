import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';

class Sites {
  static final Map<String, Site> _builtinSites = {
    Constant.kBiliBili: Site(
      id: Constant.kBiliBili,
      logo: "assets/images/bilibili_2.png",
      name: "哔哩哔哩",
      liveSite: BiliBiliSite(),
    ),
    Constant.kDouyu: Site(
      id: Constant.kDouyu,
      logo: "assets/images/douyu.png",
      name: "斗鱼直播",
      liveSite: DouyuSite(),
    ),
    Constant.kHuya: Site(
      id: Constant.kHuya,
      logo: "assets/images/huya.png",
      name: "虎牙直播",
      liveSite: HuyaSite(),
    ),
    Constant.kDouyin: Site(
      id: Constant.kDouyin,
      logo: "assets/images/douyin.png",
      name: "抖音直播",
      liveSite: DouyinSite(),
    ),
  };

  static final Map<String, Site> allSites = Map.from(_builtinSites);

  static bool isBuiltinSite(String id) => _builtinSites.containsKey(id);

  static void registerPluginSite(Site site) {
    allSites[site.id] = site;
  }

  static void unregisterPluginSite(String id) {
    if (!isBuiltinSite(id)) {
      allSites.remove(id);
    }
  }

  static List<Site> get supportSites {
    return AppSettingsController.instance.siteSort
        .map((key) => allSites[key])
        .whereType<Site>()
        .toList();
  }
}

class Site {
  final String id;
  final String name;
  final String logo;
  final LiveSite liveSite;
  final bool isPlugin;
  final LivePluginManifest? manifest;

  Site({
    required this.id,
    required this.liveSite,
    required this.logo,
    required this.name,
    this.isPlugin = false,
    this.manifest,
  });
}
