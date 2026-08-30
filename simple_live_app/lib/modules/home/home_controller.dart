import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_list_controller.dart';
import 'package:simple_live_app/routes/route_path.dart';

class HomeController extends GetxController
    with GetTickerProviderStateMixin {
  late TabController tabController;
  StreamSubscription<dynamic>? streamSubscription;
  StreamSubscription<dynamic>? siteSubscription;

  @override
  void onInit() {
    _initTabs();

    streamSubscription = EventBus.instance.listen(
      EventBus.kBottomNavigationBarClicked,
      (index) {
        if (index == 0) {
          refreshOrScrollTop();
        }
      },
    );

    siteSubscription = EventBus.instance.listen(
      EventBus.kSitesChanged,
      (_) => _reinitTabs(),
    );

    super.onInit();
  }

  void _initTabs() {
    var sites = Sites.supportSites;
    tabController = TabController(length: sites.isEmpty ? 1 : sites.length, vsync: this);
    for (var site in sites) {
      if (!Get.isRegistered<HomeListController>(tag: site.id)) {
        Get.put(HomeListController(site), tag: site.id);
      }
    }
  }

  void _reinitTabs() {
    try {
      tabController.dispose();
    } catch (_) {}

    _initTabs();
    update();
  }

  void refreshOrScrollTop() {
    var sites = Sites.supportSites;
    if (sites.isEmpty) return;
    var tabIndex = tabController.index;
    if (tabIndex >= sites.length) tabIndex = 0;

    var controller = Get.find<HomeListController>(tag: sites[tabIndex].id);
    controller.scrollToTopOrRefresh();
  }

  void toSearch() {
    Get.toNamed(RoutePath.kSearch);
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    siteSubscription?.cancel();
    try {
      tabController.dispose();
    } catch (_) {}
    super.onClose();
  }
}
