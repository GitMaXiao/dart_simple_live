import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/home/home_controller.dart';
import 'package:simple_live_app/modules/home/home_list_view.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (ctl) {
        final sites = Sites.supportSites;
        if (sites.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text("Simple Live")),
            body: const Center(child: Text("暂无可用直播平台")),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: TabBar(
              controller: ctl.tabController,
              labelPadding: AppStyle.edgeInsetsH20,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.label,
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
            ),
            actions: [
              IconButton(
                onPressed: ctl.toSearch,
                icon: const Icon(Icons.search),
              )
            ],
          ),
          body: TabBarView(
            controller: ctl.tabController,
            children: sites
                .map(
                  (e) => HomeListView(
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
