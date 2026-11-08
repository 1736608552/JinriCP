import '../models/short_drama.dart';

class DramaHistoryItem {
  final String dramaId;
  final String title;
  final String coverUrl;
  final String category;
  final int totalEpisodes;       // 观看记录时的已知总集数基准（如 33）
  final int lastEpisodeIndex;    // 上次观看的集数索引（从 0 开始，如 29）
  final int lastEpisodeNum;      // 上次观看的集数（如 30）
  final int positionMs;
  final int durationMs;
  final int updatedAt;
  final int? latestTotalEpisodes; // 远端最新探测到的总集数（如 34）
  final int? lastNotifiedEpisode; // 上次已提醒更新的集数

  DramaHistoryItem({
    required this.dramaId,
    required this.title,
    required this.coverUrl,
    required this.category,
    required this.totalEpisodes,
    required this.lastEpisodeIndex,
    required this.lastEpisodeNum,
    this.positionMs = 0,
    this.durationMs = 0,
    required this.updatedAt,
    this.latestTotalEpisodes,
    this.lastNotifiedEpisode,
  });

  /// 🌟 严谨更新判定：只有当远端总集数真正超过观看时的总集数基准时，才判定为“影片更新”
  /// （例如：原总集数 33 集，现在服务端变成 34 集，则提示更新；如果原为 33 集用户看到第 30 集，总集数仍为 33 则绝不提示更新）
  bool get hasNewEpisodes {
    if (latestTotalEpisodes == null) return false;
    return latestTotalEpisodes! > totalEpisodes;
  }

  /// 当前远端实际最新总集数
  int get currentMaxEpisodes => (latestTotalEpisodes != null && latestTotalEpisodes! > totalEpisodes)
      ? latestTotalEpisodes!
      : totalEpisodes;

  /// 本次剧集更新新增的集数（例如从 33 集变成 34 集，新增 1 集）
  int get newlyUpdatedCount {
    if (latestTotalEpisodes == null || latestTotalEpisodes! <= totalEpisodes) return 0;
    return latestTotalEpisodes! - totalEpisodes;
  }

  DramaHistoryItem copyWith({
    int? latestTotalEpisodes,
    int? lastNotifiedEpisode,
    int? totalEpisodes,
    int? lastEpisodeIndex,
    int? lastEpisodeNum,
    int? positionMs,
    int? durationMs,
    int? updatedAt,
  }) {
    return DramaHistoryItem(
      dramaId: dramaId,
      title: title,
      coverUrl: coverUrl,
      category: category,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      lastEpisodeIndex: lastEpisodeIndex ?? this.lastEpisodeIndex,
      lastEpisodeNum: lastEpisodeNum ?? this.lastEpisodeNum,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      latestTotalEpisodes: latestTotalEpisodes ?? this.latestTotalEpisodes,
      lastNotifiedEpisode: lastNotifiedEpisode ?? this.lastNotifiedEpisode,
    );
  }

  factory DramaHistoryItem.fromJson(Map<String, dynamic> json) {
    return DramaHistoryItem(
      dramaId: json['dramaId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      totalEpisodes: json['totalEpisodes'] as int? ?? 1,
      lastEpisodeIndex: json['lastEpisodeIndex'] as int? ?? 0,
      lastEpisodeNum: json['lastEpisodeNum'] as int? ?? 1,
      positionMs: json['positionMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      latestTotalEpisodes: json['latestTotalEpisodes'] as int?,
      lastNotifiedEpisode: json['lastNotifiedEpisode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dramaId': dramaId,
      'title': title,
      'coverUrl': coverUrl,
      'category': category,
      'totalEpisodes': totalEpisodes,
      'lastEpisodeIndex': lastEpisodeIndex,
      'lastEpisodeNum': lastEpisodeNum,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'updatedAt': updatedAt,
      'latestTotalEpisodes': latestTotalEpisodes,
      'lastNotifiedEpisode': lastNotifiedEpisode,
    };
  }

  double get progressPercent {
    if (durationMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  ShortDrama toShortDrama() {
    final maxEps = currentMaxEpisodes;
    return ShortDrama(
      id: dramaId,
      title: title,
      coverUrl: coverUrl,
      description: '看到第 $lastEpisodeNum 集 / 共 $maxEps 集',
      category: category,
      totalEpisodes: maxEps,
      rating: 9.0,
      playCount: '历史记录',
      tags: ['历史记录'],
      episodes: List.generate(
        maxEps > 0 ? maxEps : 1,
        (i) => DramaEpisode(
          episodeNum: i + 1,
          title: '第 ${i + 1} 集',
        ),
      ),
    );
  }
}
