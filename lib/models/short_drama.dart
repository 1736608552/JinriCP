class DramaEpisode {
  final int episodeNum;
  final String title;
  String videoUrl;
  final String embedUrl;

  DramaEpisode({
    required this.episodeNum,
    required this.title,
    this.videoUrl = '',
    this.embedUrl = '',
  });

  factory DramaEpisode.fromJson(Map<String, dynamic> json) {
    return DramaEpisode(
      episodeNum: json['episodeNum'] as int? ?? 1,
      title: json['title']?.toString() ?? '第1集',
      videoUrl: json['videoUrl']?.toString() ?? '',
      embedUrl: json['embedUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episodeNum': episodeNum,
      'title': title,
      'videoUrl': videoUrl,
      'embedUrl': embedUrl,
    };
  }
}

class ShortDrama {
  final String id;
  final String title;
  final String coverUrl;
  final String description;
  final String category;
  int totalEpisodes;
  final double rating;
  String playCount;
  final String badge;
  final String updateInfo;
  final List<String> tags;
  List<DramaEpisode> episodes;
  final String itemType; // 'drama' | 'topic' | 'gossip'
  final String extraMeta; // 专题："48部剧情"；吃瓜："作者 · 日期"
  final int rankNum; // 排行榜排名序号：1, 2, 3...

  ShortDrama({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.category,
    required this.totalEpisodes,
    required this.rating,
    required this.playCount,
    this.badge = '',
    this.updateInfo = '',
    required this.tags,
    required this.episodes,
    this.itemType = 'drama',
    this.extraMeta = '',
    this.rankNum = 0,
  });

  /// 解析当前短剧播放量为数值（用于总热度精准排序）
  double get playCountNum {
    if (playCount.isEmpty) return 0.0;
    try {
      String clean = playCount
          .replaceAll('🔥', '')
          .replaceAll('次播放', '')
          .replaceAll('播放', '')
          .replaceAll('热度', '')
          .replaceAll('人追剧', '')
          .replaceAll('追剧', '')
          .replaceAll('+', '')
          .replaceAll(',', '')
          .trim();
      if (clean.isEmpty) return 0.0;
      if (clean.endsWith('亿')) {
        final numPart = clean.replaceAll('亿', '').trim();
        return (double.tryParse(numPart) ?? 0.0) * 100000000.0;
      } else if (clean.endsWith('千万')) {
        final numPart = clean.replaceAll('千万', '').trim();
        return (double.tryParse(numPart) ?? 0.0) * 10000000.0;
      } else if (clean.endsWith('万') || clean.toLowerCase().endsWith('w')) {
        final numPart = clean.replaceAll(RegExp(r'[万wW]'), '').trim();
        return (double.tryParse(numPart) ?? 0.0) * 10000.0;
      } else if (clean.endsWith('千') || clean.toLowerCase().endsWith('k')) {
        final numPart = clean.replaceAll(RegExp(r'[千kK]'), '').trim();
        return (double.tryParse(numPart) ?? 0.0) * 1000.0;
      }
      return double.tryParse(clean) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  factory ShortDrama.fromJson(Map<String, dynamic> json) {
    var rawEpisodes = json['episodes'] as List<dynamic>? ?? [];
    List<DramaEpisode> epList = rawEpisodes.map((e) => DramaEpisode.fromJson(e as Map<String, dynamic>)).toList();

    final total = (json['totalEpisodes'] as int?) ?? (epList.isNotEmpty ? epList.length : 1);

    if (epList.isEmpty) {
      for (int i = 1; i <= total; i++) {
        epList.add(DramaEpisode(
          episodeNum: i,
          title: '第 $i 集',
          videoUrl: json['videoUrl']?.toString() ?? '',
          embedUrl: json['embedUrl']?.toString() ?? '',
        ));
      }
    }

    return ShortDrama(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '热播短剧',
      coverUrl: json['coverUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '精彩短剧，尽享原生流畅播放。',
      category: json['category']?.toString() ?? 'AI成人短剧',
      totalEpisodes: total,
      rating: (json['rating'] as num?)?.toDouble() ?? 8.8,
      playCount: json['playCount']?.toString() ?? '100万+',
      badge: json['badge']?.toString() ?? '',
      updateInfo: json['updateInfo']?.toString() ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['短剧', '超清'],
      episodes: epList,
      itemType: json['itemType']?.toString() ?? 'drama',
      extraMeta: json['extraMeta']?.toString() ?? '',
      rankNum: json['rankNum'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'description': description,
      'category': category,
      'totalEpisodes': totalEpisodes,
      'rating': rating,
      'playCount': playCount,
      'badge': badge,
      'updateInfo': updateInfo,
      'tags': tags,
      'episodes': episodes.map((e) => e.toJson()).toList(),
      'itemType': itemType,
      'extraMeta': extraMeta,
      'rankNum': rankNum,
    };
  }
}

enum ArticleNodeType {
  heading,     // 小节标题 (h1~h6)
  paragraph,   // 正文文本段落
  image,       // 原文插图
  video,       // 原文内嵌原生视频 (m3u8 / mp4)
  dramaLink,   // 关联正片短剧直达
}

class ArticleContentNode {
  final ArticleNodeType type;
  final String content; // 文本内容或媒体直链
  final String? extra;   // 辅助信息，如小节级别或关联剧ID
  final String? title;   // 标题或视频名称

  const ArticleContentNode({
    required this.type,
    required this.content,
    this.extra,
    this.title,
  });
}

class GossipArticle {
  final String id;
  final String title;
  final String author;
  final String authorAvatar;
  final String publishDate;
  final String categoryName;
  final List<String> paragraphs;
  final List<String> imageUrls;
  final String rawContent;
  final String relatedDramaId;
  final String relatedDramaTitle;
  final List<ArticleContentNode> contentNodes;
  final List<String> videoUrls;
  final List<String> tags;

  GossipArticle({
    required this.id,
    required this.title,
    required this.author,
    required this.authorAvatar,
    required this.publishDate,
    required this.categoryName,
    required this.paragraphs,
    required this.imageUrls,
    required this.rawContent,
    this.relatedDramaId = '',
    this.relatedDramaTitle = '',
    this.contentNodes = const [],
    this.videoUrls = const [],
    this.tags = const [],
  });
}

