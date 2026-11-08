import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/live_stream.dart';
import '../models/file_item.dart';
import 'cloudflare_opt_service.dart';
import 'proxy_route_service.dart';
import 'settings_service.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = CloudflareOptService.createOptDio();
    CloudflareOptService.benchmarkFastestIp();
  }

  // 内存极速全局共享缓存
  static final Map<String, String> _globalM3uMap = {};
  static List<LiveStreamItem> _cachedPandaStreams = [];
  static List<LiveStreamItem> _cachedFlexStreams = [];

  static void _parseM3u(String content) {
    final lines = content.split('\n');
    String? currentId;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#EXTINF:')) {
        final parts = trimmed.split(',');
        if (parts.length >= 2) currentId = parts[1].trim();
      } else if (trimmed.startsWith('http') && currentId != null) {
        _globalM3uMap[currentId] = trimmed;
        if (ProxyRouteService.defaultTestStreamUrl == null) {
          ProxyRouteService.defaultTestStreamUrl = trimmed;
        }
        currentId = null;
      }
    }
  }

  static String? getM3uStreamUrl(String userId) => _globalM3uMap[userId];

  /// 获取任意一个正在开播的有效直播推流直链 (供全线路真实直播测速使用)
  static String? getAnyActiveLiveStream() {
    if (_globalM3uMap.isNotEmpty) {
      for (final v in _globalM3uMap.values) {
        if (v.startsWith('http') && v.contains('.m3u8')) return v;
      }
    }
    for (final s in _cachedPandaStreams) {
      if (s.streamUrl.isNotEmpty && s.streamUrl.startsWith('http')) return s.streamUrl;
    }
    for (final s in _cachedFlexStreams) {
      if (s.streamUrl.isNotEmpty && s.streamUrl.startsWith('http')) return s.streamUrl;
    }
    return null;
  }

  /// 静态预加载 M3U 直播映射
  static Future<void> ensureGlobalM3uLoaded() async {
    if (_globalM3uMap.isNotEmpty) return;
    try {
      final dio = CloudflareOptService.createOptDio();
      final res = await dio.get('https://5721004.xyz/player/list.m3u');
      if (res.statusCode == 200) {
        _parseM3u(res.data.toString());
      }
    } catch (_) {}
  }

  Future<void> _ensureM3uLoaded() async {
    await ensureGlobalM3uLoaded();
  }

  String _baseUrl = 'https://zb.djseven.cc.cd';

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
  }

  /// 获取 PandaTV 实时直播列表（Cloudflare 优选 IP 极速加速 + 多节点并发竞速）
  Future<List<LiveStreamItem>> fetchPandaLiveStreams() async {
    final completer = Completer<List<LiveStreamItem>>();
    int failCount = 0;

    // 预加载 M3U 直播推流直链映射
    _ensureM3uLoaded();

    // 🌟 动态获取用户配置的所有自定义专属节点，实现完全无写死的多节点并发拉取
    final customDomains = await SettingsService.getCustomDomains();
    final cleanCustomNodes = customDomains.map((d) {
      var s = d.trim();
      if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
      s = s.replaceAll(RegExp(r'/hls(?:\?url=)?/?$'), '');
      s = s.replaceAll(RegExp(r'/hls/live\.m3u8(?:\?url=)?/?$'), '');
      s = s.replaceAll(RegExp(r'/proxy/?\??$'), '');
      s = s.replaceAll(RegExp(r'/+$'), '');
      return s;
    }).where((s) => s.isNotEmpty).toSet().toList();

    final endpoints = <String>[
      'https://5721004.xyz/player',
      ...cleanCustomNodes,
    ];

    for (final node in endpoints) {
      () async {
        try {
          final isCustomDomain = node.contains('djseven.cc.cd') || node.contains('workers.dev');
          final targetUrl = isCustomDomain ? '$node/pandatv' : '$node/list.json';

          // 1. 获取推流直链映射
          if (!isCustomDomain) {
            try {
              final m3uRes = await _dio.get('$node/list.m3u');
              if (m3uRes.statusCode == 200) {
                _parseM3u(m3uRes.data.toString());
              }
            } catch (_) {}
          }

          // 2. 获取直播列表
          final response = await _dio.get(targetUrl);
          if (response.statusCode == 200) {
            dynamic data = response.data;
            if (data is String) {
              data = jsonDecode(data);
            }

            List<dynamic> rawList = [];
            if (data is Map && data['list'] is List) {
              rawList = data['list'];
            } else if (data is List) {
              rawList = data;
            }

            final List<LiveStreamItem> items = [];
            for (var item in rawList) {
              if (item is Map<String, dynamic>) {
                final userId = item['userId']?.toString() ?? '';
                final directStream = _globalM3uMap[userId] ?? item['streamUrl']?.toString() ?? '';
                items.add(LiveStreamItem.fromPandaJson(item, streamUrl: directStream));
                if (directStream.isNotEmpty && directStream.startsWith('http') && ProxyRouteService.defaultTestStreamUrl == null) {
                  ProxyRouteService.defaultTestStreamUrl = directStream;
                }
              }
            }

            if (items.isNotEmpty && !completer.isCompleted) {
              _cachedPandaStreams = items;
              completer.complete(items);
              return;
            }
          }
        } catch (_) {}

        failCount++;
        if (failCount >= endpoints.length && !completer.isCompleted) {
          if (_cachedPandaStreams.isNotEmpty) {
            completer.complete(_cachedPandaStreams);
          } else {
            completer.completeError('网络连接超时，请重试');
          }
        }
      }();
    }

    return completer.future;
  }

  /// 获取 FlexTV 实时直播列表（官方 live-list API + Cloudflare 聚合加速 + 多节点并发竞速）
  Future<List<LiveStreamItem>> fetchFlexLiveStreams() async {
    final completer = Completer<List<LiveStreamItem>>();
    int failCount = 0;

    // 🌟 动态获取用户配置的所有自定义专属节点，加入 FlexTV 列表并发竞速端点池
    final customDomains = await SettingsService.getCustomDomains();
    final customFlexEndpoints = customDomains.map((d) {
      var s = d.trim();
      if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
      s = s.replaceAll(RegExp(r'/hls(?:\?url=)?/?$'), '');
      s = s.replaceAll(RegExp(r'/hls/live\.m3u8(?:\?url=)?/?$'), '');
      s = s.replaceAll(RegExp(r'/proxy/?\??$'), '');
      s = s.replaceAll(RegExp(r'/+$'), '');
      return '$s/flextv';
    }).where((s) => s.isNotEmpty).toSet().toList();

    final endpoints = [
      'https://www.flextv.co.kr/api/channels/live-list-main',
      'https://www.flextv.co.kr/api/channels/live-list-top',
      ...customFlexEndpoints,
      'https://5721004.xyz/player/flex.json',
    ];

    final Set<String> seenIds = {};
    final List<LiveStreamItem> aggregatedItems = [];

    for (final targetUrl in endpoints) {
      () async {
        try {
          final response = await _dio.get(
            targetUrl,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Referer': 'https://www.flextv.co.kr/',
                'Origin': 'https://www.flextv.co.kr',
              },
            ),
          );
          if (response.statusCode == 200) {
            dynamic data = response.data;
            if (data is String) {
              data = jsonDecode(data);
            }

            List<dynamic> rawList = [];
            if (data is Map && data['data'] is List) {
              rawList = data['data'];
            } else if (data is List) {
              rawList = data;
            }

            for (var item in rawList) {
              if (item is Map<String, dynamic>) {
                final liveItem = LiveStreamItem.fromFlexJson(item);
                if (liveItem.userId.isNotEmpty && !seenIds.contains(liveItem.userId)) {
                  seenIds.add(liveItem.userId);
                  aggregatedItems.add(liveItem);
                }
              }
            }

            if (aggregatedItems.isNotEmpty && !completer.isCompleted) {
              _cachedFlexStreams = List.from(aggregatedItems);
              completer.complete(_cachedFlexStreams);
              return;
            }
          }
        } catch (_) {}

        failCount++;
        if (failCount >= endpoints.length && !completer.isCompleted) {
          if (_cachedFlexStreams.isNotEmpty) {
            completer.complete(_cachedFlexStreams);
          } else {
            completer.completeError('FlexTV 列表加载失败');
          }
        }
      }();
    }

    return completer.future;
  }

  /// 智能直链提取与 HLS 自愈解析（智能根据当前网络选择最快线路或用户指定线路）
  Future<String> resolveRealMediaUrl(String targetUrl, {int proxyIndex = 0}) async {
    String resolved = targetUrl.trim();
    if (resolved.isEmpty) return resolved;

    // 1. 如果传入的是网页链接（如 pandalive.html?url=pandaclass），先提取主播 ID 或目标链接
    if (resolved.contains('pandalive.html?url=') ||
        resolved.contains('player/?url=') ||
        resolved.contains('pandatv.html?url=')) {
      final uri = Uri.parse(resolved);
      final rawTarget = uri.queryParameters['url'];
      if (rawTarget != null && rawTarget.isNotEmpty) {
        resolved = rawTarget;
      }
    }

    // 2. 如果是 FlexTV 链接或直链：保持完整 Master Playlist，不要截断音视频流
    if (resolved.contains('edge.naverncp.com') || resolved.contains('flextv')) {
      return resolved;
    }

    // 3. 如果是标准完整网络视频 (MP4 / 短剧 m3u8 等)，直接播放
    if (resolved.startsWith('http') &&
        (resolved.endsWith('.mp4') ||
            resolved.contains('.mp4?') ||
            (!resolved.contains('live-video.net') &&
                !resolved.contains('pandalive') &&
                !resolved.contains('flextv') &&
                !resolved.contains('naverncp.com')))) {
      return resolved;
    }

    // 4. PandaTV 专用智能代理（自愈 403 origin required / ExoPlaybackException）
    if (resolved.contains('live-video.net') || resolved.contains('pandalive') || !resolved.startsWith('http')) {
      if (!resolved.startsWith('http')) {
        // 优先从全局 M3U 实时推流映射表中查询
        if (_globalM3uMap.containsKey(resolved)) {
          resolved = _globalM3uMap[resolved]!;
        } else {
          for (var item in _cachedPandaStreams) {
            if (item.userId == resolved || item.userNick == resolved) {
              if (item.streamUrl.isNotEmpty && item.streamUrl.startsWith('http')) {
                resolved = item.streamUrl;
                break;
              }
            }
          }
        }

        // 如果依然未命中，在线补充同步一次 list.m3u
        if (!resolved.startsWith('http')) {
          await _ensureM3uLoaded();
          if (_globalM3uMap.containsKey(resolved)) {
            resolved = _globalM3uMap[resolved]!;
          }
        }
      }

      // 剥除可能已经带有的旧代理前缀，避免重复拼接
      resolved = resolved.replaceAll(RegExp(r'^https://[a-zA-Z0-9_.-]+\.515355\.xyz/proxy/\??'), '');
      for (final r in ProxyRouteService.allRoutes) {
        if (r.prefix.isNotEmpty && resolved.startsWith(r.prefix)) {
          resolved = resolved.substring(r.prefix.length);
          if (resolved.startsWith('?')) resolved = resolved.substring(1);
          break;
        }
      }

      // 🚨 核心安全守卫：如果不是以 http 开头的有效视频直链（比如主播已关播），绝不拼接代理前缀
      if (!resolved.startsWith('http')) {
        return resolved;
      }

      // 🚨 严禁在起播前拿单次推流直链进行测速，防止 AWS IVS Single-Use Token 被测速耗尽报 duplicate token 403
      // 线路测速已在 App 启动和网络变化时自动就绪，此处直接使用当前选定线路秒开
      final route = ProxyRouteService.getActiveRoute(fallbackOffset: proxyIndex);
      if (route.isDirect || route.prefix.isEmpty) {
        return resolved;
      }
      return '${route.prefix}$resolved';
    }

    return resolved;
  }

  /// 获取目录资源列表 (兼容接口)
  Future<List<FileItem>> fetchDirectory(String path) async {
    try {
      final res = await _dio.get(path);
      if (res.statusCode == 200) {
        return <FileItem>[];
      }
    } catch (_) {}
    return <FileItem>[];
  }

  /// 获取纯文本内容 (兼容接口)
  Future<String> fetchRawText(String url) async {
    try {
      final res = await _dio.get(url);
      return res.data?.toString() ?? '';
    } catch (e) {
      return '加载失败: $e';
    }
  }
}
