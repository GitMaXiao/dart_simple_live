import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/category/category_controller.dart';
import 'package:simple_live_app/modules/category/category_list_view.dart';

class CategoryPage extends GetView<CategoryController> {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CategoryController>(
      builder: (ctl) {
        final sites = Sites.supportSites;
        if (sites.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text("分类")),
            body: const Center(child: Text("暂无可用直播平台")),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: TabBar(
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
          body: TabBarView(
            controller: ctl.tabController,
            children: sites
                .map(
                  (e) => CategoryListView(
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
