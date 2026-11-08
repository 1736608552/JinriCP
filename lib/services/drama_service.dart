import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import '../models/short_drama.dart';
import '../models/drama_comment.dart';
import 'settings_service.dart';
import 'hgdju_drama_service.dart';

class DramaService {
  // 套系一：经典短剧分类
  static final List<String> categories = [
    '🏠 首页',
    '🎬 AI成人短剧',
    '🎨 AI成人漫剧',
    '🎭 AI换脸',
    '⚡ AI魔改',
    '🏆 热门排行榜',
    '🍉 娱乐吃瓜',
    '📑 独家专题',
  ];

  static final List<String> subTabs = [
    '最新更新',
    '当前热播',
    '独家原创',
    '随机推荐',
  ];

  // 套系二：黄瓜短剧分类（1:1 对齐官方截图）
  static final List<String> hgdjuCategories = [
    '全部',
    '原创',
    '魔改',
    'AI漫剧',
    '真人短剧',
    'AI短剧',
  ];

  static final List<String> hgdjuLines = [
    '全部',
    '原创',
    '魔改',
    'AI漫剧',
    '真人短剧',
    'AI短剧',
  ];

  static final List<String> hgdjuTags = [
    '全部',
    '都市邻里',
    '甜宠恋爱',
    '古装玄幻',
    '逆袭',
    '复仇逆袭',
    '虐恋情深',
    '穿越重生',
    '惊悚悬疑',
    '霸总激情',
    '战神归来',
    '校园恋爱',
    '末世生存',
    '动漫魔改',
    '人妻出轨',
    '婚外偷情',
    '秘密情人',
    '主仆调教',
    '绿帽淫妻',
    '反差小花',
    '身体交易',
    '禁忌乱伦',
    '系统爽剧',
    '复仇爽剧',
    '密室调教',
    '潜规则秘恋',
    '换妻游戏',
    '娱乐潜规',
    '村妇养成',
    '交换伴侣',
    '仙侠情缘',
    '修真双修',
    '灵异情欲',
    '禁忌师生',
  ];

  static final List<String> hgdjuStatuses = [
    '全部',
    '连载中',
    '已完结',
  ];

  static final List<String> hgdjuSorts = [
    '最热',
    '最新',
    '追剧最多',
  ];

  static final List<String> hgdjuSubTabs = [
    '🔥 最热',
    '✨ 最新',
    '❤️ 追剧最多',
    '🟢 连载中',
    '🏁 已完结',
    '都市邻里',
    '甜宠恋爱',
    '古装玄幻',
    '逆袭',
    '复仇逆袭',
    '虐恋情深',
    '穿越重生',
    '惊悚悬疑',
    '霸总激情',
    '战神归来',
    '校园恋爱',
    '末世生存',
  ];

  /// 官方权威永久直连主站与高可用容灾镜像池（免翻墙全国直连秒开）
  static const List<String> officialDomains = [
    'https://ofagqv.gitiecgad.cc',
    'https://jkelfk.gitiecgad.cc',
    'https://vo60.gitiecgad.cc',
    'https://huangguoai.com',
    'https://hgai2.com',
    'https://huangguoai.ai',
    'https://huangguo8.com',
  ];

  /// 动态获取当前激活短剧套系的一级分类列表
  static List<String> getCurrentCategories() {
    if (SettingsService.dramaSourceTypeNotifier.value == SettingsService.dramaSourceHgdju) {
      return hgdjuCategories;
    }
    return categories;
  }

  /// 动态获取当前分类下的子标签列表
  static List<String> getCurrentSubTabs(String category) {
    if (SettingsService.dramaSourceTypeNotifier.value == SettingsService.dramaSourceHgdju) {
      return hgdjuSubTabs;
    }
    return getSubTabsForCategory(category);
  }

  /// 根据所选分类动态返回专属的子标签列表 (套系一专用)
  static List<String> getSubTabsForCategory(String category) {
    if (category.contains('首页')) {
      return ['🔥 精选推荐', '⚡ 最近新上'];
    }
    if (category.contains('排行') || category.contains('榜')) {
      return ['🔥 热播榜', '✨ 潜力原创榜', '🎲 随机推荐榜'];
    }
    if (category.contains('吃瓜') || category.contains('瓜')) {
      return ['🍉 最新爆料', '🔥 热门吃瓜', '🎨 AI原创专区'];
    }
    if (category.contains('专题')) {
      return ['📑 精选专辑'];
    }
    return subTabs;
  }

  // 广告外链路径特征与博彩引流特征（严格基于 URL 判断，绝不误伤短剧标题与剧情简介）
  static final List<String> _adUrlPathKeywords = [
    '/chan/', '/jump/', '/ads/', '/adv/', '/aff/', '/affiliate/',
    '/ssp/', '/tg/', '/traffic/', '/promo/', '/union/', '/track/',
    'api/ad', 'ad_click', 'redirect_to',
  ];

  static final List<String> _adExternalKeywords = [
    't.me', 'telegram.me', 'bit.ly', 'cutt.ly', 'tinyurl',
    'bet', 'casino', 'bocai', 'cp88', 'cp99', 'qp88', 'qp99',
    'kefu', 'chat-service', 'landing-page',
  ];

  static final Dio _dio = _createDramaDio();

  static Dio _createDramaDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ),
    );
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
    return dio;
  }

  /// 判断是否属于推广广告、博彩或不良外链（严格基于链接地址与广告位属性判定，绝不误伤剧情文本和正常短剧）
  static bool _isAdContent({
    String title = '',
    String desc = '',
    String href = '',
    List<String> tags = const [],
    bool isExplicitAd = false,
  }) {
    // 1. 如果带有明确的 SSP / 广告容器标识，确认为广告
    if (isExplicitAd) return true;

    final cleanHref = href.trim().toLowerCase();

    // 如果链接为空，但标题存在（如直接来自 API 纯数据源），不视为广告
    if (cleanHref.isEmpty) return false;

    // 2. 检查伪协议或无动作脚本链接
    if (cleanHref.startsWith('javascript:') ||
        cleanHref == '#' ||
        cleanHref.startsWith('about:') ||
        cleanHref.startsWith('vbscript:')) {
      return true;
    }

    // 🌟 3. 核心白名单：站内短剧详情、播放、分类、排行榜路由绝对放行（无论是相对路径还是带域名的完整URL）
    final isContentPath = cleanHref.contains('/detail') ||
        cleanHref.contains('/video') ||
        cleanHref.contains('/videos') ||
        cleanHref.contains('/play') ||
        cleanHref.contains('/ai-duanju') ||
        cleanHref.contains('/ai-manju') ||
        cleanHref.contains('/ai-huanlian') ||
        cleanHref.contains('/ai-mogai') ||
        cleanHref.contains('/duanju') ||
        cleanHref.contains('/manju') ||
        cleanHref.contains('/ranks') ||
        cleanHref.contains('/topic') ||
        cleanHref.contains('/topics') ||
        cleanHref.contains('/archives') ||
        cleanHref.contains('/chigua');

    // 4. 检查广告跳转路由与渠道分销特征（仅针对非内容白名单）
    for (final kw in _adUrlPathKeywords) {
      if (cleanHref.contains(kw)) {
        return true;
      }
    }

    // 5. 检查站外第三方推广与违规域名（基于 URL 判断）
    if (cleanHref.startsWith('http://') || cleanHref.startsWith('https://')) {
      try {
        final uri = Uri.parse(cleanHref);
        final host = uri.host.toLowerCase();

        // 如果包含站内内容路径特征，无论是否跨镜像域，绝对属于合法短剧放行！
        if (isContentPath) {
          return false;
        }

        // 如果是本站域名或官方镜像池域名，属于站内合法内容，非广告
        bool isOfficialHost = false;
        for (final domain in officialDomains) {
          final officialHost = Uri.tryParse(domain)?.host.toLowerCase() ?? '';
          if (officialHost.isNotEmpty && (host == officialHost || host.endsWith('.$officialHost'))) {
            isOfficialHost = true;
            break;
          }
        }
        if (_cachedWorkingDomain.isNotEmpty) {
          final curHost = Uri.tryParse(_cachedWorkingDomain)?.host.toLowerCase() ?? '';
          if (curHost.isNotEmpty && (host == curHost || host.endsWith('.$curHost'))) {
            isOfficialHost = true;
          }
        }
        // 官方图片 CDN 域名，非广告
        if (host.contains('wirqed.cn') || host.contains('tuafjz.cn') || host.contains('eanfog.cn')) {
          isOfficialHost = true;
        }

        // 如果不是官方站内域名，进一步检查是否为站外推广外链
        if (!isOfficialHost) {
          for (final kw in _adExternalKeywords) {
            if (host.contains(kw)) {
              return true;
            }
          }
          // 外链且不属于站内任何合法内容路由，判定为站外推广广告
          return true;
        }
      } catch (_) {}
    } else if (isContentPath) {
      // 站内相对内容路径，绝对放行
      return false;
    }

    // 严禁通过剧情文本（title / desc / tags）模糊匹配过滤，杜绝误杀正常短剧
    return false;
  }

  static String _cachedWorkingDomain = '';
  static String _lastConfiguredUrl = '';

  /// 清除已解析的工作节点缓存（在用户切换短剧源或更新地址时触发）
  static void clearWorkingDomainCache() {
    _cachedWorkingDomain = '';
    _lastConfiguredUrl = '';
  }

  /// 智能探测并解析活跃的实际内容节点
  /// 🌟 核心规范：无论用户输入任何地址（如 huangguoai.ai、huangguo4.com、huangguo2.com 等），
  /// 均访问该页面并保序提取其中的线路列表，【默认调用里面的第一个地址】！
  static Future<String> resolveWorkingDomain(String baseUrl) async {
    String raw = baseUrl.trim();
    if (raw.isEmpty) {
      raw = SettingsService.defaultClassicUrl;
    }
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    if (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }

    if (raw == _lastConfiguredUrl && _cachedWorkingDomain.isNotEmpty) {
      return _cachedWorkingDomain;
    }

    _lastConfiguredUrl = raw;
    final inputHost = Uri.tryParse(raw)?.host.toLowerCase() ?? '';

    // 1. 请求传入的源站发布页/内容页
    try {
      final directResp = await _dio.get<String>(
        raw,
        options: Options(
          receiveTimeout: const Duration(milliseconds: 4000),
          sendTimeout: const Duration(milliseconds: 4000),
          followRedirects: true,
        ),
      );

      if (directResp.statusCode == 200 && directResp.data != null) {
        final html = directResp.data!;

        // 🌟 2. 核心优先：从发布页中保序提取所有线路卡片，严格锁定【第一个地址】
        final List<String> extractedLines = [];

        try {
          final doc = html_parser.parse(html);

          // 规则 A：提取 .route-card 或带有 data-url 的卡片
          final cards = doc.querySelectorAll('.route-card, article[data-url], div[data-url]');
          for (final card in cards) {
            var u = card.attributes['data-url'] ?? '';
            if (u.isEmpty) {
              final btn = card.querySelector('a.use-btn, a[href^="http"]');
              u = btn?.attributes['href'] ?? '';
            }
            u = _cleanCandidateUrl(u);
            if (_isValidCandidateUrl(u, inputHost) && !extractedLines.contains(u)) {
              extractedLines.add(u);
            }
          }

          // 规则 B：提取包含“立即使用”、“打开线路”等文字的超链接
          if (extractedLines.isEmpty) {
            for (final a in doc.querySelectorAll('a.use-btn, a[href^="http"]')) {
              final text = a.text.trim();
              final aria = a.attributes['aria-label'] ?? '';
              if (text.contains('立即使用') || text.contains('进入') || text.contains('线路') || aria.contains('打开线路')) {
                final u = _cleanCandidateUrl(a.attributes['href'] ?? '');
                if (_isValidCandidateUrl(u, inputHost) && !extractedLines.contains(u)) {
                  extractedLines.add(u);
                }
              }
            }
          }
        } catch (_) {}

        // 规则 C：正则保序兜底提取所有 data-url="..."
        if (extractedLines.isEmpty) {
          final cardRegex = RegExp(r'data-url=["\x27](https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}[^"\x27]*)["\x27]', caseSensitive: false);
          for (final m in cardRegex.allMatches(html)) {
            final link = m.group(1) ?? '';
            final u = _cleanCandidateUrl(link);
            if (_isValidCandidateUrl(u, inputHost) && !extractedLines.contains(u)) {
              extractedLines.add(u);
            }
          }
        }

        // 🌟🌟🌟 核心指令执行：只要页面内存在线路列表，100% 默认调用里面的【第一个地址】！
        if (extractedLines.isNotEmpty) {
          final firstLine = extractedLines.first;
          _cachedWorkingDomain = firstLine;
          return firstLine;
        }

        // 3. 若页面本身无任何发布页线路，但直接包含短剧内容卡片（即本身就是真实内容站）
        if (html.contains('hg-drama-card') || html.contains('/detail/') || html.contains('/video/')) {
          _cachedWorkingDomain = raw;
          return raw;
        }
      }
    } catch (_) {}

    // 4. 若传入地址请求失败，直接返回原始规范化地址作为兜底
    _cachedWorkingDomain = raw;
    return raw;
  }

  static String _cleanCandidateUrl(String u) {
    var s = u.trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  static bool _isValidCandidateUrl(String u, String excludeHost) {
    if (u.isEmpty) return false;
    if (!u.startsWith('http://') && !u.startsWith('https://')) return false;
    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (excludeHost.isNotEmpty && (host == excludeHost || host.endsWith('.$excludeHost'))) return false;
    if (host.contains('google') ||
        host.contains('yandex') ||
        host.contains('twitter') ||
        host.contains('x.com') ||
        host.contains('telegram') ||
        host.contains('t.me') ||
        host.contains('github') ||
        host.contains('pages.dev')) {
      return false;
    }
    final path = uri.path.toLowerCase();
    if (path.contains('/chan/') || path.contains('.apk') || path.contains('download')) {
      return false;
    }
    return true;
  }

  static Future<String> _resolveWorkingDomain(String baseUrl) => resolveWorkingDomain(baseUrl);

  /// 统一的高可用 HTTP GET 请求（直连快速超时 + 镜像节点自愈重试 + 边缘代理保底）
  static Future<Response<String>?> _safeGet(
    String url, {
    bool isJson = false,
    String? referer,
    Duration directTimeout = const Duration(milliseconds: 3500),
  }) async {
    final Map<String, dynamic> headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      'Accept': isJson ? 'application/json' : 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };
    if (referer != null && referer.isNotEmpty) {
      headers['Referer'] = referer;
    }

    // 1. 直连请求（3.5 秒超时，避免直连被阻断时长时间挂起）
    try {
      final resp = await _dio.get<String>(
        url,
        options: Options(
          headers: headers,
          receiveTimeout: directTimeout,
          sendTimeout: directTimeout,
        ),
      );
      if (resp.statusCode == 200 && resp.data != null && resp.data!.isNotEmpty) {
        return resp;
      }
    } catch (_) {}

    // 2. 直连失败或超时，通过 Cloudflare 边缘代理节点穿透中继
    try {
      final customDomain = await SettingsService.getCustomDomain();
      final proxyHost = customDomain.isNotEmpty ? customDomain : 'https://zb.djseven.cc.cd';
      final proxyUrl = '$proxyHost/drama?url=${Uri.encodeComponent(url)}';
      final resp = await _dio.get<String>(
        proxyUrl,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
      if (resp.statusCode == 200 && resp.data != null && resp.data!.isNotEmpty) {
        return resp;
      }
    } catch (_) {}

    return null;
  }

  /// 获取分类对应的真实 URL 路径（与官方网页版 100% 对齐）
  static String _getCategoryPath(String category, {String subTab = '最新更新'}) {
    String base = '';
    if (category.contains('短剧')) base = '/ai-duanju/';
    else if (category.contains('漫剧')) base = '/ai-manju/';
    else if (category.contains('换脸')) base = '/ai-huanlian/';
    else if (category.contains('魔改')) base = '/ai-mogai/';

    if (base.isNotEmpty) {
      if (subTab.contains('热播') || subTab.contains('总热度') || subTab.contains('热度')) {
        return '$base?by=hits&sort=hot';
      } else if (subTab.contains('原创')) {
        return '$base?by=score&sort=original';
      } else if (subTab.contains('推荐') || subTab.contains('随机')) {
        return '$base?by=rand&sort=random&_t=${DateTime.now().millisecondsSinceEpoch}';
      }
      return base;
    }

    if (category.contains('排行') || category.contains('榜')) {
      if (subTab.contains('推荐') || subTab.contains('随机')) return '/ranks/recommend/';
      if (subTab.contains('原创') || subTab.contains('潜力')) return '/ranks/potential/';
      return '/ranks/hot/'; // 默认和热播都指向 hot
    }

    if (category.contains('吃瓜') || category.contains('瓜')) {
      if (subTab.contains('热播') || subTab.contains('热门')) return '/chigua/remen/';
      if (subTab.contains('原创')) return '/chigua/yuanchuang/';
      return '/chigua/'; // 默认和最新爆料
    }

    if (category.contains('专题')) {
      return '/topics/'; // 专题暂无子分类路由
    }

    // 首页或其他走查询参数
    String path = '/';
    if (subTab.contains('热播') || subTab.contains('总热度') || subTab.contains('热度')) {
      path += '?by=hits&sort=hot';
    } else if (subTab.contains('原创')) {
      path += '?by=score&sort=original';
    } else if (subTab.contains('推荐') || subTab.contains('随机')) {
      path += '?by=rand&sort=random&_t=${DateTime.now().millisecondsSinceEpoch}';
    }
    return path;
  }

  /// 获取分类对应的 JSON API 路径 slug（用于 /api/videos/category/{slug}）
  static String? _getCategoryApiSlug(String category) {
    if (category.contains('短剧')) return 'ai-duanju';
    if (category.contains('漫剧')) return 'ai-manju';
    if (category.contains('换脸')) return 'ai-huanlian';
    if (category.contains('魔改')) return 'ai-mogai';
    return null; // 首页、专题、排行榜、吃瓜暂无此 API
  }

  /// 将 JSON API 子排序映射为 query 参数（100% 忠实对齐官方前端 JS 调用的真实接口参数）
  static String _subTabToApiQuery(String subTab) {
    if (subTab.contains('热播') || subTab.contains('热门') || subTab.contains('总热度') || subTab.contains('热度')) {
      return 'sort=hot_window'; // 官方网页端当前热播/热门选项卡真实参数：sort=hot_window
    }
    if (subTab.contains('原创')) {
      return 'sort=hot_window&is_original=1'; // 官方网页端独家原创选项卡真实参数
    }
    if (subTab.contains('推荐') || subTab.contains('随机')) {
      return 'sort=random&_t=${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'sort=latest'; // 最新更新 = 显式传 sort=latest
  }

  /// 解析播放量数值工具方法
  static double parsePlayCountValue(String playCount) {
    if (playCount.isEmpty) return 0.0;
    try {
      String clean = playCount
          .replaceAll('🔥', '')
          .replaceAll('次播放', '')
          .replaceAll('播放', '')
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

  /// 将 JSON API 返回的 item 转换为 ShortDrama 对象
  static ShortDrama _apiItemToDrama(Map<String, dynamic> item, String category, String domain) {
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    var cover = item['cover']?.toString() ?? '';
    
    // 🌟 核心图片自愈：将失效旧 CDN (tuafjz.cn / eanfog.cn) 动态重写为当前真实活跃直连 CDN pic.wirqed.cn
    if (cover.contains('pic.tuafjz.cn')) {
      cover = cover.replaceAll('pic.tuafjz.cn', 'pic.wirqed.cn');
    } else if (cover.contains('pic.eanfog.cn')) {
      cover = cover.replaceAll('pic.eanfog.cn', 'pic.wirqed.cn');
    } else if (cover.startsWith('/upload')) {
      cover = 'https://pic.wirqed.cn$cover';
    } else if (cover.startsWith('/')) {
      final cleanDomain = domain.endsWith('/') ? domain.substring(0, domain.length - 1) : domain;
      cover = '$cleanDomain$cover';
    }

    final desc = item['desc']?.toString() ?? item['description']?.toString() ?? '精彩爆款剧情，超清在线。';
    final episodeCount = item['episode_count'] as int? ?? 1;
    final score = (item['score'] as num?)?.toDouble() ?? 8.8;
    final hot = item['hot'] as int? ?? 0;
    final isFinished = item['is_finished'] == true;
    final isOriginal = (item['is_original'] as int? ?? 0) == 1;
    final rawTags = (item['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    // 构建播放量文字
    String playCount;
    if (hot >= 10000000) {
      playCount = '${(hot / 10000000).toStringAsFixed(1)}千万';
    } else if (hot >= 10000) {
      playCount = '${(hot / 10000).toStringAsFixed(1)}万';
    } else if (hot > 0) {
      playCount = '$hot';
    } else {
      playCount = '${(score * 120 + 30).toStringAsFixed(1)}万';
    }

    // 构建角标
    String badge = item['badge']?.toString() ?? '';
    if (badge.isEmpty && isOriginal) badge = '黄果原创';

    // 构建更新状态
    String updateInfo = isFinished ? '全${episodeCount}集' : '更新至${episodeCount}集';

    // 构建分集列表
    final List<DramaEpisode> episodes = [];
    for (int i = 1; i <= episodeCount; i++) {
      episodes.add(DramaEpisode(
        episodeNum: i,
        title: '第 $i 集',
        videoUrl: '',
        embedUrl: '$domain/videos/embed/$id?ep=$i',
      ));
    }

    final dramaTags = <String>[];
    if (rawTags.isNotEmpty) {
      dramaTags.addAll(rawTags);
    } else {
      final cleanCat = category.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
      if (cleanCat.isNotEmpty) dramaTags.add(cleanCat);
    }
    if (category.isNotEmpty && !dramaTags.contains(category) && !category.contains('首页')) {
      final cleanCat = category.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
      if (cleanCat.isNotEmpty && !dramaTags.contains(cleanCat)) {
        dramaTags.insert(0, cleanCat);
      }
    }

    return ShortDrama(
      id: id,
      title: title,
      coverUrl: cover,
      description: desc,
      category: category,
      totalEpisodes: episodeCount,
      rating: score > 0 ? score : 9.2,
      playCount: playCount,
      badge: badge,
      updateInfo: updateInfo,
      tags: dramaTags,
      episodes: episodes,
    );
  }

  /// 通过官方 API 获取首页全量聚合短剧（首屏与翻页均涵盖全部分类全部内容，单页拉取上限100条，绝不仅取前几条）
  static Future<List<ShortDrama>> _fetchHomeFromApi({
    required String baseUrl,
    required String subTab,
    required int page,
  }) async {
    final slugs = [
      {'slug': 'ai-duanju', 'name': '🎬 AI成人短剧'},
      {'slug': 'ai-manju', 'name': '🎨 AI成人漫剧'},
      {'slug': 'ai-huanlian', 'name': '🎭 AI换脸'},
      {'slug': 'ai-mogai', 'name': '⚡ AI魔改'},
    ];

    final List<ShortDrama> allList = [];
    final Set<String> seenIds = {};

    void addItems(List<dynamic>? items, {String defaultCategory = '🔥 精选推荐'}) {
      if (items == null) return;
      for (final raw in items) {
        if (raw is Map<String, dynamic>) {
          final drama = _apiItemToDrama(raw, defaultCategory, baseUrl);
          final idKey = drama.id.trim();
          if (drama.title.isNotEmpty && !seenIds.contains(idKey)) {
            seenIds.add(idKey);
            allList.add(drama);
          }
        }
      }
    }

    // 1. 若为第 1 页且为最新更新子标签：才加载 /api/home 置顶推荐与分类数据（避免污染热播、原创与随机推荐）
    if (page == 1 && subTab.contains('最新')) {
      final apiUrl = '$baseUrl/api/home';
      try {
        final response = await _safeGet(apiUrl, isJson: true, referer: '$baseUrl/');
        if (response != null && response.statusCode == 200 && response.data != null) {
          final json = jsonDecode(response.data!);
          final data = json['data'] as Map<String, dynamic>?;
          if (data != null) {
            // 精选推荐与最新上新
            addItems(data['featured'] as List<dynamic>?, defaultCategory: '🔥 精选推荐');
            addItems(data['latest'] as List<dynamic>?, defaultCategory: '⚡ 最新上新');

            // 分类推荐
            final cateRec = data['cate_rec'];
            if (cateRec is List) {
              for (final catGroup in cateRec) {
                if (catGroup is Map<String, dynamic>) {
                  final catName = catGroup['cate_name']?.toString() ?? '分类精选';
                  final vids = catGroup['videos'] as List<dynamic>? ?? catGroup['items'] as List<dynamic>?;
                  addItems(vids, defaultCategory: catName);
                }
              }
            }
            addItems(data['banners'] as List<dynamic>?, defaultCategory: '✨ 热门爆款');
          }
        }
      } catch (_) {}
    }

    // 2. 核心全量拉取：无论第 1 页还是翻页，并发获取四大分类对应页的全部剧集（单次 size=100 上限拉满）
    try {
      final futures = slugs.map((s) => _fetchFromApi(
            baseUrl: baseUrl,
            category: s['name']!,
            subTab: subTab,
            page: page,
          ));
      final results = await Future.wait(futures);

      // Round-Robin 交织穿插聚合四大分类全部数据
      int maxLen = 0;
      for (final r in results) {
        if (r.length > maxLen) maxLen = r.length;
      }

      for (int i = 0; i < maxLen; i++) {
        for (final list in results) {
          if (i < list.length) {
            final d = list[i];
            final idKey = d.id.trim();
            if (!seenIds.contains(idKey)) {
              seenIds.add(idKey);
              allList.add(d);
            }
          }
        }
      }
    } catch (_) {}

    // 🎲 随机推荐保底洗牌：确保每次点击刷新均真随机
    if (subTab.contains('推荐') || subTab.contains('随机')) {
      allList.shuffle(Random(DateTime.now().microsecondsSinceEpoch));
    }

    // 🌟 忠实保留官方接口返回的原生排序，严禁客户端擅自按累计播放量降序重排而挤掉新片
    return allList;
  }

  /// 通过 JSON API 获取短剧列表（主要数据源，数据完整准确）
  static Future<List<ShortDrama>> _fetchFromApi({
    required String baseUrl,
    required String category,
    required String subTab,
    required int page,
  }) async {
    final slug = _getCategoryApiSlug(category);
    if (slug == null) return []; // 该分类无 API

    final subQuery = _subTabToApiQuery(subTab);
    // 🌟 严格对齐官方网站每页数量规格（SIZE=21），确保每一页的内容与网页端 100% 绝对一致
    String apiUrl = '$baseUrl/api/videos/category/$slug?page=$page&size=21';
    if (subQuery.isNotEmpty) {
      apiUrl += '&$subQuery';
    }

    final response = await _safeGet(apiUrl, isJson: true, referer: '$baseUrl/');
    if (response == null || response.statusCode != 200 || response.data == null) {
      return [];
    }

    try {
      final json = jsonDecode(response.data!);
      final items = json['data']?['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return [];

      final List<ShortDrama> list = [];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final drama = _apiItemToDrama(item, category, baseUrl);
          if (drama.title.isNotEmpty) {
            list.add(drama);
          }
        }
      }
      // 🌟 忠实保留官方接口原生排序（服务端接收 sort=hot/latest 后已完成权威排序，客户端严禁破坏）
      return list;
    } catch (_) {
      return [];
    }
  }

  /// 获取短剧列表（严格按分类与子排序拉取，支持分页）
  /// 优先使用 JSON API（数据完整，分页精确），失败时回退 HTML 解析
  static Future<List<ShortDrama>> fetchDramas({
    String category = '🏠 首页',
    String subTab = '最新更新',
    String keyword = '',
    int page = 1,
    String? hgdjuLine,
    String? hgdjuTag,
    String? hgdjuStatus,
    String? hgdjuSort,
  }) async {
    final rawBaseUrl = await SettingsService.getDramaBaseUrl();
    if (rawBaseUrl.isEmpty) {
      return [];
    }

    // 🌟 智能双源分发：如果当前启用或识别为黄瓜短剧（hgdju1.com /browse）套系
    final sourceType = await SettingsService.getDramaSourceType();
    if (sourceType == SettingsService.dramaSourceHgdju ||
        SettingsService.detectDramaSourceType(rawBaseUrl) == SettingsService.dramaSourceHgdju) {
      final line = hgdjuLine != null
          ? HgdjuDramaService.getLineSlug(hgdjuLine)
          : HgdjuDramaService.getLineSlug(category);
      final tag = hgdjuTag != null
          ? HgdjuDramaService.getTagSlug(hgdjuTag)
          : HgdjuDramaService.getTagSlug(subTab);
      final status = hgdjuStatus != null
          ? HgdjuDramaService.getStatusSlug(hgdjuStatus)
          : HgdjuDramaService.getStatusSlug(subTab);
      String sort = hgdjuSort != null
          ? HgdjuDramaService.getSortSlug(hgdjuSort)
          : 'hot';

      // 若未指定专属 sort，自动从 subTab 解析
      if (hgdjuSort == null) {
        if (subTab.contains('最新')) {
          sort = 'new';
        } else if (subTab.contains('追剧') || subTab.contains('最多')) {
          sort = 'fav';
        } else if (subTab.contains('最热')) {
          sort = 'hot';
        }
      }

      return await HgdjuDramaService.fetchDramas(
        rawBaseUrl: rawBaseUrl,
        line: line,
        tag: tag,
        status: status,
        sort: sort,
        page: page,
      );
    }

    final baseUrl = await resolveWorkingDomain(rawBaseUrl);
    final cleanKeyword = keyword.trim();

    // 1. 搜索模式：按搜索路由精确抓取
    if (cleanKeyword.isNotEmpty) {
      try {
        String targetUrl;
        if (category.contains('吃瓜') || category.contains('瓜')) {
          targetUrl = '$baseUrl/search/post/${Uri.encodeComponent(cleanKeyword)}/$page/';
        } else {
          targetUrl = page > 1
              ? '$baseUrl/search/video/${Uri.encodeComponent(cleanKeyword)}/$page/'
              : '$baseUrl/search/video/${Uri.encodeComponent(cleanKeyword)}/';
        }
        final response = await _safeGet(targetUrl, isJson: false, referer: '$baseUrl/');
        if (response != null && response.statusCode == 200 && response.data != null) {
          final parsed = _parseHtmlDramaList(response.data!, category: category, subTab: subTab, domain: baseUrl);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {}
      return [];
    }

    // 2. 首页聚合模式：优先通过真实网页 HTML 并发聚合四大分类，API 兜底
    if (category.contains('首页')) {
      try {
        final homeHtmlList = await _fetchHomeFromHtml(baseUrl: baseUrl, subTab: subTab, page: page);
        if (homeHtmlList.isNotEmpty) {
          return homeHtmlList;
        }
      } catch (_) {}

      // 保底走官方首页 API
      final homeApiResult = await _fetchHomeFromApi(
        baseUrl: baseUrl,
        subTab: subTab,
        page: page,
      );
      if (homeApiResult.isNotEmpty) {
        return homeApiResult;
      }
      return [];
    }

    // 🌟 3. 🎬 AI成人短剧 / 🎨 AI成人漫剧（最新更新 / 当前热播 / 独家原创 / 随机推荐 及其每一页 1:1 完全对齐）：
    if (category.contains('短剧') || category.contains('漫剧')) {
      final baseCatPath = category.contains('漫剧') ? '/ai-manju/' : '/ai-duanju/';

      // 🎲 随机推荐：必须保证 100% 真随机！绝不读取静态写死的 HTML 预渲染模板，直接请求带微秒时间戳的官方随机 API
      if (subTab.contains('推荐') || subTab.contains('随机')) {
        final randomResult = await _fetchFromApi(
          baseUrl: baseUrl,
          category: category,
          subTab: subTab,
          page: page,
        );
        if (randomResult.isNotEmpty) {
          // 双重保障：客户端配合时间戳进行二次真随机打乱洗牌，确保每次点击或下拉刷新都绝对是全新的随机短剧/漫剧
          final shuffled = List<ShortDrama>.from(randomResult)..shuffle(Random(DateTime.now().microsecondsSinceEpoch));
          return shuffled;
        }
      }

      // 最新更新：优先抓取官方真实静态 HTML 页面（/ai-duanju/ 或 /ai-manju/ 及其分页）
      if (subTab.contains('最新')) {
        try {
          final targetUrl = page > 1 ? '$baseUrl$baseCatPath$page/' : '$baseUrl$baseCatPath';
          final response = await _safeGet(targetUrl, isJson: false, referer: '$baseUrl/');
          if (response != null && response.statusCode == 200 && response.data != null) {
            // 防污染校验：若是漫剧，校验 HTML 是否确实属于漫剧，防止被源站 Nginx 错误回退至短剧
            final htmlLower = response.data!.toLowerCase();
            final isLegit = !category.contains('漫剧') || htmlLower.contains('漫剧') || htmlLower.contains('manju');
            if (isLegit) {
              final parsedList = _parseHtmlDramaList(
                response.data!,
                category: category,
                subTab: subTab,
                domain: baseUrl,
              );
              if (parsedList.isNotEmpty) {
                return parsedList;
              }
            }
          }
        } catch (_) {}
      } else if (page == 1) {
        // 当前热播 / 独家原创 的第 1 页：优先从源站 HTML 的预渲染模板中提取（100% 同步秒开）
        try {
          final targetUrl = '$baseUrl$baseCatPath';
          final response = await _safeGet(targetUrl, isJson: false, referer: '$baseUrl/');
          if (response != null && response.statusCode == 200 && response.data != null) {
            // 防污染校验：若是漫剧，校验预渲染模板是否属于漫剧
            final htmlLower = response.data!.toLowerCase();
            final isLegit = !category.contains('漫剧') || htmlLower.contains('漫剧') || htmlLower.contains('manju');
            if (isLegit) {
              final parsedList = _parseHtmlDramaList(
                response.data!,
                category: category,
                subTab: subTab,
                domain: baseUrl,
              );
              if (parsedList.isNotEmpty) {
                return parsedList;
              }
            }
          }
        } catch (_) {}
      }

      // 翻页（page > 1）或 HTML 为空/被Nginx回退时，调用官方专属 API（精准带上 sort=hot_window 等参数，单页 21 条）
      final apiFallback = await _fetchFromApi(
        baseUrl: baseUrl,
        category: category,
        subTab: subTab,
        page: page,
      );
      if (apiFallback.isNotEmpty) {
        return apiFallback;
      }
    }

    // 🌟 4. 🎭 AI换脸 / ⚡ AI魔改（独立专属分类）：
    // 核心解决分类雷同缺陷，直接调用专属 API，确保分类内容各自独立！
    if (category.contains('换脸') || category.contains('魔改')) {
      final apiResult = await _fetchFromApi(
        baseUrl: baseUrl,
        category: category,
        subTab: subTab,
        page: page,
      );
      if (apiResult.isNotEmpty) {
        if (subTab.contains('推荐') || subTab.contains('随机')) {
          final shuffled = List<ShortDrama>.from(apiResult)..shuffle(Random(DateTime.now().microsecondsSinceEpoch));
          return shuffled;
        }
        return apiResult;
      }
    }

    // 🌟 5. 排行榜 / 吃瓜 / 专题 板块：源站有独立 HTML，优先抓取真实 HTML 页面
    try {
      final catPath = _getCategoryPath(category, subTab: subTab);
      String targetUrl;
      if (page > 1) {
        final cleanPath = catPath.contains('?') ? catPath.split('?').first : catPath;
        final queryStr = catPath.contains('?') ? '?${catPath.split('?').last}' : '';
        if (cleanPath == '/chigua/' || cleanPath == '/chigua') {
          targetUrl = '$baseUrl/chigua/page/$page/$queryStr';
        } else {
          final normalizedPath = cleanPath.endsWith('/') ? cleanPath : '$cleanPath/';
          targetUrl = '$baseUrl$normalizedPath$page/$queryStr';
        }
      } else {
        targetUrl = '$baseUrl$catPath';
      }

      final response = await _safeGet(targetUrl, isJson: false, referer: '$baseUrl/');
      if (response != null && response.statusCode == 200 && response.data != null) {
        final parsedList = _parseHtmlDramaList(
          response.data!,
          category: category,
          subTab: subTab,
          domain: baseUrl,
        );
        if (parsedList.isNotEmpty) {
          return parsedList;
        }
      }
    } catch (_) {}

    return await _fetchFromApi(
      baseUrl: baseUrl,
      category: category,
      subTab: subTab,
      page: page,
    );
  }

  /// 从官方网页 HTML 真实页面聚合首页内容（100% 忠实对齐官方首页两大板块：精选推荐 与 最近上新）
  static Future<List<ShortDrama>> _fetchHomeFromHtml({
    required String baseUrl,
    required String subTab,
    required int page,
  }) async {
    final List<ShortDrama> mergedHome = [];
    final Set<String> seenIds = {};
    final Set<String> seenTitles = {};

    void addDramas(List<ShortDrama> dramas) {
      for (final it in dramas) {
        final idKey = it.id.trim();
        final titleKey = it.title.trim().toLowerCase();
        if (idKey.isNotEmpty && !seenIds.contains(idKey) && !seenTitles.contains(titleKey)) {
          seenIds.add(idKey);
          seenTitles.add(titleKey);
          mergedHome.add(it);
        }
      }
    }

    // 🎲 0. 随机推荐兜底保障：若请求随机推荐，绝不读静态模板，实时拉取 API 并客户端微秒真随机打乱洗牌
    if (subTab.contains('推荐') && (subTab.contains('随机') || subTab.contains('换一批'))) {
      final futures = [
        _fetchFromApi(baseUrl: baseUrl, category: '🎬 AI成人短剧', subTab: '随机推荐', page: page),
        _fetchFromApi(baseUrl: baseUrl, category: '🎨 AI成人漫剧', subTab: '随机推荐', page: page),
      ];
      final results = await Future.wait(futures);
      final List<ShortDrama> allRandom = [];
      for (final r in results) {
        allRandom.addAll(r);
      }
      if (allRandom.isNotEmpty) {
        allRandom.shuffle(Random(DateTime.now().microsecondsSinceEpoch));
        return allRandom;
      }
      return [];
    }

    // ⚡ 1. 【最近新上 / 最近上新】：
    if (subTab.contains('新') || subTab.contains('上新')) {
      if (page == 1) {
        // 第 1 页优先抓取官方首页根路径 HTML 中 <section> 中的“最近上新”卡片列表
        try {
          final rootResp = await _safeGet('$baseUrl/', isJson: false, referer: '$baseUrl/');
          if (rootResp != null && rootResp.statusCode == 200 && rootResp.data != null) {
            final latestItems = _parseHtmlDramaList(rootResp.data!, category: '🏠 首页', subTab: '最近上新', domain: baseUrl);
            addDramas(latestItems);
          }
        } catch (_) {}

        // 并发拉取官方短剧与漫剧最新更新 API 作为充盈补充
        final futures = [
          _fetchFromApi(baseUrl: baseUrl, category: '🎬 AI成人短剧', subTab: '最新更新', page: 1),
          _fetchFromApi(baseUrl: baseUrl, category: '🎨 AI成人漫剧', subTab: '最新更新', page: 1),
        ];
        final results = await Future.wait(futures);
        int maxLen = 0;
        for (final r in results) {
          if (r.length > maxLen) maxLen = r.length;
        }
        for (int i = 0; i < maxLen; i++) {
          for (final list in results) {
            if (i < list.length) {
              final it = list[i];
              final idKey = it.id.trim();
              final titleKey = it.title.trim().toLowerCase();
              if (!seenIds.contains(idKey) && !seenTitles.contains(titleKey)) {
                seenIds.add(idKey);
                seenTitles.add(titleKey);
                mergedHome.add(it);
              }
            }
          }
        }
        return mergedHome;
      } else {
        // 翻页（page > 1）：直连官方短剧与漫剧最新更新专属 API（单页 size=21），分页 1:1 对齐
        final futures = [
          _fetchFromApi(baseUrl: baseUrl, category: '🎬 AI成人短剧', subTab: '最新更新', page: page),
          _fetchFromApi(baseUrl: baseUrl, category: '🎨 AI成人漫剧', subTab: '最新更新', page: page),
        ];
        final results = await Future.wait(futures);
        int maxLen = 0;
        for (final r in results) {
          if (r.length > maxLen) maxLen = r.length;
        }
        for (int i = 0; i < maxLen; i++) {
          for (final list in results) {
            if (i < list.length) {
              final it = list[i];
              final idKey = it.id.trim();
              final titleKey = it.title.trim().toLowerCase();
              if (!seenIds.contains(idKey) && !seenTitles.contains(titleKey)) {
                seenIds.add(idKey);
                seenTitles.add(titleKey);
                mergedHome.add(it);
              }
            }
          }
        }
        return mergedHome;
      }
    }

    // 🔥 2. 【精选推荐】（官方首页首屏核心板块）：
    if (page == 1) {
      // 第 1 页优先抓取官方首页根路径 HTML 中 <section> 中的“精选推荐”卡片列表
      try {
        final rootResp = await _safeGet('$baseUrl/', isJson: false, referer: '$baseUrl/');
        if (rootResp != null && rootResp.statusCode == 200 && rootResp.data != null) {
          final featItems = _parseHtmlDramaList(rootResp.data!, category: '🏠 首页', subTab: '精选推荐', domain: baseUrl);
          addDramas(featItems);
        }
      } catch (_) {}

      // 并发拉取官方短剧与漫剧当前热播 API 作为热榜补充
      final futures = [
        _fetchFromApi(baseUrl: baseUrl, category: '🎬 AI成人短剧', subTab: '当前热播', page: 1),
        _fetchFromApi(baseUrl: baseUrl, category: '🎨 AI成人漫剧', subTab: '当前热播', page: 1),
      ];
      final results = await Future.wait(futures);
      int maxLen = 0;
      for (final r in results) {
        if (r.length > maxLen) maxLen = r.length;
      }
      for (int i = 0; i < maxLen; i++) {
        for (final list in results) {
          if (i < list.length) {
            final it = list[i];
            final idKey = it.id.trim();
            final titleKey = it.title.trim().toLowerCase();
            if (!seenIds.contains(idKey) && !seenTitles.contains(titleKey)) {
              seenIds.add(idKey);
              seenTitles.add(titleKey);
              mergedHome.add(it);
            }
          }
        }
      }
      return mergedHome;
    } else {
      // 翻页（page > 1）：直连官方短剧与漫剧热播专属 API（单页 size=21），保障精选内容持续供给
      final futures = [
        _fetchFromApi(baseUrl: baseUrl, category: '🎬 AI成人短剧', subTab: '当前热播', page: page),
        _fetchFromApi(baseUrl: baseUrl, category: '🎨 AI成人漫剧', subTab: '当前热播', page: page),
      ];
      final results = await Future.wait(futures);
      int maxLen = 0;
      for (final r in results) {
        if (r.length > maxLen) maxLen = r.length;
      }
      for (int i = 0; i < maxLen; i++) {
        for (final list in results) {
          if (i < list.length) {
            final it = list[i];
            final idKey = it.id.trim();
            final titleKey = it.title.trim().toLowerCase();
            if (!seenIds.contains(idKey) && !seenTitles.contains(titleKey)) {
              seenIds.add(idKey);
              seenTitles.add(titleKey);
              mergedHome.add(it);
            }
          }
        }
      }
      return mergedHome;
    }
  }

  /// 从 HTML 源码中解析纯净短剧列表，全量提取所有卡片内容、彻底过滤广告卡片并修复海报图片
  static List<ShortDrama> _parseHtmlDramaList(
    String htmlContent, {
    String category = '🔥 精选推荐',
    String subTab = '最新更新',
    String domain = '',
  }) {
    final List<ShortDrama> list = [];
    final document = html_parser.parse(htmlContent);

    // 🌟 核心突破：精准隔离官方选项卡专属容器，彻底避免置顶推广位或其它面板卡片混入
    // - 最新更新：.hg-card-grid[data-channel-panel="latest"]
    // - 当前热播：template[data-panel-cards="hot"]
    // - 独家原创：template[data-panel-cards="original"]
    // - 随机推荐：template[data-panel-cards="random"]
    html_dom.Document? templateDoc;
    if (subTab.contains('热播') || subTab.contains('热门')) {
      final match = RegExp(r'<template[^>]*data-panel-cards=["\x27]hot["\x27][^>]*>(.*?)</template>', dotAll: true).firstMatch(htmlContent);
      if (match != null && match.group(1) != null) {
        templateDoc = html_parser.parse(match.group(1)!);
      }
    } else if (subTab.contains('原创')) {
      final match = RegExp(r'<template[^>]*data-panel-cards=["\x27]original["\x27][^>]*>(.*?)</template>', dotAll: true).firstMatch(htmlContent);
      if (match != null && match.group(1) != null) {
        templateDoc = html_parser.parse(match.group(1)!);
      }
    } else if (subTab.contains('推荐') || subTab.contains('随机')) {
      final match = RegExp(r'<template[^>]*data-panel-cards=["\x27]random["\x27][^>]*>(.*?)</template>', dotAll: true).firstMatch(htmlContent);
      if (match != null && match.group(1) != null) {
        templateDoc = html_parser.parse(match.group(1)!);
      }
    }

    final docToQuery = templateDoc ?? document;
    html_dom.Element? targetContainer;
    if (category.contains('首页')) {
      if (subTab.contains('新') || subTab.contains('上新')) {
        for (final sec in document.querySelectorAll('section, .hg-section')) {
          final t = sec.text;
          if (t.contains('最近上新') || t.contains('最新上新') || t.contains('最近新上')) {
            targetContainer = sec;
            break;
          }
        }
      } else {
        for (final sec in document.querySelectorAll('section, .hg-section')) {
          final t = sec.text;
          if (t.contains('精选推荐') || t.contains('精选')) {
            targetContainer = sec;
            break;
          }
        }
      }
    } else if (templateDoc == null && subTab.contains('最新')) {
      targetContainer = document.querySelector('.hg-card-grid[data-channel-panel="latest"]') ??
          document.querySelector('[data-channel-panel="latest"]');
    }

    final queryScope = targetContainer ?? docToQuery.body ?? docToQuery.documentElement!;

    // 全量获取作用域中所有合法的短剧/漫剧/换脸/魔改/专题/排行榜/吃瓜/分类推荐卡片元素
    final rawCards = queryScope.querySelectorAll(
      '.hg-drama-card, [data-drama-card], .drama-card, .video-item, '
      '.hg-category-item, [class*="category-item"], .hg-hero__thumb, .hg-hero__thumb-panel, [class*="hero__thumb"], '
      '.hg-topic-card, .topic-card, .topic-item, [data-topic-id], '
      '.hg-rank-item, .hg-rank-card, .rank-card, .rank-item, [data-rank-id], [data-rank-item], '
      '.hg-post-card, .hg-chigua-card, .hg-article-card, .chigua-card, .article-card, .news-item, [data-article-id], '
      '.module-item, .hl-list-item, .vodlist_item, .myui-vodlist__thumb, .stui-vodlist__thumb, .public-list-exp, '
      '[class*="drama-card"], [class*="video-item"], [class*="topic-card"], [class*="chigua-card"], [class*="rank-item"], [class*="post-card"]',
    );

    // 严密过滤嵌套子元素：如果 card 已经在另一个已被匹配的 card 内部，直接跳过，防止父子同时被解析产生重复卡片
    final List<dynamic> cardElements = [];
    for (final card in rawCards) {
      bool isNested = false;
      var parentEl = card.parent;
      while (parentEl != null) {
        if (rawCards.contains(parentEl)) {
          isNested = true;
          break;
        }
        parentEl = parentEl.parent;
      }
      if (!isNested) {
        cardElements.add(card);
      }
    }

    // 智能回退抓取带有链接的卡片容器
    if (cardElements.isEmpty) {
      cardElements.addAll(queryScope.querySelectorAll('a[href*="/detail/"], a[href*="/video/"], a[href*="/play/"], a[href*="/topics/"], a[href*="/topic/"], a[href*="/archives/"], a[href*="/chigua/"]'));
    }

    for (final card in cardElements) {
      // 1. 过滤带有广告标记的插槽及侧边栏推荐（如搜索建议）
      bool isAdSlot = false;
      var parentEl = card.parent;
      while (parentEl != null) {
        if (parentEl.classes.contains('hg-ssp-slot') || 
            parentEl.attributes.containsKey('data-ssp-slot-key') ||
            parentEl.classes.contains('hg-search-suggest') ||
            parentEl.classes.contains('hg-search-suggest__guess') ||
            parentEl.classes.contains('hg-play__related')) {
          isAdSlot = true;
          break;
        }
        parentEl = parentEl.parent;
      }
      if (isAdSlot || card.querySelector('[data-ssp-slot-key]') != null) {
        continue;
      }

      // 2. 提取剧集/专题/排行榜/吃瓜 ID 与详情链接
      html_dom.Element? linkEl;
      for (final a in card.querySelectorAll('a')) {
        final aHref = (a.attributes['href'] ?? '').trim();
        // 排除纯分类路由（如 /ai-duanju/、/ai-manju/ 等分类主页导航）
        if (aHref == '/ai-duanju/' ||
            aHref == '/ai-duanju' ||
            aHref == '/ai-manju/' ||
            aHref == '/ai-manju' ||
            aHref == '/ai-huanlian/' ||
            aHref == '/ai-huanlian' ||
            aHref == '/ai-mogai/' ||
            aHref == '/ai-mogai' ||
            aHref == '/chigua/' ||
            aHref == '/chigua' ||
            aHref == '/topics/' ||
            aHref == '/topics' ||
            aHref == '/ranks/' ||
            aHref == '/ranks' ||
            aHref == '/' ||
            aHref == '#') {
          continue;
        }
        if (aHref.contains('/detail') ||
            aHref.contains('/video') ||
            aHref.contains('/videos') ||
            aHref.contains('/play') ||
            aHref.contains('/archives') ||
            aHref.contains('/topic') ||
            aHref.contains('/art') ||
            aHref.contains('/news') ||
            aHref.contains('/duanju') ||
            aHref.contains('/manju') ||
            aHref.contains('/v/') ||
            aHref.contains('/ad/')) {
          linkEl = a;
          break;
        }
      }
      linkEl ??= card.querySelector('a[href*="/detail/"]') ??
          card.querySelector('a[href*="/video/"]') ??
          card.querySelector('a[href*="/videos/"]') ??
          card.querySelector('a[href*="/play/"]') ??
          card.querySelector('a[href*="/topics/"]') ??
          card.querySelector('a[href*="/topic/"]') ??
          card.querySelector('a[href*="/archives/"]') ??
          card.querySelector('a[href*="/chigua/"]') ??
          card.querySelector('a[href*="/duanju/"]') ??
          card.querySelector('a[href*="/manju/"]') ??
          card.querySelector('a[href*="/art/"]') ??
          card.querySelector('a[href*="/news/"]') ??
          (card.localName == 'a' ? card : card.querySelector('a'));
      final href = linkEl?.attributes['href'] ?? '';
      final trackId = card.attributes['data-track-id'] ??
          card.attributes['data-topic-id'] ??
          card.attributes['data-rank-id'] ??
          card.attributes['data-id'] ??
          '';

      String dramaId = trackId;
      if (dramaId.isEmpty && href.isNotEmpty) {
        final match = RegExp(r'/(?:detail|topic|topics|archives|chigua|art|news|video|videos|play|ranks|duanju|manju|ai-duanju|ai-manju|ai-huanlian|ai-mogai|ad|v)/([a-zA-Z0-9_-]+)').firstMatch(href);
        if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
          final candidate = match.group(1)!;
          if (candidate != 'duanju' && candidate != 'manju' && candidate != 'page') {
            dramaId = candidate;
          }
        }
      }
      if (dramaId.isEmpty && href.isNotEmpty && href != '/' && href != '#') {
        dramaId = href.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      }

      // 判定条目形态类型 (itemType) 与元数据提取
      String itemType = 'drama';
      String extraMeta = '';
      int rankNum = 0;

      if (category.contains('专题') || card.classes.contains('hg-topic-card') || href.contains('/topics/') || href.contains('/topic/')) {
        itemType = 'topic';
        final metaEl = card.querySelector('.hg-topic-card__meta, .topic-meta, [class*="meta"]');
        if (metaEl != null) {
          extraMeta = metaEl.text.trim();
        }
      } else if (category.contains('吃瓜') || card.classes.contains('hg-post-card') || href.contains('/archives/') || href.contains('/chigua/')) {
        itemType = 'gossip';
        final userEl = card.querySelector('.hg-post-card__user');
        final dateEl = card.querySelector('.hg-post-card__date');
        final catEl = card.querySelector('.hg-post-card__cat');
        List<String> metaParts = [];
        if (userEl != null && userEl.text.trim().isNotEmpty) metaParts.add(userEl.text.trim());
        if (dateEl != null && dateEl.text.trim().isNotEmpty) metaParts.add(dateEl.text.trim());
        if (catEl != null && catEl.text.trim().isNotEmpty) metaParts.add(catEl.text.trim());
        extraMeta = metaParts.join(' · ');
      } else if (category.contains('排行') || category.contains('榜') || card.classes.contains('hg-rank-item') || card.attributes.containsKey('data-rank-item')) {
        itemType = 'drama';
        final rankNumEl = card.querySelector('.hg-rank-num, .rank-num, [class*="rank-num"]');
        if (rankNumEl != null) {
          rankNum = int.tryParse(rankNumEl.text.trim()) ?? 0;
        }
      }

      // 3. 提取标题
      final titleEl = card.querySelector('.hg-category-item__title') ??
          card.querySelector('.hg-hero__thumb-title') ??
          card.querySelector('.hg-hero__title') ??
          card.querySelector('.hg-drama-card__title a') ??
          card.querySelector('.hg-drama-card__title') ??
          card.querySelector('.hg-rank-item__title a') ??
          card.querySelector('.hg-rank-item__title') ??
          card.querySelector('.hg-topic-card__title a') ??
          card.querySelector('.hg-topic-card__title') ??
          card.querySelector('.topic-title') ??
          card.querySelector('.chigua-title') ??
          card.querySelector('.title a') ??
          card.querySelector('.name a') ??
          card.querySelector('.name') ??
          card.querySelector('h3') ??
          card.querySelector('h2') ??
          card.querySelector('h4') ??
          card.querySelector('.title');
      var title = titleEl?.text.trim() ?? card.attributes['data-track-title'] ?? card.attributes['title'] ?? '';
      if (title.isEmpty) {
        final imgEl = card.querySelector('img');
        title = imgEl?.attributes['alt'] ?? imgEl?.attributes['title'] ?? '';
      }
      if (title.isEmpty) continue;
      if (dramaId.isEmpty) {
        dramaId = title.hashCode.abs().toString();
      }

      // 4. 提取封面图（全属性深度探测 + 自动转 HTTPS + 补全绝对路径）
      final allImgs = card.querySelectorAll('img');
      String coverUrl = '';
      for (final imgEl in allImgs) {
        final candidates = [
          imgEl.attributes['data-original'],
          imgEl.attributes['data-src'],
          imgEl.attributes['data-lazy-src'],
          imgEl.attributes['data-url'],
          imgEl.attributes['data-poster'],
          imgEl.attributes['data-cover'],
          imgEl.attributes['data-thumb'],
          imgEl.attributes['data-bg'],
          imgEl.attributes['data-echo'],
          imgEl.attributes['data-actualsrc'],
          imgEl.attributes['src'],
        ];
        for (final c in candidates) {
          if (c != null &&
              c.trim().isNotEmpty &&
              !c.startsWith('data:image/svg') &&
              !c.endsWith('.gif') &&
              !c.contains('loading') &&
              !c.contains('placeholder') &&
              !c.contains('default_cover')) {
            coverUrl = c.trim();
            break;
          }
        }
        if (coverUrl.isNotEmpty) break;
      }

      if (coverUrl.isEmpty) {
        final bgElements = card.querySelectorAll('[style*="background"], .hg-drama-card__cover, .cover, .thumb');
        for (final el in bgElements) {
          final style = el.attributes['style'] ?? '';
          final bgMatch = RegExp(r'''url\(["']?([^"')]+)["']?\)''').firstMatch(style);
          if (bgMatch != null) {
            coverUrl = bgMatch.group(1)!.trim();
            break;
          }
        }
      }

      if (coverUrl.isEmpty) {
        for (final attr in card.attributes.entries) {
          final val = attr.value.trim();
          if (val.contains(RegExp(r'\.(?:jpg|jpeg|png|webp|avif)', caseSensitive: false))) {
            coverUrl = val;
            break;
          }
        }
      }

      // 规范化图片 URL：去除引号与 HTML 实体，自动补全 HTTPS 与绝对路径
      coverUrl = coverUrl.replaceAll('&amp;', '&').replaceAll('"', '').replaceAll("'", '').trim();

      // 🌟 核心图片自愈：替换失效旧 CDN 域名
      if (coverUrl.contains('pic.tuafjz.cn')) {
        coverUrl = coverUrl.replaceAll('pic.tuafjz.cn', 'pic.wirqed.cn');
      } else if (coverUrl.contains('pic.eanfog.cn')) {
        coverUrl = coverUrl.replaceAll('pic.eanfog.cn', 'pic.wirqed.cn');
      }

      final cleanDomain = domain.endsWith('/') ? domain.substring(0, domain.length - 1) : domain;
      if (coverUrl.startsWith('//')) {
        coverUrl = 'https:$coverUrl';
      } else if (coverUrl.startsWith('http://')) {
        coverUrl = 'https://${coverUrl.substring(7)}';
      } else if (coverUrl.startsWith('/upload')) {
        coverUrl = 'https://pic.wirqed.cn$coverUrl';
      } else if (coverUrl.startsWith('/') && cleanDomain.isNotEmpty) {
        coverUrl = '$cleanDomain$coverUrl';
      } else if (coverUrl.isNotEmpty && !coverUrl.startsWith('http') && cleanDomain.isNotEmpty) {
        coverUrl = '$cleanDomain/$coverUrl';
      }

      // 5. 提取评分与更新集数
      final scoreEl = card.querySelector('.hg-drama-card__score') ?? card.querySelector('.score');
      double rating = 8.8;
      if (scoreEl != null) {
        final scoreText = scoreEl.text.replaceAll('分', '').trim();
        rating = double.tryParse(scoreText) ?? 8.8;
      }

      final epEl = card.querySelector('.hg-drama-card__episode') ?? card.querySelector('.episode');
      final epText = epEl?.text.trim() ?? '全集';
      int totalEpisodes = 1;
      final epMatch = RegExp(r'(\d+)集').firstMatch(epText);
      if (epMatch != null) {
        totalEpisodes = int.tryParse(epMatch.group(1)!) ?? 1;
      }

      // 提取排行榜热力指数
      final heatEl = card.querySelector('.hg-rank-item__heat-value, .hg-rank-metric-value, [class*="heat-value"]');
      String heatStr = '';
      if (heatEl != null && heatEl.text.trim().isNotEmpty) {
        heatStr = heatEl.text.trim();
      }

      // 提取角标
      final badgeEl = card.querySelector('.badge, .tag-new, .hg-drama-card__badge, .hg-topic-card__badge, .rank-num, .num, [class*="badge"], .new-tag');
      var badge = badgeEl?.text.trim() ?? '';
      if (badge.isEmpty) {
        if (itemType == 'topic') {
          badge = '专题专辑';
        } else if (itemType == 'gossip') {
          badge = '吃瓜爆料';
        } else if (rankNum > 0) {
          badge = 'TOP $rankNum';
        } else if (category.contains('排行') || category.contains('榜')) {
          badge = '榜单热推';
        }
      }

      final timeEl = card.querySelector('.time, .date, [class*="time"], [class*="date"]');
      String updateInfo = epText;
      if (timeEl != null) {
        final t = timeEl.text.trim();
        if (t.isNotEmpty && !updateInfo.contains(t)) {
          updateInfo = '$t · $updateInfo';
        }
      }
      if (extraMeta.isNotEmpty && itemType == 'topic') {
        updateInfo = extraMeta;
      }

      // 6. 提取简介与标签
      final descEl = card.querySelector('.hg-category-item__desc') ??
          card.querySelector('.hg-drama-card__desc') ??
          card.querySelector('.hg-rank-item__desc') ??
          card.querySelector('.desc');
      final desc = descEl?.text.trim() ?? (itemType == 'gossip' ? '最新吃瓜八卦爆料' : '精彩爆款剧情，超清在线。');

      // 动态识别来自分类推荐列的具体分类（如 AI成人短剧、AI成人漫剧、AI换脸、AI魔改）
      String itemCategory = category;
      var parentCol = card.parent;
      while (parentCol != null) {
        if (parentCol.classes.contains('hg-category-col')) {
          final colTitleEl = parentCol.querySelector('.hg-category-col__title') ?? parentCol.querySelector('h3');
          if (colTitleEl != null && colTitleEl.text.trim().isNotEmpty) {
            itemCategory = colTitleEl.text.trim();
          }
          break;
        }
        parentCol = parentCol.parent;
      }

      final tagElements = card.querySelectorAll('.hg-tag, .tag, [class*="tag"], .hg-rank-item__tags span');
      final List<String> tags = [];
      for (final t in tagElements) {
        final tagText = t.text.replaceAll('·', '').trim();
        if (tagText.isNotEmpty && tagText.length < 10 && !tags.contains(tagText) && !tagText.contains('分')) {
          tags.add(tagText);
        }
      }
      if (itemCategory.isNotEmpty && !itemCategory.contains('首页')) {
        final cleanCat = itemCategory.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
        if (cleanCat.isNotEmpty && !tags.contains(cleanCat)) {
          tags.insert(0, cleanCat);
        }
      }
      if (tags.isEmpty) {
        tags.add(itemCategory.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), ''));
      }

      // 7. 严格广告与博彩校验
      if (_isAdContent(title: title, desc: desc, href: href, tags: tags)) {
        continue;
      }

      // 8. 构造分集列表
      final List<DramaEpisode> episodes = [];
      if (itemType == 'drama') {
        for (int i = 1; i <= totalEpisodes; i++) {
          episodes.add(DramaEpisode(
            episodeNum: i,
            title: '第 $i 集',
            videoUrl: '',
            embedUrl: '$domain/videos/embed/$dramaId?ep=$i',
          ));
        }
      }

      String playCountText = heatStr.isNotEmpty 
          ? '🔥 热度 $heatStr' 
          : '${(rating * 120 + 30).toStringAsFixed(1)}万';

      // 严格仅在片名完全相同且非空时去重融合（片名不同绝对不去重，杜绝误杀）
      final cleanTitle = title.trim().toLowerCase();
      final existingIndex = list.indexWhere((d) =>
          cleanTitle.isNotEmpty && d.title.trim().toLowerCase() == cleanTitle);

      if (existingIndex >= 0) {
        final existing = list[existingIndex];
        if (existing.description.contains('精彩爆款剧情') && !desc.contains('精彩爆款剧情')) {
          list[existingIndex] = ShortDrama(
            id: existing.id.length < dramaId.length ? dramaId : existing.id,
            title: existing.title,
            coverUrl: existing.coverUrl.isNotEmpty ? existing.coverUrl : coverUrl,
            description: desc,
            category: itemCategory != '🏠 首页' ? itemCategory : existing.category,
            totalEpisodes: totalEpisodes > 1 ? totalEpisodes : existing.totalEpisodes,
            rating: rating > 0 ? rating : existing.rating,
            playCount: heatStr.isNotEmpty ? '🔥 热度 $heatStr' : existing.playCount,
            badge: existing.badge.isNotEmpty ? existing.badge : badge,
            updateInfo: existing.updateInfo.isNotEmpty ? existing.updateInfo : updateInfo,
            tags: tags.length > existing.tags.length ? tags : existing.tags,
            episodes: existing.episodes.isNotEmpty ? existing.episodes : episodes,
            itemType: itemType,
            extraMeta: extraMeta.isNotEmpty ? extraMeta : existing.extraMeta,
            rankNum: rankNum > 0 ? rankNum : existing.rankNum,
          );
        }
      } else {
        list.add(ShortDrama(
          id: dramaId,
          title: title,
          coverUrl: coverUrl,
          description: desc,
          category: itemCategory,
          totalEpisodes: totalEpisodes,
          rating: rating,
          playCount: playCountText,
          badge: badge,
          updateInfo: updateInfo,
          tags: tags.isNotEmpty ? tags : ['短剧', '超清'],
          episodes: episodes,
          itemType: itemType,
          extraMeta: extraMeta,
          rankNum: rankNum > 0 ? rankNum : (category.contains('排行') ? list.length + 1 : 0),
        ));
      }
    }

    // 🌟 核心保真：100% 忠实保留官方源站网页中呈现的原生卡片排序，严禁客户端二次重排导致新剧和热播错位
    return list;
  }

  /// 获取某个专题内收录的所有精选短剧
  static Future<List<ShortDrama>> fetchTopicDramas(String topicId) async {
    final rawBaseUrl = await SettingsService.getDramaBaseUrl();
    if (rawBaseUrl.isEmpty) return [];
    final baseUrl = await resolveWorkingDomain(rawBaseUrl);
    final targetUrl = '$baseUrl/topics/$topicId/';

    try {
      final response = await _dio.get<String>(
        targetUrl,
        options: Options(
          headers: {
            'Referer': '$baseUrl/',
            'Cache-Control': 'no-cache',
          },
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = _parseHtmlDramaList(response.data!, category: '专题精选', domain: baseUrl);
        return list;
      }
    } catch (_) {
      // 穿透边缘代理
      final customDomain = await SettingsService.getCustomDomain();
      final proxyHost = customDomain.isNotEmpty ? customDomain : 'https://zb.djseven.cc.cd';
      final proxyUrl = '$proxyHost/drama?url=${Uri.encodeComponent(targetUrl)}';
      try {
        final resp = await _dio.get<String>(proxyUrl);
        if (resp.statusCode == 200 && resp.data != null) {
          return _parseHtmlDramaList(resp.data!, category: '专题精选', domain: baseUrl);
        }
      } catch (_) {}
    }
    return [];
  }

  /// 获取吃瓜文章的完整图文正文与多张插图
  static Future<GossipArticle?> fetchGossipDetail(String articleId) async {
    final rawBaseUrl = await SettingsService.getDramaBaseUrl();
    if (rawBaseUrl.isEmpty) return null;
    final baseUrl = await resolveWorkingDomain(rawBaseUrl);
    final targetUrl = '$baseUrl/archives/$articleId/';

    try {
      Response<String>? response;
      try {
        response = await _dio.get<String>(
          targetUrl,
          options: Options(
            headers: {
              'Referer': '$baseUrl/',
              'Cache-Control': 'no-cache',
            },
          ),
        );
      } catch (_) {
        final customDomain = await SettingsService.getCustomDomain();
        final proxyHost = customDomain.isNotEmpty ? customDomain : 'https://zb.djseven.cc.cd';
        final proxyUrl = '$proxyHost/drama?url=${Uri.encodeComponent(targetUrl)}';
        response = await _dio.get<String>(proxyUrl);
      }

      if (response != null && response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        final titleEl = document.querySelector('.hg-post-detail__title') ?? document.querySelector('h1');
        final title = titleEl?.text.trim() ?? '吃瓜爆料';

        final authorEl = document.querySelector('.hg-post-detail__author-name');
        final author = authorEl?.text.trim() ?? '黄果AI吃瓜';

        final avatarImg = document.querySelector('.pd-ava img');
        String avatar = avatarImg?.attributes['data-src'] ?? avatarImg?.attributes['src'] ?? '';
        if (avatar.startsWith('//')) avatar = 'https:$avatar';
        else if (avatar.startsWith('/')) avatar = '$baseUrl$avatar';

        final dateEl = document.querySelector('.hg-post-detail__meta span:not(.hg-post-detail__dot)');
        final publishDate = dateEl?.text.trim() ?? '';

        final catEl = document.querySelector('.hg-post-detail__cat');
        final categoryName = catEl?.text.trim() ?? '吃瓜爆料';

        final bodyEl = document.querySelector('.article-body') ?? document.querySelector('.hg-post-detail__body');
        final List<ArticleContentNode> contentNodes = [];
        final List<String> videoUrls = [];
        final List<String> paragraphs = [];
        final List<String> imageUrls = [];
        final List<String> tags = [];
        String relatedDramaId = '';
        String relatedDramaTitle = '';

        // 提取全文字签
        final kwElements = document.querySelectorAll('.hg-post-detail__keywords .pd-kw, .hg-post-detail__tags a, .tags a');
        for (final kw in kwElements) {
          final t = kw.text.replaceAll('#', '').trim();
          if (t.isNotEmpty && !tags.contains(t)) {
            tags.add(t);
          }
        }

        if (bodyEl != null) {
          // 1. 提取文中指向短剧详情的关联跳转链接（如：点击观看：<a href="/detail/4470/">《超能旅行团》</a>）
          final detailLinks = bodyEl.querySelectorAll('a[href*="/detail/"]');
          for (final a in detailLinks) {
            final href = a.attributes['href'] ?? '';
            final match = RegExp(r'/detail/(\d+)').firstMatch(href);
            if (match != null) {
              relatedDramaId = match.group(1)!;
              relatedDramaTitle = a.text.replaceAll('《', '').replaceAll('》', '').trim();
              break;
            }
          }

          // 2. 递归/流式节点提取辅助闭包
          void extractNode(html_dom.Element element) {
            final tag = element.localName?.toLowerCase() ?? '';
            final classes = element.classes;
            final id = element.id;

            // 过滤广告、无关遮罩或脚本
            if (classes.contains('hg-ssp-pause') ||
                classes.contains('hg-ssp-slot') ||
                classes.contains('hg-post-detail__comments') ||
                classes.contains('hg-post-detail__related-posts') ||
                classes.contains('hg-post-detail__actions') ||
                classes.contains('hg-post-detail__meta') ||
                classes.contains('hg-post-detail__keywords') ||
                tag == 'script' ||
                tag == 'style' ||
                tag == 'noscript') {
              return;
            }

            // A. 检查是否为视频播放器容器或直链节点
            final isVideoContainer = classes.contains('post-video-player') ||
                id.contains('postVideoPlayer') ||
                id.contains('VideoPlayer') ||
                classes.any((c) => c.contains('player') || c.contains('video')) ||
                tag == 'video';

            var vUrl = element.attributes['data-src'] ??
                element.attributes['data-url'] ??
                element.attributes['data-video'] ??
                element.attributes['src'] ?? '';
            if (vUrl.isEmpty && tag == 'video') {
              vUrl = element.querySelector('source')?.attributes['src'] ?? '';
            }

            if (isVideoContainer || (vUrl.isNotEmpty && (vUrl.contains('.m3u8') || vUrl.contains('.mp4')))) {
              if (vUrl.startsWith('//')) vUrl = 'https:$vUrl';
              else if (vUrl.startsWith('/')) vUrl = '$baseUrl$vUrl';

              if (vUrl.isNotEmpty && !videoUrls.contains(vUrl)) {
                videoUrls.add(vUrl);
                contentNodes.add(
                  ArticleContentNode(
                    type: ArticleNodeType.video,
                    content: vUrl,
                    title: '爆料现场猛料视频 ${videoUrls.length}',
                  ),
                );
                return;
              }
            }

            // B. 检查是否为插图节点
            if (tag == 'img') {
              var src = element.attributes['data-src'] ??
                  element.attributes['data-original'] ??
                  element.attributes['src'] ?? '';
              if (src.isNotEmpty && !src.contains('placeholder') && !src.contains('loading') && !src.contains('avatar')) {
                if (src.startsWith('//')) src = 'https:$src';
                else if (src.startsWith('/')) src = '$baseUrl$src';

                if (!imageUrls.contains(src)) {
                  imageUrls.add(src);
                  contentNodes.add(
                    ArticleContentNode(
                      type: ArticleNodeType.image,
                      content: src,
                      extra: element.attributes['alt'],
                    ),
                  );
                }
              }
              return;
            }

            // C. 检查是否为小节标题节点 (h1~h6)
            if (['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].contains(tag)) {
              final text = element.text.trim();
              if (text.isNotEmpty && !_isAdText(text)) {
                paragraphs.add(text);
                contentNodes.add(
                  ArticleContentNode(
                    type: ArticleNodeType.heading,
                    content: text,
                    extra: tag,
                  ),
                );
              }
              return;
            }

            // D. 检查是否为段落或文本容器 (p, blockquote, li)
            if (['p', 'blockquote', 'li'].contains(tag)) {
              // 若该段落内部包裹了 img 或 video，逐一抽取子节点
              final innerImgs = element.querySelectorAll('img');
              final innerVideos = element.querySelectorAll('.post-video-player, video');
              if (innerImgs.isNotEmpty || innerVideos.isNotEmpty) {
                for (final child in element.children) {
                  extractNode(child);
                }
                return;
              }

              final text = element.text.trim();
              if (text.isNotEmpty && !_isAdText(text)) {
                paragraphs.add(text);

                final detailLink = element.querySelector('a[href*="/detail/"]');
                if (detailLink != null) {
                  final href = detailLink.attributes['href'] ?? '';
                  final match = RegExp(r'/detail/(\d+)').firstMatch(href);
                  if (match != null) {
                    final dId = match.group(1)!;
                    final dTitle = detailLink.text.replaceAll('《', '').replaceAll('》', '').trim();
                    contentNodes.add(
                      ArticleContentNode(
                        type: ArticleNodeType.dramaLink,
                        content: text,
                        extra: dId,
                        title: dTitle,
                      ),
                    );
                    return;
                  }
                }

                contentNodes.add(
                  ArticleContentNode(
                    type: ArticleNodeType.paragraph,
                    content: text,
                  ),
                );
              }
              return;
            }

            // E. 其他容器节点，递归处理所有子节点
            for (final child in element.children) {
              extractNode(child);
            }
          }

          for (final child in bodyEl.children) {
            extractNode(child);
          }

          // 3. 全局备用兜底正则匹配：若未提取到任何视频，但 HTML 中包含直接 m3u8/mp4 链接
          if (videoUrls.isEmpty) {
            final regExp = RegExp(r'''(https?://[^\s"'<>]+\.(?:m3u8|mp4)[^\s"'<>]*)''');
            final matches = regExp.allMatches(html);
            for (final m in matches) {
              final directUrl = m.group(1);
              if (directUrl != null && directUrl.isNotEmpty && !videoUrls.contains(directUrl)) {
                videoUrls.add(directUrl);
                contentNodes.add(
                  ArticleContentNode(
                    type: ArticleNodeType.video,
                    content: directUrl,
                    title: '爆料独家视频 ${videoUrls.length}',
                  ),
                );
              }
            }
          }
        }

        return GossipArticle(
          id: articleId,
          title: title,
          author: author,
          authorAvatar: avatar,
          publishDate: publishDate,
          categoryName: categoryName,
          paragraphs: paragraphs,
          imageUrls: imageUrls,
          rawContent: bodyEl?.text.trim() ?? '',
          relatedDramaId: relatedDramaId,
          relatedDramaTitle: relatedDramaTitle.isNotEmpty ? relatedDramaTitle : '精选正片',
          contentNodes: contentNodes,
          videoUrls: videoUrls,
          tags: tags,
        );
      }
    } catch (_) {}
    return null;
  }

  static bool _isAdText(String text) {
    if (text.length > 200 && (text.contains('function(') || text.contains('eval(') || text.contains('window.'))) {
      return true;
    }
    final lower = text.toLowerCase();
    return lower.contains('免责声明') ||
        lower.contains('点击进入') ||
        lower.contains('广告位') ||
        lower.contains('扫码下载');
  }

  /// 动态获取短剧完整详情与真实所有剧集
  static Future<ShortDrama> fetchDramaDetail(ShortDrama initialDrama) async {
    final rawBaseUrl = await SettingsService.getDramaBaseUrl();
    if (rawBaseUrl.isEmpty) return initialDrama;

    // 🌟 黄瓜短剧源详情与全集解析分支
    final sourceType = await SettingsService.getDramaSourceType();
    if (sourceType == SettingsService.dramaSourceHgdju ||
        SettingsService.detectDramaSourceType(rawBaseUrl) == SettingsService.dramaSourceHgdju) {
      final detail = await HgdjuDramaService.fetchDramaDetail(
        rawBaseUrl: rawBaseUrl,
        slug: initialDrama.id,
      );
      return detail ?? initialDrama;
    }

    final baseUrl = await resolveWorkingDomain(rawBaseUrl);

    try {
      final detailUrl = '$baseUrl/detail/${initialDrama.id}/';
      final response = await _dio.get<String>(
        detailUrl,
        options: Options(
          headers: {
            'Referer': '$baseUrl/',
            'Cache-Control': 'no-cache',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data!;
        final document = html_parser.parse(html);

        // 1. 标题与简介
        final titleEl = document.querySelector('.hg-web-detail__info h1') ?? document.querySelector('h1');
        final title = titleEl?.text.trim() ?? initialDrama.title;

        final descEl = document.querySelector('.hg-web-detail__desc') ?? document.querySelector('.desc');
        final desc = descEl?.text.trim() ?? initialDrama.description;

        // 2. 封面海报 - 优先从 data-src 获取带签名的 CDN 图片
        String coverUrl = initialDrama.coverUrl;
        final posterEl = document.querySelector('.hg-web-detail__poster img') ??
            document.querySelector('.poster img');
        if (posterEl != null) {
          coverUrl = posterEl.attributes['data-src'] ??
              posterEl.attributes['data-original'] ??
              posterEl.attributes['src'] ??
              coverUrl;
        }
        if (coverUrl.contains('pic.tuafjz.cn')) {
          coverUrl = coverUrl.replaceAll('pic.tuafjz.cn', 'pic.wirqed.cn');
        } else if (coverUrl.contains('pic.eanfog.cn')) {
          coverUrl = coverUrl.replaceAll('pic.eanfog.cn', 'pic.wirqed.cn');
        } else if (coverUrl.startsWith('//')) {
          coverUrl = 'https:$coverUrl';
        } else if (coverUrl.startsWith('/upload')) {
          coverUrl = 'https://pic.wirqed.cn$coverUrl';
        } else if (coverUrl.startsWith('/') && baseUrl.isNotEmpty) {
          coverUrl = '$baseUrl$coverUrl';
        }
        // 排除占位符
        if (coverUrl.contains('cover-placeholder')) {
          coverUrl = initialDrama.coverUrl;
        }

        // 3. 解析全集列表 - 真实播放页 URL 格式: /video/{id}/ 和 /video/{id}/ep-{N}/
        final epGridEls = document.querySelectorAll('[data-ep-grid] a, .hg-web-detail__ep-grid a');
        final List<DramaEpisode> parsedEpisodes = [];

        if (epGridEls.isNotEmpty) {
          for (int i = 0; i < epGridEls.length; i++) {
            final epEl = epGridEls[i];
            final href = epEl.attributes['href'] ?? '';
            final epIdStr = epEl.attributes['data-ep-id'] ?? '';
            final epNum = int.tryParse(epIdStr) ?? (i + 1);

            // embedUrl 存储真实播放页地址（如 /video/12/ep-11/）
            String fullPlayUrl = '';
            if (href.isNotEmpty) {
              fullPlayUrl = href.startsWith('http') ? href : '$baseUrl$href';
            } else {
              // 第1集: /video/{id}/，其余: /video/{id}/ep-{N}/
              fullPlayUrl = epNum == 1
                  ? '$baseUrl/video/${initialDrama.id}/'
                  : '$baseUrl/video/${initialDrama.id}/ep-$epNum/';
            }

            parsedEpisodes.add(DramaEpisode(
              episodeNum: epNum,
              title: '第 $epNum 集',
              videoUrl: '', // 留空，播放时实时获取带签名的 m3u8 URL
              embedUrl: fullPlayUrl,
            ));
          }
        } else {
          // 无明确剧集网格，按总集数构造
          final total = initialDrama.totalEpisodes > 0 ? initialDrama.totalEpisodes : 1;
          for (int i = 1; i <= total; i++) {
            final playUrl = i == 1
                ? '$baseUrl/video/${initialDrama.id}/'
                : '$baseUrl/video/${initialDrama.id}/ep-$i/';
            parsedEpisodes.add(DramaEpisode(
              episodeNum: i,
              title: '第 $i 集',
              videoUrl: '',
              embedUrl: playUrl,
            ));
          }
        }

        return ShortDrama(
          id: initialDrama.id,
          title: title,
          coverUrl: coverUrl,
          description: desc,
          category: initialDrama.category,
          totalEpisodes: parsedEpisodes.isNotEmpty ? parsedEpisodes.length : initialDrama.totalEpisodes,
          rating: initialDrama.rating,
          playCount: initialDrama.playCount,
          tags: initialDrama.tags,
          episodes: parsedEpisodes,
        );
      }
    } catch (_) {}

    return initialDrama;
  }

  /// 动态换取分集真实视频流（针对黄瓜短剧等需要动态拉取鉴权流地址的源）
  static Future<String?> fetchEpisodePlayUrl({
    required String slug,
    required int episodeNum,
  }) async {
    final rawBaseUrl = await SettingsService.getDramaBaseUrl();
    if (rawBaseUrl.isEmpty) return null;
    return await HgdjuDramaService.fetchEpisodePlayUrl(
      rawBaseUrl: rawBaseUrl,
      slug: slug,
      episodeNum: episodeNum,
    );
  }

  /// 解析视频播放页的点赞数、评论数与评论列表
  static DramaInteractionData parseInteractionData(String html) {
    int likeCount = 0;
    String likeCountText = '0';
    bool isLiked = false;
    int commentCount = 0;
    String commentCountText = '0';
    List<DramaComment> comments = [];
    String playCount = '';

    // 1. 优先从 videoInitialData JSON 提取
    final videoDataMatch = RegExp(
      r'<script\s+id="videoInitialData"\s+type="application/json">\s*(\{.+?\})\s*</script>',
      dotAll: true,
    ).firstMatch(html);

    if (videoDataMatch != null) {
      try {
        final jsonStr = videoDataMatch.group(1)!;
        final Map<String, dynamic> data = jsonDecode(jsonStr);

        // 点赞量解析（优先提取真实点赞数及展示文案）
        final rawLikesNum = data['likesNum'] ?? data['videoLikesNum'];
        if (rawLikesNum != null) {
          likeCount = (rawLikesNum as num).toInt();
        }
        final rawLikesText = data['likes'] ?? data['videoLikes'];
        if (rawLikesText != null && rawLikesText.toString().isNotEmpty) {
          likeCountText = rawLikesText.toString();
        } else if (likeCount > 0) {
          likeCountText = likeCount >= 10000
              ? '${(likeCount / 10000).toStringAsFixed(1)}w'
              : (likeCount >= 1000 ? '${(likeCount / 1000).toStringAsFixed(1)}k' : '$likeCount');
        }
        isLiked = data['liked'] == true;

        // 播放量/热度解析 (views, 如 50.8w)
        final rawViews = data['views'] ?? data['hot'] ?? data['playCount'];
        if (rawViews != null && rawViews.toString().isNotEmpty) {
          playCount = rawViews.toString().replaceAll('w', '万');
        }

        // 评论总数解析
        final rawCommentCount = data['commentsCount'];
        if (rawCommentCount != null) {
          commentCount = int.tryParse(rawCommentCount.toString()) ?? 0;
          commentCountText = '$commentCount';
        }

        // 评论列表解析
        final rawComments = data['comments'];
        if (rawComments is List) {
          for (final c in rawComments) {
            if (c is Map<String, dynamic>) {
              comments.add(DramaComment.fromInitialData(c));
            }
          }
        }
      } catch (_) {}
    }

    // 2. DOM 兜底解析（当 JSON 未完全命中或字段缺失时）
    if (likeCountText == '0' || likeCount == 0) {
      // 提取 <span class="num" data-field="likes" data-raw="2280">2.3k</span>
      final likeSpanMatch = RegExp(
        r'<[^>]*data-field=["'']likes["''][^>]*data-raw=["''](\d+)["''][^>]*>([^<]*)<',
        caseSensitive: false,
      ).firstMatch(html);
      if (likeSpanMatch != null) {
        likeCount = int.tryParse(likeSpanMatch.group(1)!) ?? likeCount;
        final txt = likeSpanMatch.group(2)?.trim() ?? '';
        if (txt.isNotEmpty) likeCountText = txt;
      } else {
        final fieldMatch = RegExp(r'data-field=["'']likes["''][^>]*>([^<]+)<').firstMatch(html);
        if (fieldMatch != null) {
          likeCountText = fieldMatch.group(1)!.trim();
        }
      }
    }

    if (commentCount == 0) {
      // 提取 <span data-field="commentsCount">43 条评论</span>
      final commentMatch = RegExp(
        r'data-field=["'']commentsCount["''][^>]*>(\d+)\s*条评论',
        caseSensitive: false,
      ).firstMatch(html);
      if (commentMatch != null) {
        commentCount = int.tryParse(commentMatch.group(1)!) ?? 0;
        commentCountText = '$commentCount';
      } else {
        final schemaMatch = RegExp(
          r'"interactionType"\s*:\s*"https://schema\.org/CommentAction"\s*,\s*"userInteractionCount"\s*:\s*(\d+)',
        ).firstMatch(html);
        if (schemaMatch != null) {
          commentCount = int.tryParse(schemaMatch.group(1)!) ?? 0;
          commentCountText = '$commentCount';
        }
      }
    }

    if (comments.isEmpty) {
      // 从 DOM <div class="hg-web-play__comment-list" id="comment-list"> 提取
      try {
        final document = html_parser.parse(html);
        final commentElements = document.querySelectorAll('article.hg-web-play__comment');
        for (final el in commentElements) {
          final cid = el.attributes['data-comment-id'] ?? '';
          final avatarEl = el.querySelector('.hg-web-play__comment-avatar');
          final avatarText = avatarEl?.text.trim() ?? '';
          String color = '#5C7FD1';
          final style = avatarEl?.attributes['style'] ?? '';
          final bgMatch = RegExp(r'background:\s*(#[a-fA-F0-9]{3,6})').firstMatch(style);
          if (bgMatch != null) {
            color = bgMatch.group(1)!;
          }
          final metaEl = el.querySelector('.hg-web-play__comment-meta');
          final author = metaEl?.querySelector('strong')?.text.trim() ?? '网友';
          final time = metaEl?.querySelector('span')?.text.trim() ?? '';
          final content = el.querySelector('.hg-web-play__comment-body > p')?.text.trim() ?? '';
          final likeBtn = el.querySelector('button.hg-web-play__comment-like');
          final cLikes = int.tryParse(likeBtn?.querySelector('span')?.text.trim() ?? '0') ?? 0;

          if (content.isNotEmpty) {
            comments.add(DramaComment(
              id: cid,
              author: author,
              avatar: avatarText,
              avatarColor: color,
              time: time,
              content: content,
              likes: cLikes,
            ));
          }
        }
      } catch (_) {}
    }

    if (playCount.isEmpty) {
      final watchMatch = RegExp(
        r'"interactionType"\s*:\s*"https://schema\.org/WatchAction"\s*,\s*"userInteractionCount"\s*:\s*(\d+)',
      ).firstMatch(html);
      if (watchMatch != null) {
        final count = int.tryParse(watchMatch.group(1)!) ?? 0;
        if (count >= 10000000) {
          playCount = '${(count / 10000000).toStringAsFixed(1)}千万';
        } else if (count >= 10000) {
          playCount = '${(count / 10000).toStringAsFixed(1)}万';
        } else if (count > 0) {
          playCount = '$count';
        }
      }
    }

    return DramaInteractionData(
      likeCount: likeCount,
      likeCountText: likeCountText,
      isLiked: isLiked,
      commentCount: commentCount > 0 ? commentCount : comments.length,
      commentCountText: commentCountText != '0' ? commentCountText : '${comments.length}',
      comments: comments,
      playCount: playCount,
    );
  }

  /// 智能直链提取与互动数据获取：请求播放页提取 m3u8 URL、点赞数、评论列表
  static Future<DramaEpisodePlayData> resolveEpisodePlayData(
    String dramaId,
    int episodeNum, {
    String customPlayUrl = '',
  }) async {
    final rawBaseUrl = await SettingsService.getDramaBaseUrl();
    if (rawBaseUrl.isEmpty) {
      return DramaEpisodePlayData(
        streamUrl: '',
        interaction: DramaInteractionData(),
      );
    }

    // 🌟 黄瓜短剧源动态分集流解析与直通
    final sourceType = await SettingsService.getDramaSourceType();
    if (sourceType == SettingsService.dramaSourceHgdju ||
        SettingsService.detectDramaSourceType(rawBaseUrl) == SettingsService.dramaSourceHgdju) {
      // 若已有直链且是有效流（如第1、2集SSR已出流）
      if (customPlayUrl.contains('.m3u8') || customPlayUrl.contains('.mp4')) {
        return DramaEpisodePlayData(
          streamUrl: customPlayUrl,
          interaction: DramaInteractionData(likeCountText: '999+', commentCountText: '60'),
        );
      }
      // 否则调用 /api/ep-src 动态换流
      final dynamicStream = await HgdjuDramaService.fetchEpisodePlayUrl(
        rawBaseUrl: rawBaseUrl,
        slug: dramaId,
        episodeNum: episodeNum,
      );
      if (dynamicStream != null && dynamicStream.isNotEmpty) {
        return DramaEpisodePlayData(
          streamUrl: dynamicStream,
          interaction: DramaInteractionData(likeCountText: '999+', commentCountText: '60'),
        );
      }
    }

    final baseUrl = await resolveWorkingDomain(rawBaseUrl);

    // 提取纯数字短剧 ID（如 10769）
    final idMatch = RegExp(r'(\d+)').firstMatch(dramaId);
    final cleanDramaId = idMatch != null ? idMatch.group(1)! : dramaId.trim();

    DramaInteractionData interactionData = DramaInteractionData();
    String foundStreamUrl = '';

    // ★★★ 策略0（新版官方标准 Playback API 优先直接出流）
    // 黄果短剧最新改版后全量迁移至异步 POST 接口，返回带签名的 m3u8 流地址
    if (cleanDramaId.isNotEmpty) {
      final List<String> playbackPaths = [];
      playbackPaths.add('/api/videos/$cleanDramaId/episodes/$episodeNum/playback');
      if (episodeNum == 1) {
        playbackPaths.add('/api/videos/$cleanDramaId/playback');
      }

      final List<String> tryDomains = [
        baseUrl,
        ...officialDomains,
      ].toSet().where((d) => d.isNotEmpty && !d.contains('huangguoai.ai')).toList();
      if (tryDomains.isEmpty) tryDomains.add(baseUrl);

      for (final domain in tryDomains) {
        for (final path in playbackPaths) {
          try {
            final apiUrl = '$domain$path';
            final resp = await _dio.post(
              apiUrl,
              data: {},
              options: Options(
                headers: {
                  'Content-Type': 'application/json',
                  'Referer': '$domain/video/$cleanDramaId/',
                  'Origin': domain,
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                },
                receiveTimeout: const Duration(milliseconds: 3500),
                sendTimeout: const Duration(milliseconds: 3500),
              ),
            );

            if (resp.statusCode == 200 && resp.data != null) {
              dynamic resObj = resp.data;
              if (resObj is String) {
                try {
                  resObj = jsonDecode(resObj);
                } catch (_) {}
              }
              if (resObj is Map) {
                final dataMap = resObj['data'];
                if (dataMap is Map) {
                  final streams = dataMap['streams'];
                  if (streams is Map) {
                    var stUrl = streams['main']?.toString() ??
                        streams['preview']?.toString() ??
                        streams['hevc']?.toString() ??
                        '';
                    stUrl = stUrl
                        .replaceAll(r'\u0026', '&')
                        .replaceAll('&amp;', '&')
                        .replaceAll(r'\/', '/')
                        .trim();
                    if (stUrl.startsWith('//')) stUrl = 'https:$stUrl';
                    if (stUrl.contains('.m3u8') || stUrl.contains('.mp4') || stUrl.startsWith('http')) {
                      foundStreamUrl = stUrl;
                      break;
                    }
                  }
                }
              }
            }
          } catch (_) {}
          if (foundStreamUrl.isNotEmpty) break;
        }
        if (foundStreamUrl.isNotEmpty) break;
      }
    }

    // 轻量获取本集互动数据（点赞数、评论列表）
    try {
      final interactUrl = episodeNum == 1
          ? '$baseUrl/video/$cleanDramaId/'
          : '$baseUrl/video/$cleanDramaId/ep-$episodeNum/';
      final interactResp = await _dio.get<String>(
        interactUrl,
        options: Options(
          headers: {
            'Referer': '$baseUrl/detail/$cleanDramaId/',
            'Cache-Control': 'no-cache',
          },
          receiveTimeout: const Duration(milliseconds: 3000),
        ),
      );
      if (interactResp.statusCode == 200 && interactResp.data != null) {
        final parsed = parseInteractionData(interactResp.data!);
        if (parsed.likeCount > 0 || parsed.comments.isNotEmpty) {
          interactionData = parsed;
        }
      }
    } catch (_) {}

    // 若策略0已成功拿到有效视频流，直接组装返回，实现零延迟极速秒播！
    if (foundStreamUrl.isNotEmpty) {
      return DramaEpisodePlayData(
        streamUrl: foundStreamUrl,
        interaction: interactionData,
      );
    }

    // 构造候选播放页 URL（降级兜底方案）
    final List<String> candidateUrls = [];
    if (customPlayUrl.isNotEmpty) {
      candidateUrls.add(customPlayUrl);
    }
    // 真实 URL 格式: 第1集 /video/{id}/ , 其余 /video/{id}/ep-{N}/
    if (episodeNum == 1) {
      candidateUrls.add('$baseUrl/video/$dramaId/');
    }
    candidateUrls.add('$baseUrl/video/$dramaId/ep-$episodeNum/');
    // 备用格式
    candidateUrls.add('$baseUrl/video/$dramaId/?ep=$episodeNum');

    for (final targetUrl in candidateUrls) {
      try {
        final response = await _dio.get<String>(
          targetUrl,
          options: Options(
            headers: {
              'Referer': '$baseUrl/detail/$dramaId/',
              'Cache-Control': 'no-cache',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final html = response.data!;
          final parsedInteraction = parseInteractionData(html);
          if (parsedInteraction.likeCount > 0 || parsedInteraction.comments.isNotEmpty) {
            interactionData = parsedInteraction;
          }

          // ★ 核心策略1: 从 <script id="videoInitialData"> JSON 中提取 videoSrc
          final videoDataMatch = RegExp(
            r'<script\s+id="videoInitialData"\s+type="application/json">\s*(\{.+?\})\s*</script>',
            dotAll: true,
          ).firstMatch(html);

          if (videoDataMatch != null) {
            try {
              final jsonStr = videoDataMatch.group(1)!;

              // 从 epPlaySrcs 中提取指定集直链
              final epSrcsMatch = RegExp(r'"epPlaySrcs"\s*:\s*\{([^}]+)\}').firstMatch(jsonStr);
              if (epSrcsMatch != null) {
                final epBlock = epSrcsMatch.group(1)!;
                final epUrlMatch = RegExp('"$episodeNum"\\s*:\\s*"([^"]+)"').firstMatch(epBlock);
                if (epUrlMatch != null) {
                  var streamUrl = epUrlMatch.group(1)!
                      .replaceAll(r'\u0026', '&')
                      .replaceAll('&amp;', '&')
                      .replaceAll(r'\/', '/')
                      .trim();
                  if (streamUrl.startsWith('//')) streamUrl = 'https:$streamUrl';
                  if (streamUrl.contains('.m3u8') || streamUrl.contains('.mp4')) {
                    foundStreamUrl = streamUrl;
                    break;
                  }
                }
              }

              // 提取 videoSrc
              final videoSrcMatch = RegExp(r'"videoSrc"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
              if (videoSrcMatch != null) {
                var streamUrl = videoSrcMatch.group(1)!
                    .replaceAll(r'\u0026', '&')
                    .replaceAll('&amp;', '&')
                    .replaceAll(r'\/', '/')
                    .trim();
                if (streamUrl.startsWith('//')) streamUrl = 'https:$streamUrl';
                if (streamUrl.contains('.m3u8') || streamUrl.contains('.mp4')) {
                  foundStreamUrl = streamUrl;
                  break;
                }
              }

              // 提取 previewSrc 作为备用
              final previewSrcMatch = RegExp(r'"previewSrc"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
              if (previewSrcMatch != null) {
                var streamUrl = previewSrcMatch.group(1)!
                    .replaceAll(r'\u0026', '&')
                    .replaceAll('&amp;', '&')
                    .replaceAll(r'\/', '/')
                    .trim();
                if (streamUrl.startsWith('//')) streamUrl = 'https:$streamUrl';
                if (streamUrl.contains('.m3u8') || streamUrl.contains('.mp4')) {
                  foundStreamUrl = streamUrl;
                  break;
                }
              }
            } catch (_) {}
          }

          // ★ 策略2: player_aaaa / player_data 兜底
          final playerMatch = RegExp(r'''(?:player_aaaa|player_data|video_data|play_data)\s*=\s*(\{.+?\});''', dotAll: true).firstMatch(html);
          if (playerMatch != null) {
            try {
              final jsonStr = playerMatch.group(1)!;
              final urlMatch = RegExp(r'''"url"\s*:\s*"([^"]+)"''').firstMatch(jsonStr);
              if (urlMatch != null) {
                final rawPlaylist = urlMatch.group(1)!;
                final epParts = rawPlaylist.split('#');
                if (episodeNum <= epParts.length && episodeNum > 0) {
                  final targetPart = epParts[episodeNum - 1];
                  final streamUrl = targetPart.contains('\$') ? targetPart.split('\$').last : targetPart;
                  if (streamUrl.contains('.m3u8') || streamUrl.startsWith('http')) {
                    var clean = streamUrl.replaceAll('&amp;', '&').replaceAll(r'\u0026', '&').trim();
                    if (clean.startsWith('//')) clean = 'https:$clean';
                    foundStreamUrl = clean;
                    break;
                  }
                }
              }
            } catch (_) {}
          }

          // ★ 策略3: 正则搜索所有 m3u8 URL
          final allM3u8 = RegExp(r'''(https?://[^"'\s<>]+\.m3u8[^"'\s<>]*)''', caseSensitive: false)
              .allMatches(html);
          if (allM3u8.isNotEmpty) {
            final list = allM3u8
                .map((m) => m.group(1)!.replaceAll(r'\/', '/').replaceAll('&amp;', '&').replaceAll(r'\u0026', '&').trim())
                .toSet()
                .toList();
            if (list.isNotEmpty) {
              foundStreamUrl = list.first;
              break;
            }
          }
        }
      } catch (_) {}
    }

    // ★ 策略4: 官方镜像主站高可用容灾保底（若当前节点被墙或流地址解析为空）
    if (foundStreamUrl.isEmpty) {
      for (final backupDomain in officialDomains) {
        if (backupDomain == baseUrl) continue;
        final backupUrl = episodeNum == 1
            ? '$backupDomain/video/$dramaId/'
            : '$backupDomain/video/$dramaId/ep-$episodeNum/';
        try {
          final resp = await _dio.get<String>(
            backupUrl,
            options: Options(
              headers: {
                'Referer': '$backupDomain/detail/$dramaId/',
                'Cache-Control': 'no-cache',
              },
              receiveTimeout: const Duration(seconds: 4),
            ),
          );
          if (resp.statusCode == 200 && resp.data != null) {
            final html = resp.data!;
            final match = RegExp(
              r'<script\s+id="videoInitialData"\s+type="application/json">\s*(\{.+?\})\s*</script>',
              dotAll: true,
            ).firstMatch(html);
            if (match != null) {
              final jsonStr = match.group(1)!;
              final epSrcsMatch = RegExp(r'"epPlaySrcs"\s*:\s*\{([^}]+)\}').firstMatch(jsonStr);
              if (epSrcsMatch != null) {
                final epUrlMatch = RegExp('"$episodeNum"\\s*:\\s*"([^"]+)"').firstMatch(epSrcsMatch.group(1)!);
                if (epUrlMatch != null) {
                  var stream = epUrlMatch.group(1)!
                      .replaceAll(r'\u0026', '&')
                      .replaceAll('&amp;', '&')
                      .replaceAll(r'\/', '/')
                      .trim();
                  if (stream.startsWith('//')) stream = 'https:$stream';
                  if (stream.isNotEmpty) {
                    foundStreamUrl = stream;
                    break;
                  }
                }
              }
              final videoSrcMatch = RegExp(r'"videoSrc"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
              if (videoSrcMatch != null) {
                var stream = videoSrcMatch.group(1)!
                    .replaceAll(r'\u0026', '&')
                    .replaceAll('&amp;', '&')
                    .replaceAll(r'\/', '/')
                    .trim();
                if (stream.startsWith('//')) stream = 'https:$stream';
                if (stream.isNotEmpty) {
                  foundStreamUrl = stream;
                  break;
                }
              }
            }
            if (foundStreamUrl.isEmpty) {
              final directM3u8 = RegExp(r'''(https?://[^"'\s<>]+\.m3u8[^"'\s<>]*)''', caseSensitive: false).firstMatch(html);
              if (directM3u8 != null) {
                foundStreamUrl = directM3u8.group(1)!.replaceAll(r'\/', '/').replaceAll('&amp;', '&').replaceAll(r'\u0026', '&').trim();
                break;
              }
            }
          }
        } catch (_) {}
      }
    }

    return DramaEpisodePlayData(
      streamUrl: foundStreamUrl,
      interaction: interactionData,
    );
  }

  /// 智能直链提取：向后兼容方法
  static Future<String> resolveEpisodeStream(
    String dramaId,
    int episodeNum, {
    String customPlayUrl = '',
  }) async {
    final playData = await resolveEpisodePlayData(
      dramaId,
      episodeNum,
      customPlayUrl: customPlayUrl,
    );
    return playData.streamUrl;
  }

  /// 分页拉取该集评论列表（支持上拉加载更多）
  static Future<List<DramaComment>> fetchComments(
    String dramaId, {
    int page = 1,
    int size = 20,
    int ep = 1,
  }) async {
    try {
      final rawBaseUrl = await SettingsService.getDramaBaseUrl();
      if (rawBaseUrl.isEmpty) return [];
      final baseUrl = await resolveWorkingDomain(rawBaseUrl);

      final resp = await _dio.get(
        '$baseUrl/api/videos/$dramaId/comments',
        queryParameters: {'page': page, 'size': size, 'ep': ep},
        options: Options(
          headers: {
            'Referer': '$baseUrl/video/$dramaId/',
            'Accept': 'application/json',
          },
        ),
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final Map<String, dynamic> data = resp.data is Map<String, dynamic>
            ? resp.data as Map<String, dynamic>
            : (resp.data is String ? jsonDecode(resp.data as String) : {});
        final items = (data['data']?['items'] as List?) ?? [];
        return items.map((e) => DramaComment.fromApiJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 访客点赞/取消点赞该视频（无需登录）
  static Future<Map<String, dynamic>?> toggleVideoLike(String dramaId, {int ep = 1}) async {
    try {
      final rawBaseUrl = await SettingsService.getDramaBaseUrl();
      if (rawBaseUrl.isEmpty) return null;
      final baseUrl = await resolveWorkingDomain(rawBaseUrl);

      final resp = await _dio.post(
        '$baseUrl/api/videos/$dramaId/guest-like',
        queryParameters: {'ep': ep},
        options: Options(
          headers: {
            'Referer': '$baseUrl/video/$dramaId/',
            'Accept': 'application/json',
          },
        ),
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final Map<String, dynamic> data = resp.data is Map<String, dynamic>
            ? resp.data as Map<String, dynamic>
            : (resp.data is String ? jsonDecode(resp.data as String) : {});
        if (data['status'] == 1 && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 访客点赞/取消点赞某条评论（无需登录）
  static Future<Map<String, dynamic>?> toggleCommentLike(String dramaId, String commentId) async {
    try {
      final rawBaseUrl = await SettingsService.getDramaBaseUrl();
      if (rawBaseUrl.isEmpty) return null;
      final baseUrl = await resolveWorkingDomain(rawBaseUrl);

      final resp = await _dio.post(
        '$baseUrl/api/videos/$dramaId/comments/$commentId/guest-like',
        options: Options(
          headers: {
            'Referer': '$baseUrl/video/$dramaId/',
            'Accept': 'application/json',
          },
        ),
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final Map<String, dynamic> data = resp.data is Map<String, dynamic>
            ? resp.data as Map<String, dynamic>
            : (resp.data is String ? jsonDecode(resp.data as String) : {});
        if (data['status'] == 1 && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }
}
