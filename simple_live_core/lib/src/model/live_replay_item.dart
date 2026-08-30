import 'dart:convert';

class LiveReplayItem {
  /// 唯一标识（vid / bvid / vid 等）
  final String id;

  /// 录播/视频标题
  final String title;

  /// 封面图片
  final String cover;

  /// 视频时长（如 01:23:45 或 12:30）
  final String duration;

  /// 发布或生成时间
  final String createTime;

  /// 主播/作者
  final String author;

  /// 网页链接 / 原地址
  final String url;

  /// 直接可播放链接（若已有）
  final String playUrl;

  /// 标签/类型（如 直播录播、精彩回放 等）
  final String tag;

  /// 播放量 / 热度
  final String viewCount;

  /// 弹幕数
  final String danmuCount;

  /// 扩展字段（如 cid, bvid, upId, room_id 等，供解析 playurl 使用）
  final Map<String, dynamic>? extra;

  LiveReplayItem({
    required this.id,
    required this.title,
    required this.cover,
    this.duration = "",
    this.createTime = "",
    this.author = "",
    this.url = "",
    this.playUrl = "",
    this.tag = "直播录播",
    this.viewCount = "0",
    this.danmuCount = "0",
    this.extra,
  });

  @override
  String toString() {
    return json.encode({
      "id": id,
      "title": title,
      "cover": cover,
      "duration": duration,
      "createTime": createTime,
      "author": author,
      "url": url,
      "playUrl": playUrl,
      "tag": tag,
      "viewCount": viewCount,
      "danmuCount": danmuCount,
      "extra": extra,
    });
  }
}

class LiveReplayResult {
  final bool hasMore;
  final List<LiveReplayItem> items;

  LiveReplayResult({
    required this.hasMore,
    required this.items,
  });
}

