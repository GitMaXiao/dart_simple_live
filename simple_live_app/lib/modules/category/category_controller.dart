import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';

class CategoryController extends GetxController
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
        if (index == 2) {
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
      if (!Get.isRegistered<CategoryListController>(tag: site.id)) {
        Get.put(CategoryListController(site), tag: site.id);
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

    var controller = Get.find<CategoryListController>(tag: sites[tabIndex].id);
    controller.scrollToTopOrRefresh();
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
