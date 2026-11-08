class LiveStreamItem {
  final String platform; // 'pandatv' | 'flextv'
  final String userId;
  final String userNick;
  final String title;
  final String thumbUrl;
  final int viewers;
  final int score;
  final int bookmarks;
  final bool isAdult;
  final bool isPw;
  final bool isFan;
  final bool isLive;
  final String startTime;
  final String streamUrl;

  const LiveStreamItem({
    this.platform = 'pandatv',
    required this.userId,
    required this.userNick,
    required this.title,
    required this.thumbUrl,
    required this.viewers,
    this.score = 0,
    this.bookmarks = 0,
    required this.isAdult,
    required this.isPw,
    this.isFan = false,
    required this.isLive,
    required this.startTime,
    required this.streamUrl,
  });

  factory LiveStreamItem.fromPandaJson(Map<String, dynamic> json, {String? streamUrl}) {
    int parsedViewers = 0;
    if (json['user'] != null) {
      parsedViewers = (json['user'] is num)
          ? (json['user'] as num).toInt()
          : (int.tryParse(json['user'].toString()) ?? 0);
    }

    int parsedScore = 0;
    if (json['totalScoreCnt'] != null) {
      parsedScore = (json['totalScoreCnt'] is num)
          ? (json['totalScoreCnt'] as num).toInt()
          : (int.tryParse(json['totalScoreCnt'].toString()) ?? 0);
    }

    int parsedBookmarks = 0;
    if (json['bookmarkCnt'] != null) {
      parsedBookmarks = (json['bookmarkCnt'] is num)
          ? (json['bookmarkCnt'] as num).toInt()
          : (int.tryParse(json['bookmarkCnt'].toString()) ?? 0);
    }

    final isFan = json['type'] == 'fan';

    return LiveStreamItem(
      platform: 'pandatv',
      userId: json['userId']?.toString() ?? '',
      userNick: json['userNick']?.toString() ?? json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'PandaTV 直播',
      thumbUrl: json['thumbUrl']?.toString() ??
          json['userImg']?.toString() ??
          json['ivsThumbnail']?.toString() ??
          '',
      viewers: parsedViewers,
      score: parsedScore,
      bookmarks: parsedBookmarks,
      isAdult: json['isAdult'] == true || json['isAdult'] == 'true' || json['isAdult'] == 1,
      isPw: json['isPw'] == true || json['isPw'] == 'true' || json['isPw'] == 1,
      isFan: isFan,
      isLive: json['isLive'] != false && json['isLive'] != 'false' && json['isLive'] != 0,
      startTime: json['startTime']?.toString() ?? '',
      streamUrl: streamUrl ?? '',
    );
  }

  factory LiveStreamItem.fromFlexJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>? ?? {};
    final barrier = json['barrier'] as Map<String, dynamic>? ?? {};
    final playSource = json['playSource'] as Map<String, dynamic>? ?? {};
    final stat = json['stat'] as Map<String, dynamic>? ?? {};

    int parsedViewers = (json['playerCount'] is num)
        ? (json['playerCount'] as num).toInt()
        : (int.tryParse(json['playerCount']?.toString() ?? '') ?? 0);

    int parsedScore = (stat['numberOfRecommendations'] is num)
        ? (stat['numberOfRecommendations'] as num).toInt()
        : 0;

    int parsedBookmarks = (stat['numberOfSubs'] is num)
        ? (stat['numberOfSubs'] as num).toInt()
        : 0;

    final streamUrl = playSource['url']?.toString() ?? '';
    final isAdult = barrier['isForAdult'] == true || barrier['isForAdult'] == 1 || barrier['useAdultThumbnail'] == 1;
    final isPw = barrier['isLocked'] == true || barrier['isLocked'] == 1;
    final isFan = owner['isBigFan'] == 1;

    return LiveStreamItem(
      platform: 'flextv',
      userId: owner['loginId']?.toString() ?? json['channelId']?.toString() ?? '',
      userNick: owner['nickname']?.toString() ?? owner['name']?.toString() ?? 'Flex主播',
      title: json['title']?.toString() ?? 'FlexTV 直播',
      thumbUrl: json['thumbUrl']?.toString() ?? owner['thumbUrl']?.toString() ?? '',
      viewers: parsedViewers,
      score: parsedScore,
      bookmarks: parsedBookmarks,
      isAdult: isAdult,
      isPw: isPw,
      isFan: isFan,
      isLive: json['isInLive'] == 1,
      startTime: json['startedAt']?.toString() ?? '',
      streamUrl: streamUrl,
    );
  }
}
