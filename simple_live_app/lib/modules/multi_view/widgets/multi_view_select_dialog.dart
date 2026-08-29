import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/net_image.dart';
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

class MultiViewSelectDialog extends StatelessWidget {
  const MultiViewSelectDialog({super.key});

  static Future<MultiViewSelectResult?> show({bool isLandscape = false}) async {
    final context = Get.context;
    final isLand = isLandscape ||
        (context != null &&
            MediaQuery.of(context).orientation == Orientation.landscape);

    if (isLand) {
      // 横屏全屏模式：以右侧滑出抽屉面板形式弹出
      return await Get.generalDialog<MultiViewSelectResult?>(
        barrierDismissible: true,
        barrierLabel: "选择分屏直播间",
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, anim1, anim2) {
          final double panelWidth =
              (MediaQuery.of(dialogContext).size.width * 0.58).clamp(380.0, 520.0);
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(140),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const SafeArea(
                  left: false,
                  child: MultiViewSelectSection(
                    showHeader: true,
                    isBottomSheet: false,
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim, secondaryAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      );
    } else {
      // 竖屏模式：从底部滑出
      return await Get.bottomSheet<MultiViewSelectResult?>(
        const MultiViewSelectDialog(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MultiViewSelectSection(
      showHeader: true,
      isBottomSheet: true,
    );
  }
}

class MultiViewSelectSection extends StatefulWidget {
  final Function(MultiViewSelectResult result)? onSelect;
  final bool showHeader;
  final bool isBottomSheet;

  const MultiViewSelectSection({
    super.key,
    this.onSelect,
    this.showHeader = false,
    this.isBottomSheet = false,
  });

  @override
  State<MultiViewSelectSection> createState() => _MultiViewSelectSectionState();
}

class _MultiViewSelectSectionState extends State<MultiViewSelectSection>
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

  void _deliverResult(MultiViewSelectResult result) {
    if (widget.onSelect != null) {
      widget.onSelect!(result);
    } else {
      Get.back(result: result);
    }
  }

  void _onSelectFollow(FollowUser user) {
    var site = Sites.allSites[user.siteId];
    if (site == null) {
      SmartDialog.showToast("不支持的直播平台");
      return;
    }
    _deliverResult(
      MultiViewSelectResult(
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
    _deliverResult(
      MultiViewSelectResult(
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
            _deliverResult(
              MultiViewSelectResult(
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
      _deliverResult(
        MultiViewSelectResult(
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    Widget content = Column(
      children: [
        if (widget.showHeader) ...[
          // 顶部小把手
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(90),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Remix.layout_grid_line,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                AppStyle.hGap12,
                Text(
                  "选择分屏直播间",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Remix.close_line, size: 20),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),
        ],
        // 选项卡
        TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Remix.heart_3_line, size: 16),
              text: "我的关注",
            ),
            Tab(
              icon: Icon(Remix.history_line, size: 16),
              text: "观看历史",
            ),
            Tab(
              icon: Icon(Remix.search_2_line, size: 16),
              text: "搜索 / 链接",
            ),
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
    );

    if (widget.isBottomSheet) {
      return AnimatedPadding(
        padding: EdgeInsets.only(bottom: bottomInset),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: content,
          ),
        ),
      );
    } else {
      return content;
    }
  }

  Widget _buildFollowTab() {
    return Obx(() {
      var liveList = FollowService.instance.liveList;
      var notLiveList = FollowService.instance.notLiveList;
      var totalList = [...liveList, ...notLiveList];

      if (totalList.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Remix.user_heart_line, size: 48, color: Colors.grey.withAlpha(120)),
              AppStyle.vGap12,
              const Text("暂无关注的主播", style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: AppStyle.edgeInsetsA12,
        itemCount: totalList.length,
        separatorBuilder: (_, __) => AppStyle.vGap8,
        itemBuilder: (context, index) {
          var user = totalList[index];
          var site = Sites.allSites[user.siteId];
          bool isLiving = user.liveStatus.value == 2;

          return Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _onSelectFollow(user),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // 头像与平台角标
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: NetImage(
                            user.face,
                            width: 46,
                            height: 46,
                          ),
                        ),
                        if (site != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                site.logo,
                                width: 14,
                                height: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    AppStyle.hGap12,
                    // 主播名与房间信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (site != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withAlpha(35),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    site.name,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          AppStyle.vGap4,
                          Text(
                            "房间号: ${user.roomId}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AppStyle.hGap8,
                    // 状态徽章
                    if (isLiving)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withAlpha(120)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "● 直播中",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        "未开播",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildHistoryTab() {
    var historyList = DBService.instance.historyBox.values.toList().reversed.toList();
    if (historyList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Remix.history_line, size: 48, color: Colors.grey.withAlpha(120)),
            AppStyle.vGap12,
            const Text("暂无观看历史记录", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: AppStyle.edgeInsetsA12,
      itemCount: historyList.length,
      separatorBuilder: (_, __) => AppStyle.vGap8,
      itemBuilder: (context, index) {
        var item = historyList[index];
        var site = Sites.allSites[item.siteId];
        return Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onSelectHistory(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: NetImage(
                          item.face,
                          width: 44,
                          height: 44,
                        ),
                      ),
                      if (site != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              site.logo,
                              width: 14,
                              height: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppStyle.vGap4,
                        Text(
                          "${site?.name ?? item.siteId.toUpperCase()} · 房间 ${item.roomId}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Remix.arrow_right_s_line, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputTab() {
    final theme = Theme.of(context);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppStyle.edgeInsetsA16,
      children: [
        // 平台选择
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Text("目标平台：", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              AppStyle.hGap8,
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Site>(
                    value: _selectedSite,
                    isExpanded: true,
                    items: Sites.allSites.values.map((site) {
                      return DropdownMenuItem<Site>(
                        value: site,
                        child: Row(
                          children: [
                            Image.asset(site.logo, width: 20, height: 20),
                            AppStyle.hGap8,
                            Text(site.name, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSite = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 输入房间号或网址
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: "直播间链接 或 房间号",
            hintText: "可直接粘贴完整网页链接或输入房间ID",
            prefixIcon: const Icon(Remix.link, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "粘贴剪贴板内容",
                  icon: const Icon(Remix.clipboard_line, size: 18),
                  onPressed: () async {
                    var text = await Utils.getClipboard();
                    if (text != null && text.isNotEmpty) {
                      _urlController.text = text;
                    }
                  },
                ),
                IconButton(
                  tooltip: "确定载入",
                  icon: const Icon(Remix.check_line, size: 20, color: Colors.blueAccent),
                  onPressed: _parseUrlOrRoomId,
                ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _parseUrlOrRoomId(),
        ),
        AppStyle.vGap12,
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _parseUrlOrRoomId,
          icon: const Icon(Remix.play_circle_line),
          label: const Text("载入此房间播放", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        AppStyle.vGap24,
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text("或搜索平台在线主播", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "输入主播昵称或房间标题",
                  prefixIcon: const Icon(Remix.search_line, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onSubmitted: (_) => _doSearch(),
              ),
            ),
            AppStyle.hGap8,
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSearching ? null : _doSearch,
              child: _isSearching
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("搜索"),
            ),
          ],
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._searchResults.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetImage(
                    item.cover,
                    width: 54,
                    height: 38,
                  ),
                ),
                title: Text(item.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Remix.arrow_right_s_line, size: 16),
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
              ),
            );
          }),
        ],
      ],
    );
  }
}
