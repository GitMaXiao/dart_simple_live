import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class MultiViewSelectResult {
  final Site site;
  final String roomId;
  final String title;
  final String? userName;
  final String? cover;

  MultiViewSelectResult({
    required this.site,
    required this.roomId,
    required this.title,
    this.userName,
    this.cover,
  });
}

class MultiViewSelectDialog extends StatefulWidget {
  const MultiViewSelectDialog({super.key});

  static Future<MultiViewSelectResult?> show() async {
    return await Get.bottomSheet<MultiViewSelectResult?>(
      const MultiViewSelectDialog(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<MultiViewSelectDialog> createState() => _MultiViewSelectDialogState();
}

class _MultiViewSelectDialogState extends State<MultiViewSelectDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Site _selectedSite = Sites.allSites.values.first;
  bool _isSearching = false;
  List<LiveRoomItem> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectFollow(FollowUser user) {
    var site = Sites.allSites[user.siteId];
    if (site == null) {
      SmartDialog.showToast("不支持的直播平台");
      return;
    }
    Get.back(
      result: MultiViewSelectResult(
        site: site,
        roomId: user.roomId,
        title: user.userName,
        userName: user.userName,
        cover: user.face,
      ),
    );
  }

  void _onSelectHistory(History history) {
    var site = Sites.allSites[history.siteId];
    if (site == null) {
      SmartDialog.showToast("不支持的直播平台");
      return;
    }
    Get.back(
      result: MultiViewSelectResult(
        site: site,
        roomId: history.roomId,
        title: history.userName,
        userName: history.userName,
        cover: history.face,
      ),
    );
  }

  void _parseUrlOrRoomId() async {
    String input = _urlController.text.trim();
    if (input.isEmpty) {
      SmartDialog.showToast("请输入直播间链接或房间号");
      return;
    }

    // 检查是否为直连 URL
    if (input.startsWith("http://") || input.startsWith("https://")) {
      try {
        SmartDialog.showLoading(msg: "正在解析链接...");
        for (var site in Sites.allSites.values) {
          try {
            var detail = await site.liveSite.getRoomDetail(roomId: input);
            SmartDialog.dismiss();
            Get.back(
              result: MultiViewSelectResult(
                site: site,
                roomId: detail.roomId,
                title: detail.title,
                userName: detail.userName,
                cover: detail.cover,
              ),
            );
            return;
          } catch (_) {}
        }
        SmartDialog.dismiss();
        SmartDialog.showToast("未能从链接解析出有效直播间");
      } catch (e) {
        SmartDialog.dismiss();
        SmartDialog.showToast("解析失败: $e");
      }
    } else {
      // 纯房间号
      Get.back(
        result: MultiViewSelectResult(
          site: _selectedSite,
          roomId: input,
          title: "${_selectedSite.name} - $input",
        ),
      );
    }
  }

  void _doSearch() async {
    String keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      var result = await _selectedSite.liveSite.searchRooms(keyword, page: 1);
      setState(() {
        _searchResults = result.items;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      SmartDialog.showToast("搜索失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsH16,
            child: Row(
              children: [
                Text(
                  "选择分屏直播间",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "我的关注"),
              Tab(text: "观看历史"),
              Tab(text: "搜索 / 输入"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFollowTab(),
                _buildHistoryTab(),
                _buildInputTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowTab() {
    return Obx(() {
      var list = FollowService.instance.liveList.isNotEmpty
          ? FollowService.instance.liveList
          : FollowService.instance.followList;
      if (list.isEmpty) {
        return const Center(child: Text("暂无关注主播"));
      }
      return ListView.separated(
        padding: AppStyle.edgeInsetsA12,
        itemCount: list.length,
        separatorBuilder: (_, __) => AppStyle.vGap8,
        itemBuilder: (context, index) {
          var user = list[index];
          return ListTile(
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user.face),
              onBackgroundImageError: (_, __) {},
            ),
            title: Text(user.userName, maxLines: 1),
            subtitle: Text("房间号: ${user.roomId}", maxLines: 1),
            trailing: Obx(() => user.liveStatus.value == 2
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text("直播中", style: TextStyle(color: Colors.white, fontSize: 11)),
                  )
                : const SizedBox.shrink()),
            onTap: () => _onSelectFollow(user),
          );
        },
      );
    });
  }

  Widget _buildHistoryTab() {
    var historyList = DBService.instance.historyBox.values.toList().reversed.toList();
    if (historyList.isEmpty) {
      return const Center(child: Text("暂无历史记录"));
    }
    return ListView.separated(
      padding: AppStyle.edgeInsetsA12,
      itemCount: historyList.length,
      separatorBuilder: (_, __) => AppStyle.vGap8,
      itemBuilder: (context, index) {
        var item = historyList[index];
        return ListTile(
          tileColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: CircleAvatar(
            backgroundImage: NetworkImage(item.face),
            onBackgroundImageError: (_, __) {},
          ),
          title: Text(item.userName, maxLines: 1),
          subtitle: Text("${item.siteId.toUpperCase()} · ${item.roomId}", maxLines: 1),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => _onSelectHistory(item),
        );
      },
    );
  }

  Widget _buildInputTab() {
    return ListView(
      padding: AppStyle.edgeInsetsA16,
      children: [
        // 平台选择
        Row(
          children: [
            const Text("选择平台："),
            AppStyle.hGap8,
            DropdownButton<Site>(
              value: _selectedSite,
              items: Sites.allSites.values.map((site) {
                return DropdownMenuItem<Site>(
                  value: site,
                  child: Text(site.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSite = val);
              },
            ),
          ],
        ),
        AppStyle.vGap12,
        // 输入房间号或网址
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: "直播间链接 或 房间号",
            hintText: "可直接粘贴完整网页链接或输入房间ID",
            suffixIcon: IconButton(
              icon: const Icon(Remix.check_line),
              onPressed: _parseUrlOrRoomId,
            ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _parseUrlOrRoomId(),
        ),
        AppStyle.vGap12,
        FilledButton.icon(
          onPressed: _parseUrlOrRoomId,
          icon: const Icon(Remix.play_line),
          label: const Text("载入此房间"),
        ),
        AppStyle.vGap24,
        const Divider(),
        AppStyle.vGap12,
        Text("或者按关键字搜索主播：", style: Theme.of(context).textTheme.titleSmall),
        AppStyle.vGap8,
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "输入主播昵称或房间标题",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _doSearch(),
              ),
            ),
            AppStyle.hGap8,
            FilledButton.tonal(
              onPressed: _isSearching ? null : _doSearch,
              child: _isSearching
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("搜索"),
            ),
          ],
        ),
        if (_searchResults.isNotEmpty) ...[
          AppStyle.vGap12,
          ..._searchResults.map((item) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(item.cover),
                onBackgroundImageError: (_, __) {},
              ),
              title: Text(item.userName),
              subtitle: Text(item.title, maxLines: 1),
              onTap: () {
                Get.back(
                  result: MultiViewSelectResult(
                    site: _selectedSite,
                    roomId: item.roomId,
                    title: item.title,
                    userName: item.userName,
                    cover: item.cover,
                  ),
                );
              },
            );
          }),
        ],
      ],
    );
  }
}
