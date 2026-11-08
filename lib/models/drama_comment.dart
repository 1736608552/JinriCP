class DramaComment {
  final String id;
  final String author;
  final String avatar;
  final String avatarColor;
  final String time;
  final String content;
  int likes;
  bool isLiked;
  final bool isPinned;

  DramaComment({
    required this.id,
    required this.author,
    this.avatar = '',
    this.avatarColor = '#5C7FD1',
    required this.time,
    required this.content,
    this.likes = 0,
    this.isLiked = false,
    this.isPinned = false,
  });

  /// 解析自 /api/videos/{id}/comments 接口的 JSON
  factory DramaComment.fromApiJson(Map<String, dynamic> json) {
    return DramaComment(
      id: json['id']?.toString() ?? '',
      author: json['nickname']?.toString() ?? '热心网友',
      avatar: json['avatar']?.toString() ?? '',
      avatarColor: (json['avatar_color']?.toString().isNotEmpty ?? false)
          ? json['avatar_color'].toString()
          : '#5C7FD1',
      time: json['created_at']?.toString() ?? '',
      content: json['text']?.toString() ?? '',
      likes: (json['like_count'] as num?)?.toInt() ??
          int.tryParse(json['like_count']?.toString() ?? '0') ??
          0,
      isLiked: json['liked'] == true,
      isPinned: json['is_pinned'] == true,
    );
  }

  /// 解析自播放页内嵌 <script id="videoInitialData"> 的 JSON
  factory DramaComment.fromInitialData(Map<String, dynamic> json) {
    return DramaComment(
      id: json['id']?.toString() ?? '',
      author: json['author']?.toString() ?? '热心网友',
      avatar: json['av']?.toString() ?? '',
      avatarColor: (json['color']?.toString().isNotEmpty ?? false)
          ? json['color'].toString()
          : '#5C7FD1',
      time: json['time']?.toString() ?? '',
      content: json['text']?.toString() ?? '',
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
      isLiked: false,
      isPinned: json['pinned']?.toString().isNotEmpty == true,
    );
  }
}

class DramaInteractionData {
  final int likeCount;
  final String likeCountText;
  final bool isLiked;
  final int commentCount;
  final String commentCountText;
  final List<DramaComment> comments;
  final String playCount;

  DramaInteractionData({
    this.likeCount = 0,
    this.likeCountText = '0',
    this.isLiked = false,
    this.commentCount = 0,
    this.commentCountText = '0',
    this.comments = const [],
    this.playCount = '',
  });
}

class DramaEpisodePlayData {
  final String streamUrl;
  final DramaInteractionData interaction;

  DramaEpisodePlayData({
    required this.streamUrl,
    required this.interaction,
  });
}
