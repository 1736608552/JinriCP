import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/short_drama.dart';

/// 黄瓜短剧（hgdju / Nuxt 3 browse 体系）自愈解析与服务引擎
class HgdjuDramaService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ),
  );

  /// 官方直连高可用业务线路池（防封自动回退）
  static const List<String> fallbackLines = [
    'https://porncz.ywwegfkd.cc',
    'https://rixgqa.ywwegfkd.cc',
    'https://xyz.uraifjhut.cc',
    'https://mkqjue.ywwegfkd.cc',
    'https://qwer.uraifjhut.cc',
    'https://abc.uraifjhut.cc',
    'https://xyz.zgoqmlyp.cc',
    'https://hgdju1.com',
    'https://hgdj.ai',
  ];

  /// 黄瓜短剧一级分类（内容线）- 1:1 对齐官方截图
  static final List<Map<String, String>> lines = [
    {'title': '全部', 'slug': ''},
    {'title': '原创', 'slug': 'yuanchuang'},
    {'title': '魔改', 'slug': 'mogai'},
    {'title': 'AI漫剧', 'slug': 'manju'},
    {'title': '真人短剧', 'slug': 'zhenren'},
    {'title': 'AI短剧', 'slug': 'aiduanju'},
  ];

  /// 黄瓜短剧全量官方题材标签 (1:1 绝对对齐官方网页全量标签库)
  static final List<Map<String, String>> tags = [
    {'title': '全部', 'slug': ''},
    {'title': '都市邻里', 'slug': 'dushi'},
    {'title': '甜宠恋爱', 'slug': 'tag'},
    {'title': '古装玄幻', 'slug': 'xuanhuan'},
    {'title': '逆袭', 'slug': 'nixi'},
    {'title': '复仇逆袭', 'slug': 'fuchou'},
    {'title': '虐恋情深', 'slug': 'tag-06118f'},
    {'title': '穿越重生', 'slug': 'chuanyue'},
    {'title': '惊悚悬疑', 'slug': 'xuanyi'},
    {'title': '霸总激情', 'slug': 'tianchong'},
    {'title': '战神归来', 'slug': 'tag-88650e'},
    {'title': '校园恋爱', 'slug': 'tag-834fd7'},
    {'title': '末世生存', 'slug': 'zhanshen'},
    {'title': '动漫魔改', 'slug': 'tag-d4f982'},
    {'title': '人妻出轨', 'slug': 'tag-adcb6b'},
    {'title': '婚外偷情', 'slug': 'tag-8477ea'},
    {'title': '秘密情人', 'slug': 'tag-90323d'},
    {'title': '主仆调教', 'slug': 'tag-209de5'},
    {'title': '绿帽淫妻', 'slug': 'tag-2f3cfe'},
    {'title': '反差小花', 'slug': 'tag-634f08'},
    {'title': '身体交易', 'slug': 'tag-d40bc6'},
    {'title': '禁忌乱伦', 'slug': 'tag-7cdc58'},
    {'title': '系统爽剧', 'slug': 'tag-4af083'},
    {'title': '复仇爽剧', 'slug': 'tag-c42c7f'},
    {'title': '密室调教', 'slug': 'tag-236b2c'},
    {'title': '潜规则秘恋', 'slug': 'tag-b6b9cb'},
    {'title': '换妻游戏', 'slug': 'tag-1d701c'},
    {'title': '娱乐潜规', 'slug': 'tag-2f8891'},
    {'title': '村妇养成', 'slug': 'tag-d73c28'},
    {'title': '交换伴侣', 'slug': 'tag-195078'},
    {'title': '仙侠情缘', 'slug': 'tag-e87ee8'},
    {'title': '修真双修', 'slug': 'tag-c3e4f4'},
    {'title': '灵异情欲', 'slug': 'tag-7e4c73'},
    {'title': '禁忌师生', 'slug': 'tag-0d50c2'},
  ];

  /// 状态选项 - 1:1 对齐官方截图
  static final List<Map<String, String>> statuses = [
    {'title': '全部', 'slug': ''},
    {'title': '连载中', 'slug': 'ongoing'},
    {'title': '已完结', 'slug': 'completed'},
  ];

  /// 排序选项 - 1:1 对齐官方截图 (最热为默认排序，官方URL不带sort参数)
  static final List<Map<String, String>> sorts = [
    {'title': '最热', 'slug': ''},
    {'title': '最新', 'slug': 'new'},
    {'title': '追剧最多', 'slug': 'fav'},
  ];

  static String getLineSlug(String title) {
    if (title.isEmpty || title == '全部') return '';
    for (final item in lines) {
      if (item['title'] == title || title.contains(item['title']!)) return item['slug']!;
    }
    return '';
  }

  static String getTagSlug(String title) {
    if (title.isEmpty || title == '全部' || title == '全部题材') return '';
    for (final item in tags) {
      if (item['title'] == title || title.contains(item['title']!)) return item['slug']!;
    }
    return '';
  }

  static String getStatusSlug(String title) {
    if (title.isEmpty || title == '全部' || title == '全部状态') return '';
    for (final item in statuses) {
      if (item['title'] == title || title.contains(item['title']!)) return item['slug']!;
    }
    return '';
  }

  static String getSortSlug(String title) {
    if (title.contains('最新') || title == 'new') return 'new';
    if (title.contains('追剧') || title.contains('最多') || title == 'fav') return 'fav';
    // 🌟 核心规范：最热为默认，严禁返回 hot（黄瓜官方URL中不带任何sort参数）
    return '';
  }

  /// 缓存解析成功的真实有效线路
  static String? _resolvedLiveBaseUrl;
  static String? _lastRawInputUrl;

  /// 规范化并自动解析真实可用的基础 URL
  static Future<String> resolveRealBaseUrl(String rawUrl) async {
    String u = rawUrl.trim();
    if (u.endsWith('/browse')) {
      u = u.substring(0, u.length - '/browse'.length);
    }
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    if (u != _lastRawInputUrl) {
      _lastRawInputUrl = u;
      _resolvedLiveBaseUrl = null;
    }

    // 若未填、为空或包含已失效的旧域名（wuscaznx/zgoqmlyp），直接使用首选官方真实可用线路
    if (u.isEmpty || u.contains('wuscaznx') || u.contains('zgoqmlyp')) {
      return fallbackLines.first;
    }

    // 若已缓存且与输入源相符，直接返回
    if (_resolvedLiveBaseUrl != null && _resolvedLiveBaseUrl!.isNotEmpty) {
      return _resolvedLiveBaseUrl!;
    }

    // 若用户输入的是发布页（如 hgdju1.com、hgdju.com、hgdj.ai），尝试从发布页中提取真实业务线路
    if (u.contains('hgdju1.com') || u.contains('hgdju.com') || u.contains('hgdj')) {
      try {
        final resp = await _dio.get<String>(u);
        if (resp.statusCode == 200 && resp.data != null) {
          final html = resp.data!;
          final lineReg = RegExp(r'https://[a-zA-Z0-9\.\-]+\.(?:ywwegfkd|uraifjhut|zgoqmlyp|wuscaznx|zvdumduz)\.cc');
          final matches = lineReg.allMatches(html);
          for (final m in matches) {
            final matchUrl = m.group(0)!;
            if (matchUrl.contains('ywwegfkd') || matchUrl.contains('uraifjhut')) {
              _resolvedLiveBaseUrl = matchUrl;
              return _resolvedLiveBaseUrl!;
            }
          }
          if (matches.isNotEmpty) {
            _resolvedLiveBaseUrl = matches.first.group(0)!;
            return _resolvedLiveBaseUrl!;
          }
        }
      } catch (_) {}
      _resolvedLiveBaseUrl = fallbackLines.first;
      return _resolvedLiveBaseUrl!;
    }

    // 默认直接使用用户填写的地址
    _resolvedLiveBaseUrl = u;
    return u;
  }

  /// 抓取黄瓜短剧列表（对应 https://porncz.wuscaznx.cc/browse）
  static Future<List<ShortDrama>> fetchDramas({
    required String rawBaseUrl,
    String line = '',
    String tag = '',
    String status = '',
    String sort = '',
    int page = 1,
  }) async {
    final base = await resolveRealBaseUrl(rawBaseUrl);
    final queryParams = <String, String>{};
    if (line.isNotEmpty) queryParams['line'] = line;
    if (tag.isNotEmpty) queryParams['tag'] = tag;
    if (status.isNotEmpty) queryParams['status'] = status;
    // 🌟 核心规范对齐：仅在最新（new）或追剧最多（fav）时传递 sort，最热默认不传！
    if (sort == 'new' || sort == 'fav') {
      queryParams['sort'] = sort;
    }
    if (page > 1) {
      queryParams['page'] = page.toString();
    }

    final uri = Uri.parse('$base/browse').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    // 首选请求解析
    try {
      final resp = await _dio.getUri<String>(
        uri,
        options: Options(
          headers: {'Referer': '$base/browse'},
        ),
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final list = parseBrowseHtml(resp.data!, base);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // 若首选请求失败或解析为空，尝试备用线路池
    for (final altBase in fallbackLines) {
      if (altBase == base) continue;
      try {
        final altUri = Uri.parse('$altBase/browse').replace(queryParameters: queryParams);
        final resp = await _dio.getUri<String>(
          altUri,
          options: Options(
            headers: {'Referer': '$altBase/browse'},
          ),
        );
        if (resp.statusCode == 200 && resp.data != null) {
          final list = parseBrowseHtml(resp.data!, altBase);
          if (list.isNotEmpty) {
            _resolvedLiveBaseUrl = altBase;
            return list;
          }
        }
      } catch (_) {}
    }

    return [];
  }

  /// 解析 /browse 页面的 HTML，提取 ShortDrama 列表
  static List<ShortDrama> parseBrowseHtml(String html, String baseUrl) {
    final List<ShortDrama> list = [];

    // 🌟 1. 核心首选：从 Nuxt 3 数据岛 (__NUXT_DATA__) 反序列化完整短剧对象
    // 包含高清 CDN 封面、官方真实分类角标、真实连载/完结集数、7日热度及全部关联标签
    try {
      final doc = html_parser.parse(html);
      final nuxtScript = doc.querySelector('script#__NUXT_DATA__');
      if (nuxtScript != null) {
        final rawData = json.decode(nuxtScript.text.trim()) as List<dynamic>;

        dynamic resolveVal(dynamic v) {
          if (v is int && v >= 0 && v < rawData.length) {
            return rawData[v];
          }
          return v;
        }

        final seenSlugs = <String>{};

        for (final item in rawData) {
          if (item is Map) {
            final slugVal = resolveVal(item['slug']);
            final titleVal = resolveVal(item['title']);
            if (slugVal is String && slugVal.startsWith('dj-') && titleVal is String && titleVal.isNotEmpty) {
              if (seenSlugs.contains(slugVal)) continue;
              seenSlugs.add(slugVal);

              // 提取高清直连 CDN 封面
              String coverUrl = '';
              final covObj = resolveVal(item['cover']);
              if (covObj is Map) {
                final urlVal = resolveVal(covObj['url']);
                if (urlVal is String && urlVal.startsWith('http')) {
                  coverUrl = urlVal;
                } else {
                  final fbVal = resolveVal(covObj['fallback_url']);
                  if (fbVal is String && fbVal.isNotEmpty) {
                    coverUrl = fbVal.startsWith('http') ? fbVal : '$baseUrl$fbVal';
                  }
                }
              }

              // 提取官方真实内容线与角标
              String badge = 'AI短剧';
              final lineObj = resolveVal(item['line']);
              if (lineObj is Map) {
                final lineName = resolveVal(lineObj['name']);
                if (lineName is String && lineName.isNotEmpty) {
                  badge = lineName.endsWith('剧') ? lineName : '$lineName短剧';
                }
              }

              // 集数与连载状态
              int totalEpisodes = 1;
              final totVal = resolveVal(item['total_episodes']) ?? resolveVal(item['total_episode_count']);
              final latVal = resolveVal(item['latest_episode_number']);
              if (totVal is int && totVal > 0) {
                totalEpisodes = totVal;
              } else if (latVal is int && latVal > 0) {
                totalEpisodes = latVal;
              }

              final serialStatus = resolveVal(item['serial_status']);
              final isCompleted = serialStatus == 'completed';
              final updateInfo = isCompleted ? '全 $totalEpisodes 集' : '更新至 $totalEpisodes 集';

              // 热度 / 播放量
              String playCount = '1.2万';
              final heatVal = resolveVal(item['heat_7d']);
              if (heatVal is num) {
                if (heatVal >= 10000) {
                  playCount = '${(heatVal / 10000).toStringAsFixed(1)}万';
                } else {
                  playCount = '${heatVal.toInt()}';
                }
              }

              // 题材标签列表
              final tagsList = <String>[badge];
              final rawTags = resolveVal(item['tags']);
              if (rawTags is List) {
                for (final tItem in rawTags) {
                  final tObj = resolveVal(tItem);
                  if (tObj is Map) {
                    final tName = resolveVal(tObj['name']);
                    if (tName is String && tName.isNotEmpty && !tagsList.contains(tName)) {
                      tagsList.add(tName);
                    }
                  }
                }
              }
              tagsList.add(isCompleted ? '已完结' : '连载中');

              list.add(
                ShortDrama(
                  id: slugVal,
                  title: titleVal,
                  coverUrl: coverUrl,
                  description: '$titleVal · $updateInfo',
                  category: badge,
                  totalEpisodes: totalEpisodes,
                  rating: 9.8,
                  playCount: playCount,
                  badge: badge,
                  updateInfo: updateInfo,
                  tags: tagsList,
                  episodes: [],
                  itemType: 'drama',
                ),
              );
            }
          }
        }

        if (list.isNotEmpty) {
          return list;
        }
      }
    } catch (_) {}

    // 🌟 2. 深度 DOM 兜底解析（当 Nuxt 数据岛为空或页面为纯静态 HTML 时）
    final doc = html_parser.parse(html);
    var cardElements = doc.querySelectorAll('article[data-xpch="card-drama"], article, .card');
    if (cardElements.isEmpty) {
      cardElements = doc.querySelectorAll('div').where((el) => el.querySelector('a[href*="/play/"]') != null).toList();
    }

    final seenSlugs = <String>{};

    for (final card in cardElements) {
      try {
        final playLink = card.querySelector('a[href*="/play/"]');
        if (playLink == null) continue;

        final href = playLink.attributes['href'] ?? '';
        final slugMatch = RegExp(r'/play/([a-zA-Z0-9_\-]+)').firstMatch(href);
        if (slugMatch == null) continue;

        final slug = slugMatch.group(1)!.trim();
        if (slug.isEmpty || seenSlugs.contains(slug)) continue;
        seenSlugs.add(slug);

        String title = playLink.attributes['aria-label'] ?? '';
        if (title.isEmpty) {
          final detailLink = card.querySelector('a[href*="/drama/"]');
          title = detailLink?.attributes['aria-label'] ?? '';
        }
        if (title.isEmpty) {
          final img = card.querySelector('img');
          title = img?.attributes['alt'] ?? '';
        }
        if (title.isEmpty) {
          final titleEl = card.querySelector('.truncate, h2, h3, .title, .name');
          title = titleEl?.text.trim() ?? '';
        }
        title = title
            .replaceAll('详情', '')
            .replaceAll('播放', '')
            .replaceAll('<!--[-->', '')
            .replaceAll('<!--]-->', '')
            .trim();
        if (title.isEmpty) title = slug;

        String cover = '';
        final img = card.querySelector('img');
        if (img != null) {
          final src = img.attributes['src'] ?? '';
          final dataSrc = img.attributes['data-src'] ?? img.attributes['data-cover-fb'] ?? '';
          if (dataSrc.isNotEmpty) {
            cover = dataSrc;
          } else if (src.isNotEmpty && !src.startsWith('data:image')) {
            cover = src;
          }
        }
        if (cover.isNotEmpty && cover.startsWith('/')) {
          cover = '$baseUrl$cover';
        }

        String badge = 'AI短剧';
        final badgeSpan = card.querySelector('span.bg-\\[\\#274e00\\]');
        if (badgeSpan != null && badgeSpan.text.trim().isNotEmpty) {
          final bText = badgeSpan.text.trim();
          badge = bText.endsWith('剧') ? bText : '$bText短剧';
        } else {
          final cardText = card.text;
          if (cardText.contains('原创')) {
            badge = '原创短剧';
          } else if (cardText.contains('魔改')) {
            badge = '魔改短剧';
          } else if (cardText.contains('漫剧')) {
            badge = 'AI漫剧';
          } else if (cardText.contains('真人')) {
            badge = '真人短剧';
          }
        }

        int totalEpisodes = 1;
        String updateInfo = '全集完结';
        final epMatch = RegExp(r'(?:全|更新至)\s*(\d+)\s*集').firstMatch(card.text);
        if (epMatch != null) {
          totalEpisodes = int.tryParse(epMatch.group(1)!) ?? 1;
          updateInfo = '全 $totalEpisodes 集';
        }

        String playCount = '1.2万';
        final heatMatch = RegExp(r'(\d+)\s*(?:<[^>]+>)*\s*热度').firstMatch(card.innerHtml);
        if (heatMatch != null) {
          final rawHeat = double.tryParse(heatMatch.group(1)!) ?? 0;
          if (rawHeat >= 10000) {
            playCount = '${(rawHeat / 10000).toStringAsFixed(1)}万';
          } else {
            playCount = '${rawHeat.toInt()}';
          }
        }

        final tagsList = <String>[badge];
        final tagEl = card.querySelector('p.text-\\[\\#b5e7c6\\], p');
        if (tagEl != null) {
          final rawTags = tagEl.text.replaceAll('<!--[-->', '').replaceAll('<!--]-->', '').trim();
          for (final part in rawTags.split(RegExp(r'[\·\|/,\s]+'))) {
            final t = part.trim();
            if (t.isNotEmpty && !tagsList.contains(t) && t != badge) {
              tagsList.add(t);
            }
          }
        }
        tagsList.add('已完结');

        list.add(
          ShortDrama(
            id: slug,
            title: title,
            coverUrl: cover,
            description: '$title · $updateInfo',
            category: badge,
            totalEpisodes: totalEpisodes,
            rating: 9.8,
            playCount: playCount,
            badge: badge,
            updateInfo: updateInfo,
            tags: tagsList,
            episodes: [],
            itemType: 'drama',
          ),
        );
      } catch (_) {}
    }

    return list;
  }

  /// 抓取黄瓜短剧详情与完整选集列表（请求 /play/{slug}/1）
  static Future<ShortDrama?> fetchDramaDetail({
    required String rawBaseUrl,
    required String slug,
  }) async {
    final base = await resolveRealBaseUrl(rawBaseUrl);
    final playUrl = '$base/play/$slug/1';

    try {
      final resp = await _dio.get<String>(
        playUrl,
        options: Options(
          headers: {'Referer': '$base/browse'},
        ),
      );

      if (resp.statusCode == 200 && resp.data != null) {
        return parseDramaDetailHtml(resp.data!, base, slug);
      }
    } catch (_) {}

    // 备用线路重试
    for (final altBase in fallbackLines) {
      if (altBase == base) continue;
      try {
        final resp = await _dio.get<String>(
          '$altBase/play/$slug/1',
          options: Options(
            headers: {'Referer': '$altBase/browse'},
          ),
        );
        if (resp.statusCode == 200 && resp.data != null) {
          return parseDramaDetailHtml(resp.data!, altBase, slug);
        }
      } catch (_) {}
    }

    return null;
  }

  /// 从黄瓜短剧播放页 HTML 中深度自愈提取真实带签名的 m3u8 直连流
  static String extractStreamUrlFromHtml(String rawHtml) {
    if (rawHtml.isEmpty) return '';

    // 1. 优先尝试精准反序列化 Nuxt 3 数据岛 (__NUXT_DATA__)
    try {
      final doc = html_parser.parse(rawHtml);
      final nuxtScript = doc.querySelector('script#__NUXT_DATA__');
      if (nuxtScript != null) {
        final rawData = json.decode(nuxtScript.text.trim()) as List<dynamic>;
        dynamic resolveVal(dynamic v) {
          if (v is int && v >= 0 && v < rawData.length) {
            return rawData[v];
          }
          return v;
        }

        for (final item in rawData) {
          if (item is Map) {
            // 匹配 media 对象中的 source_url
            final sourceUrl = resolveVal(item['source_url']);
            if (sourceUrl is String && sourceUrl.contains('.m3u8')) {
              return sourceUrl.trim();
            }
          }
        }
      }
    } catch (_) {}

    // 2. 深度正则自愈提取：将 SSR 编码中的 \u002F 全量还原为 /
    final normalized = rawHtml.replaceAll(r'\u002F', '/').replaceAll(r'\/', '/');
    final m3u8Match = RegExp(r'''https?://[^\s"'<>\\]+?\.m3u8[^\s"'<>\\]*''').firstMatch(normalized);
    if (m3u8Match != null) {
      return m3u8Match.group(0)!.trim();
    }

    return '';
  }

  /// 解析播放页提取短剧详情与全集剧集列表
  static ShortDrama? parseDramaDetailHtml(String html, String baseUrl, String slug) {
    try {
      final doc = html_parser.parse(html);

      // 提取片名
      String title = '';
      final titleMeta = doc.querySelector('meta[property="og:title"]');
      if (titleMeta != null) {
        title = titleMeta.attributes['content']?.replaceAll('播放', '').trim() ?? '';
      }
      if (title.isEmpty) {
        final titleEl = doc.querySelector('h1, .detail-title, .title');
        title = titleEl?.text.trim() ?? slug;
      }

      // 提取封面
      String cover = '';
      final imgMeta = doc.querySelector('meta[property="og:image"]');
      if (imgMeta != null) {
        cover = imgMeta.attributes['content'] ?? '';
      }

      // 提取首集可用真实直连 m3u8 流地址
      final firstEpStream = extractStreamUrlFromHtml(html);

      // 提取全集剧集列表（优先从 Nuxt 3 数据岛反序列化完整分集列表）
      final List<DramaEpisode> episodes = [];
      try {
        final nuxtScript = doc.querySelector('script#__NUXT_DATA__');
        if (nuxtScript != null) {
          final rawData = json.decode(nuxtScript.text.trim()) as List<dynamic>;
          dynamic resolveVal(dynamic v) {
            if (v is int && v >= 0 && v < rawData.length) {
              return rawData[v];
            }
            return v;
          }

          for (final item in rawData) {
            if (item is Map && item.containsKey('episodes')) {
              final epList = resolveVal(item['episodes']);
              if (epList is List && epList.isNotEmpty) {
                for (final e in epList) {
                  final eObj = resolveVal(e);
                  if (eObj is Map) {
                    final epNum = resolveVal(eObj['number']) as int? ?? (episodes.length + 1);
                    final epTitle = resolveVal(eObj['title'])?.toString() ?? '第$epNum集';
                    final epRoute = resolveVal(eObj['route'])?.toString() ?? '/play/$slug/$epNum';
                    episodes.add(
                      DramaEpisode(
                        episodeNum: epNum,
                        title: epTitle.startsWith('第') ? epTitle : '第$epNum集',
                        videoUrl: (epNum == 1 && firstEpStream.isNotEmpty) ? firstEpStream : '',
                        embedUrl: epRoute.startsWith('http') ? epRoute : '$baseUrl$epRoute',
                      ),
                    );
                  }
                }
                break;
              }
            }
          }
        }
      } catch (_) {}

      // 若未从数据岛提取到分集，执行兜底提取
      if (episodes.isEmpty) {
        int totalEp = 1;
        final epMatches = RegExp(r'(?:全|共)\s*(\d+)\s*集').allMatches(html);
        for (final m in epMatches) {
          final n = int.tryParse(m.group(1)!) ?? 1;
          if (n > totalEp) totalEp = n;
        }
        if (totalEp <= 1) {
          final numMatches = RegExp(r'/play/' + RegExp.escape(slug) + r'/(\d+)').allMatches(html);
          for (final m in numMatches) {
            final n = int.tryParse(m.group(1)!) ?? 1;
            if (n > totalEp) totalEp = n;
          }
        }
        if (totalEp <= 1) totalEp = 20;

        for (int i = 1; i <= totalEp; i++) {
          episodes.add(
            DramaEpisode(
              episodeNum: i,
              title: '第$i集',
              videoUrl: (i == 1 && firstEpStream.isNotEmpty) ? firstEpStream : '',
              embedUrl: '$baseUrl/play/$slug/$i',
            ),
          );
        }
      }

      final totalCount = episodes.isNotEmpty ? episodes.length : 1;

      return ShortDrama(
        id: slug,
        title: title,
        coverUrl: cover,
        description: '$title · 黄瓜短剧精品全集',
        category: '黄瓜短剧',
        totalEpisodes: totalCount,
        rating: 9.8,
        playCount: '1.8万',
        badge: '黄瓜独家',
        updateInfo: '全 $totalCount 集',
        tags: ['黄瓜短剧', '全集完结', '高清直连'],
        episodes: episodes,
        itemType: 'drama',
      );
    } catch (_) {
      return null;
    }
  }

  /// 动态换取分集真实视频流播放地址（请求 /play/{slug}/{episodeNum} 提取签名直链）
  static Future<String?> fetchEpisodePlayUrl({
    required String rawBaseUrl,
    required String slug,
    required int episodeNum,
  }) async {
    final base = await resolveRealBaseUrl(rawBaseUrl);
    final epUrl = '$base/play/$slug/$episodeNum';

    try {
      final resp = await _dio.get<String>(
        epUrl,
        options: Options(
          headers: {
            'Referer': '$base/play/$slug/1',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          },
        ),
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final stream = extractStreamUrlFromHtml(resp.data!);
        if (stream.isNotEmpty) {
          return stream;
        }
      }
    } catch (_) {}

    // 备选线路提取
    for (final altBase in fallbackLines) {
      if (altBase == base) continue;
      try {
        final resp = await _dio.get<String>(
          '$altBase/play/$slug/$episodeNum',
          options: Options(
            headers: {'Referer': '$altBase/play/$slug/1'},
          ),
        );
        if (resp.statusCode == 200 && resp.data != null) {
          final stream = extractStreamUrlFromHtml(resp.data!);
          if (stream.isNotEmpty) {
            _resolvedLiveBaseUrl = altBase;
            return stream;
          }
        }
      } catch (_) {}
    }

    return null;
  }
}
