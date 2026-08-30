import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/search/search_controller.dart';
import 'package:simple_live_app/modules/search/search_list_view.dart';

class SearchPage extends GetView<AppSearchController> {
  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppSearchController>(
      builder: (ctl) {
        final sites = Sites.supportSites;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: TextField(
              controller: ctl.searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "搜点什么吧",
                border: OutlineInputBorder(
                  borderRadius: AppStyle.radius24,
                ),
                contentPadding: AppStyle.edgeInsetsH12,
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Obx(
                      () => DropdownButton<int>(
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text("房间"),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text("主播"),
                          ),
                        ],
                        value: ctl.searchMode.value,
                        onChanged: (e) {
                          ctl.searchMode.value = e ?? 0;
                          ctl.doSearch();
                        },
                      ),
                    ),
                    AppStyle.hGap8,
                  ],
                ),
                suffixIcon: IconButton(
                  onPressed: ctl.doSearch,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (e) {
                ctl.doSearch();
              },
            ),
            bottom: sites.isEmpty
                ? null
                : TabBar(
                    controller: ctl.tabController,
                    padding: EdgeInsets.zero,
                    tabAlignment: TabAlignment.center,
                    tabs: sites
                        .map(
                          (e) => Tab(
                            child: Row(
                              children: [
                                e.buildLogo(width: 24, height: 24),
                                AppStyle.hGap8,
                                Text(e.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    labelPadding: AppStyle.edgeInsetsH20,
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.label,
                  ),
          ),
          body: sites.isEmpty
              ? const Center(child: Text("暂无可用直播平台"))
              : TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: ctl.tabController,
                  children: sites
                      .map(
                        (e) => SearchListView(
                          e.id,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}
