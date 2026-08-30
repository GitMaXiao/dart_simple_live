import 'dart:convert';

class LiveHighlightExcerpt {
  final String content;
  final String dnick;
  final String icon;
  final int likeCount;

  LiveHighlightExcerpt({
    required this.content,
    this.dnick = "",
    this.icon = "",
    this.likeCount = 0,
  });

  factory LiveHighlightExcerpt.fromJson(Map<String, dynamic> json) {
    return LiveHighlightExcerpt(
      content: json['content']?.toString() ?? '',
      dnick: json['dnick']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      likeCount: json['likeCount'] is int
          ? json['likeCount']
          : (int.tryParse(json['likeCount']?.toString() ?? '0') ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'dnick': dnick,
        'icon': icon,
        'likeCount': likeCount,
      };
}

class LiveHighlightItem {
  /// 唯一标识（vid / hashId）
  final String id;

  /// 看点标题
  final String title;

  /// 封面图片
  final String cover;

  /// 视频时长（如 02:30）
  final String duration;

  /// 发布或生成时间
  final String createTime;

  /// 主播/作者
  final String author;

  /// 播放/切片网页链接
  final String url;

  /// 标签（如 AI看点、高能时刻、精彩切片等）
  final String tag;

  /// 播放量 / 热度
  final String viewCount;

  /// 弹幕数
  final String danmuCount;

  /// 简要描述/AI摘要
  final String description;

  /// 点赞数
  final int likeCount;

  /// 精选弹幕列表
  final List<LiveHighlightExcerpt> excerpts;

  /// 额外元数据
  final Map<String, dynamic> extra;

  LiveHighlightItem({
    required this.id,
    required this.title,
    required this.cover,
    this.duration = "",
    this.createTime = "",
    this.author = "",
    this.url = "",
    this.tag = "AI看点",
    this.viewCount = "0",
    this.danmuCount = "0",
    this.description = "",
    this.likeCount = 0,
    this.excerpts = const [],
    this.extra = const {},
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
      "tag": tag,
      "viewCount": viewCount,
      "danmuCount": danmuCount,
      "description": description,
      "likeCount": likeCount,
      "excerpts": excerpts.map((e) => e.toJson()).toList(),
      "extra": extra,
    });
  }
}

