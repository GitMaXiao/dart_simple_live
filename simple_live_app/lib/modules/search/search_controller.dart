import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_list_controller.dart';

class AppSearchController extends GetxController
    with GetTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;

  var searchMode = 0.obs;
  StreamSubscription<dynamic>? streamSubscription;
  StreamSubscription<dynamic>? siteSubscription;
  TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    _initTabs();

    siteSubscription = EventBus.instance.listen(
      EventBus.kSitesChanged,
      (_) => _reinitTabs(),
    );

    super.onInit();
  }

  void _initTabs() {
    var sites = Sites.supportSites;
    tabController = TabController(length: sites.isEmpty ? 1 : sites.length, vsync: this);
    tabController.animation?.addListener(_tabListener);

    for (var site in sites) {
      if (!Get.isRegistered<SearchListController>(tag: site.id)) {
        Get.put(SearchListController(site), tag: site.id);
      }
    }
  }

  void _tabListener() {
    var currentIndex = (tabController.animation?.value ?? 0).round();
    if (index == currentIndex) return;

    index = currentIndex;
    var sites = Sites.supportSites;
    if (index >= sites.length) return;

    var controller = Get.find<SearchListController>(tag: sites[index].id);
    if (controller.list.isEmpty &&
        !controller.pageEmpty.value &&
        controller.keyword.isNotEmpty) {
      controller.refreshData();
    }
  }

  void _reinitTabs() {
    try {
      tabController.animation?.removeListener(_tabListener);
      tabController.dispose();
    } catch (_) {}

    _initTabs();
    update();
  }

  void doSearch() {
    if (searchController.text.isEmpty) {
      return;
    }
    var sites = Sites.supportSites;
    for (var site in sites) {
      if (Get.isRegistered<SearchListController>(tag: site.id)) {
        var controller = Get.find<SearchListController>(tag: site.id);
        controller.clear();
        controller.keyword = searchController.text;
        controller.searchMode.value = searchMode.value;
      }
    }
    if (sites.isNotEmpty && index < sites.length) {
      var controller = Get.find<SearchListController>(tag: sites[index].id);
      controller.refreshData();
    }
  }

  @override
  void onClose() {
    streamSubscription?.cancel();
    siteSubscription?.cancel();
    try {
      tabController.animation?.removeListener(_tabListener);
      tabController.dispose();
    } catch (_) {}
    super.onClose();
  }
}
