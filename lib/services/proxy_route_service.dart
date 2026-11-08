import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'settings_service.dart';

enum LocalNetworkMode {
  directMainland, // 国内直连网络 (未开启科学上网)
  vpnConnected,   // 科学上网/海外代理已连接
  unknown,
}

class ProxyRoute {
  final String id;
  final String name;
  final String region;
  final String prefix;
  final bool isDirect;
  int latencyMs;
  double downloadSpeedKBps; // 实测真实下载速度 (KB/s)
  bool isAvailable;
  String? unavailableReason;

  ProxyRoute({
    required this.id,
    required this.name,
    required this.region,
    required this.prefix,
    this.isDirect = false,
    this.latencyMs = 9999,
    this.downloadSpeedKBps = 0.0,
    this.isAvailable = true,
    this.unavailableReason,
  });

  String get speedText {
    if (!isAvailable) return unavailableReason ?? '不可用';
    if (downloadSpeedKBps <= 0) return '测速中...';
    if (downloadSpeedKBps >= 1024) {
      return '${(downloadSpeedKBps / 1024).toStringAsFixed(2)} MB/s';
    } else {
      return '${downloadSpeedKBps.toStringAsFixed(0)} KB/s';
    }
  }

  String get latencyText {
    if (!isAvailable || latencyMs >= 9000) return '不可用';
    return '$latencyMs ms';
  }
}

class ProxyRouteService {
  /// 默认内置的公共代理与官方直连线路
  static final List<ProxyRoute> defaultPublicRoutes = [
    ProxyRoute(
      id: 'f00',
      name: 'Cloudflare CDN 全球加速 (极速推荐)',
      region: '全球 Anycast (国内直连首选 · 实测高达 6MB/s)',
      prefix: 'https://f00.515355.xyz/proxy/',
    ),
    ProxyRoute(
      id: 'pol',
      name: '欧洲波兰机房 (主线路)',
      region: '欧洲/波兰 (电信/移动/联通通用)',
      prefix: 'https://pol.515355.xyz/proxy/',
    ),
    ProxyRoute(
      id: 'uae2',
      name: '中东迪拜机房 (备用线路)',
      region: '阿联酋/迪拜 (亚洲/中东高速)',
      prefix: 'https://uae2.515355.xyz/proxy/',
    ),
    ProxyRoute(
      id: 'hubu',
      name: '德国 Contabo 机房',
      region: '欧洲/德国 (高防稳定)',
      prefix: 'https://hubu.515355.xyz/proxy/?',
    ),
    ProxyRoute(
      id: 'ce2',
      name: '美洲高速机房',
      region: '北美洲 (大带宽线路)',
      prefix: 'https://ce2.515355.xyz/proxy/?',
    ),
    ProxyRoute(
      id: 'direct',
      name: '官方原画直连 (需科学上网)',
      region: '韩国原站 (直连无转播)',
      prefix: '',
      isDirect: true,
    ),
  ];

  /// 全局线路列表：包含用户自定义配置的全部专属节点 + 公共线路
  static List<ProxyRoute> allRoutes = [
    ProxyRoute(
      id: 'custom_zb',
      name: '🚀 我的 Cloudflare 专属加速节点',
      region: '全球 Anycast 边缘专属专线 (zb.djseven.cc.cd)',
      prefix: 'https://zb.djseven.cc.cd/hls/live.m3u8?url=',
    ),
    ...defaultPublicRoutes,
  ];

  static const String _prefSelectedRouteKey = 'user_selected_proxy_route_id';
  static String _selectedRouteId = 'auto'; // 'auto' or route id
  static ProxyRoute? _currentFastestRoute;
  static bool _isBenchmarking = false;
  static DateTime? _lastBenchmarkTime;
  static String? defaultTestStreamUrl;
  static LocalNetworkMode localNetworkMode = LocalNetworkMode.unknown;
  static String localNetworkDesc = '正在测试本地网络...';

  static String get selectedRouteId => _selectedRouteId;
  static ProxyRoute? get currentFastestRoute => _currentFastestRoute;

  /// 初始化线路服务，恢复用户保存的手动选择线路
  static Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final savedId = sp.getString(_prefSelectedRouteKey);
      if (savedId != null && savedId.isNotEmpty) {
        _selectedRouteId = savedId;
      }
    } catch (_) {}
    await syncCustomDomainConfig();
  }

  /// 设置当前线路并进行本地持久化保存
  static Future<void> setSelectedRouteId(String id) async {
    _selectedRouteId = id;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_prefSelectedRouteKey, id);
    } catch (_) {}
  }

  /// 📶 诊断用户设备本地网络环境（是否处于科学上网/翻墙状态）
  static Future<void> detectLocalNetworkEnvironment() async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(milliseconds: 1800);

    try {
      final req = await client.getUrl(Uri.parse('https://www.google.com/generate_204'));
      final resp = await req.close().timeout(const Duration(milliseconds: 1800));
      if (resp.statusCode == 204 || resp.statusCode == 200) {
        localNetworkMode = LocalNetworkMode.vpnConnected;
        localNetworkDesc = '科学上网已就绪 (支持官方原画直连秒开)';
        client.close(force: true);
        return;
      }
    } catch (_) {}

    localNetworkMode = LocalNetworkMode.directMainland;
    localNetworkDesc = '国内网络直连 (推荐 Cloudflare 专属节点 / 自动优选)';
    client.close(force: true);
  }

  /// 动态同步用户在设置中自定义的多个 Cloudflare 域名
  static Future<void> syncCustomDomainConfig() async {
    try {
      final domains = await SettingsService.getCustomDomains();
      final List<ProxyRoute> customRoutes = [];

      // 记忆之前已测速的数据，避免重载时数据被清空
      final Map<String, int> oldLatencies = {for (var r in allRoutes) r.id: r.latencyMs};
      final Map<String, double> oldSpeeds = {for (var r in allRoutes) r.id: r.downloadSpeedKBps};
      final Map<String, bool> oldAvails = {for (var r in allRoutes) r.id: r.isAvailable};
      final Map<String, String?> oldReasons = {for (var r in allRoutes) r.id: r.unavailableReason};

      for (int i = 0; i < domains.length; i++) {
        var raw = domains[i].trim();
        if (raw.isEmpty) continue;

        // 自动补全 https:// 协议头，防止无 scheme 导致播放器解析异常
        if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
          raw = 'https://$raw';
        }
        // 容错移除末尾可能误填的 /hls、/hls/live.m3u8、/proxy 以及尾部多余斜杠
        raw = raw.replaceAll(RegExp(r'/hls(?:\?url=)?/?$'), '');
        raw = raw.replaceAll(RegExp(r'/hls/live\.m3u8(?:\?url=)?/?$'), '');
        raw = raw.replaceAll(RegExp(r'/proxy/?\??$'), '');
        raw = raw.replaceAll(RegExp(r'/+$'), '');

        final cleanBase = raw;
        final host = Uri.tryParse(cleanBase)?.host ?? cleanBase;
        final routeId = i == 0 ? 'custom_zb' : 'custom_node_${i + 1}';
        final nodeName = domains.length == 1
            ? '🚀 我的 Cloudflare 专属加速节点'
            : '🚀 专属加速节点 ${i + 1} ($host)';

        customRoutes.add(ProxyRoute(
          id: routeId,
          name: nodeName,
          region: '全球 Anycast 边缘专属专线 ($host)',
          prefix: '$cleanBase/hls/live.m3u8?url=',
          latencyMs: oldLatencies[routeId] ?? 9999,
          downloadSpeedKBps: oldSpeeds[routeId] ?? 0.0,
          isAvailable: oldAvails[routeId] ?? true,
          unavailableReason: oldReasons[routeId],
        ));
      }

      // 若用户未配置任何域名，默认保留一个基础专属节点
      if (customRoutes.isEmpty) {
        customRoutes.add(ProxyRoute(
          id: 'custom_zb',
          name: '🚀 我的 Cloudflare 专属加速节点',
          region: '全球 Anycast 边缘专属专线 (zb.djseven.cc.cd)',
          prefix: 'https://zb.djseven.cc.cd/hls/live.m3u8?url=',
        ));
      }

      // 动态重组：用户专属节点优先置顶，紧随公共加速与直连线路
      allRoutes = [
        ...customRoutes,
        ...defaultPublicRoutes,
      ];
    } catch (_) {}
  }

  /// 获取当前配置或测速选中的有效线路
  static ProxyRoute getActiveRoute({int fallbackOffset = 0}) {
    // 🌟 1. 最高铁律：如果用户手动选定了具体线路（非 'auto'），100% 严格锁定，绝不擅自降级或切换！
    if (_selectedRouteId != 'auto') {
      final found = allRoutes.firstWhere(
        (r) => r.id == _selectedRouteId,
        orElse: () => allRoutes.first,
      );
      return found;
    }

    // 🌟 2. 仅当用户处于【自动智能优选】模式时，才在可用候选池中排序与容灾轮换
    final candidates = List<ProxyRoute>.from(allRoutes.where((r) =>
        (localNetworkMode == LocalNetworkMode.vpnConnected || !r.isDirect) && r.isAvailable));

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        if (a.downloadSpeedKBps > 0 && b.downloadSpeedKBps > 0) {
          return b.downloadSpeedKBps.compareTo(a.downloadSpeedKBps);
        }
        if (a.downloadSpeedKBps > 0) return -1;
        if (b.downloadSpeedKBps > 0) return 1;
        return a.latencyMs.compareTo(b.latencyMs);
      });
    }

    if (fallbackOffset > 0 && candidates.isNotEmpty) {
      return candidates[fallbackOffset % candidates.length];
    }

    return (_currentFastestRoute != null && _currentFastestRoute!.isAvailable)
        ? _currentFastestRoute!
        : (candidates.isNotEmpty ? candidates.first : allRoutes.first);
  }

  /// 彻底剥离可能存在的任意代理前缀，还原为纯净的源站推流直链
  static String stripProxyPrefix(String url) {
    var clean = url.trim();
    bool changed = true;
    while (changed) {
      changed = false;
      // 1. 去除第三方 515355 反代前缀 (如 https://f00.515355.xyz/proxy/?)
      final match515 = RegExp(r'^https://[a-zA-Z0-9_.-]+\.515355\.xyz/proxy/\??').firstMatch(clean);
      if (match515 != null) {
        clean = clean.substring(match515.end);
        changed = true;
      }
      // 2. 去除 Cloudflare 专属或 Worker 前缀 (/hls?url= 或 /hls/playlist.m3u8?url= 或 /hls/segment.ts?url=)
      final matchCf = RegExp(r'^https://[^/]+/hls(?:/[^?]+)?\?url=').firstMatch(clean);
      if (matchCf != null) {
        clean = clean.substring(matchCf.end);
        try {
          clean = Uri.decodeComponent(clean);
        } catch (_) {}
        changed = true;
      }
      // 3. 去除 allRoutes 中定义的 prefix
      for (final r in allRoutes) {
        if (r.prefix.isNotEmpty && clean.startsWith(r.prefix)) {
          clean = clean.substring(r.prefix.length);
          if (clean.startsWith('?')) clean = clean.substring(1);
          try {
            clean = Uri.decodeComponent(clean);
          } catch (_) {}
          changed = true;
          break;
        }
      }
    }
    return clean;
  }

  /// 🚀 真实手机本地网络测速：100% 采用真实开播的直播流节点进行端到端极速测速
  static Future<ProxyRoute> benchmarkAndSelectFastest({String? customTestUrl, bool force = false}) async {
    if (!force &&
        _lastBenchmarkTime != null &&
        DateTime.now().difference(_lastBenchmarkTime!).inSeconds < 45 &&
        _currentFastestRoute != null) {
      return getActiveRoute();
    }

    if (_isBenchmarking) return getActiveRoute();
    _isBenchmarking = true;

    // 1. 先精准诊断手机本地网络是否开启了科学上网
    await detectLocalNetworkEnvironment();

    // 2. 动态同步用户自建域名
    await syncCustomDomainConfig();

    // 🌟 3. 获取真实正在开播的直播流作为全线路统一测速基准
    String? rawLiveStream;
    if (customTestUrl != null && customTestUrl.isNotEmpty) {
      final stripped = stripProxyPrefix(customTestUrl);
      if (stripped.startsWith('http') && stripped.contains('.m3u8')) {
        rawLiveStream = stripped;
      }
    }

    if (rawLiveStream == null && defaultTestStreamUrl != null && defaultTestStreamUrl!.isNotEmpty) {
      final stripped = stripProxyPrefix(defaultTestStreamUrl!);
      if (stripped.startsWith('http') && stripped.contains('.m3u8')) {
        rawLiveStream = stripped;
      }
    }

    if (rawLiveStream == null) {
      final active = ApiService.getAnyActiveLiveStream();
      if (active != null) {
        rawLiveStream = stripProxyPrefix(active);
      }
    }

    if (rawLiveStream == null) {
      await ApiService.ensureGlobalM3uLoaded();
      final active = ApiService.getAnyActiveLiveStream();
      if (active != null) {
        rawLiveStream = stripProxyPrefix(active);
      }
    }

    // 兜底备用：如果列表尚未加载，使用当前开播的公共回退直播推流
    rawLiveStream ??= 'https://ffdced10e5f6.usw22.playlist.live-video.net/v1/playlist/CucF-rd5ErvzOCY6QalXrUSaJPbxguKNJwbp_GupVCgsQbwBjEgLvQhvvrOH3Fv1LfCcrY_Vk95QWkzpS_U12628Bt3mmLPFmDcWayDhcVzdbKmygDJ2ZecbvuKd7fs6JlMd2X0jnkPisAmq-1zMwLTilCrCn3PzrnRHnin-EUcjxxGPdFBl_16KCWKtlfGUO3Ubbylntf45pOXfmLXOPNVZ44-TuX1vswAD53tTu2kLjYi7Ttj_AclMGI6zCy-4Gfur5uG1khaaCsfV-ugYM_E93NPhttFrdzFJisS4-b5ozrFOarTYGQEa486QEj5kPcn7ic0Q1dtldqBEH-vJWwzLJEWkf8mQn-7GL3FmQI9TIknEzY6Vms3rpLyfz-Mwnp6WFZu0MUcdrS5NhGj4NaFkhMAlUk5Z1lAdCwEuqC0wLMo_B_Qi-AS49jS5CoqP9YEsJ6QYDeZGYe_6QSYztnmMZX23rwGtqrWCK2cFrp1oN3HZKG4bNgVHi3SN_vWYeK1g8bvHyaBwOBwuK9H6qwM0tYKaUGevFgs_-_b1mDQST1kNVNjsppl25D1DxTcegShFPAuFB2ge-wnK9EacH19UHtrj3OWKxeopeCHl33lW3R4EQw9za-xI01xWV-fz4cQ4H3k8mNZu9Ab8Alb8gpDrvKnNseFnTAXvpO1u-3-rO7yEncFeDs7inogP_fhEJe6ATL2vI0Dvmq52MPrYccIdySneus35c2rK-qlHnCdQpyN3jFejqeBCxrU4D6hyfMUQXsh6ZFkiKjvT5DUb6W3NoLlEzhbEE0JgOd3ZJT_C9OtyegrUJ0eHAxWoNJFB_KwdmBpiqrWXC1o-_9qvK8oYOftdLYFQIZRWN_8BsRd8WA18-Ua59rn69KCByH1sCe0gCspqGFx7i2p2Tya9-4SAAqL61DFyNKy5_pvLdZe2IabtvMuQW6NqeuVn8H8dm5AB8yNm5f0kxDIRzWHmHWo81Mh0RS0poMsaDHENYb_H5Otoo2T5gCABKgl1cy13ZXN0LTIwkBA.m3u8';

    defaultTestStreamUrl = rawLiveStream;

    try {
      await Future.wait(allRoutes.map((route) async {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        client.connectionTimeout = const Duration(milliseconds: 6000);

        try {
          // 官方直连在纯净国内网络下必然超时不通，直接精准标记
          if (route.isDirect && localNetworkMode == LocalNetworkMode.directMainland) {
            route.latencyMs = 9999;
            route.downloadSpeedKBps = 0.0;
            route.isAvailable = false;
            route.unavailableReason = '需开科学上网 (国内直连受限)';
            return;
          }

          // 🌟 统一构造真实直播推流测速地址：
          // 所有线路统一采用真实正在开播的直播流进行端到端测速！
          String testUrl;
          if (route.isDirect) {
            testUrl = rawLiveStream!;
          } else if (route.id.startsWith('custom')) {
            testUrl = '${route.prefix}${Uri.encodeComponent(rawLiveStream!)}';
          } else {
            testUrl = '${route.prefix}$rawLiveStream';
          }

          final req = await client.getUrl(Uri.parse(testUrl));
          req.headers.set(
            'User-Agent',
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          );
          req.headers.set('Accept', '*/*');
          if (route.isDirect || !route.id.startsWith('custom')) {
            req.headers.set('Origin', 'https://www.pandalive.co.kr');
            req.headers.set('Referer', 'https://www.pandalive.co.kr/');
          }

          final t0 = DateTime.now().millisecondsSinceEpoch;
          final resp = await req.close().timeout(const Duration(milliseconds: 6000));
          final ttfb = DateTime.now().millisecondsSinceEpoch - t0;

          if (resp.statusCode == 200 || (resp.statusCode == 204 && route.isDirect)) {
            route.latencyMs = ttfb;
            route.isAvailable = true;
            route.unavailableReason = null;

            // 🌟 核心突破：直接从真实直播流中读取 M3U8 并测试下行速率
            int receivedBytes = 0;
            final tStreamStart = DateTime.now().millisecondsSinceEpoch;

            final chunks = <List<int>>[];
            await for (final chunk in resp.timeout(const Duration(milliseconds: 4000))) {
              receivedBytes += chunk.length;
              chunks.add(chunk);
              if (receivedBytes >= 128 * 1024) break;
            }

            final int durationMs = DateTime.now().millisecondsSinceEpoch - tStreamStart;
            final double seconds = durationMs > 0 ? durationMs / 1000.0 : 0.05;
            double speedKBps = (receivedBytes / 1024.0) / seconds;

            // 🌟 进阶深度测速：提取真实 TS 视频切片进行真实分片下载测速 (128KB)
            if (chunks.isNotEmpty) {
              try {
                final text = utf8.decode(chunks.expand((e) => e).toList(), allowMalformed: true);
                if (text.contains('#EXTM3U')) {
                  String? segmentUrl;
                  for (final line in text.split('\n')) {
                    final trimmed = line.trim();
                    if (trimmed.startsWith('http') &&
                        (trimmed.contains('.ts') ||
                         trimmed.contains('/segment/') ||
                         trimmed.startsWith('#EXT-X-PREFETCH:'))) {
                      segmentUrl = trimmed.replaceFirst('#EXT-X-PREFETCH:', '').trim();
                      break;
                    }
                  }

                  if (segmentUrl != null && segmentUrl.startsWith('http')) {
                    final tsReq = await client.getUrl(Uri.parse(segmentUrl));
                    tsReq.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14; Mobile)');
                    tsReq.headers.set('Range', 'bytes=0-131071');
                    tsReq.headers.set('Accept', '*/*');
                    final tSegStart = DateTime.now().millisecondsSinceEpoch;
                    final tsResp = await tsReq.close().timeout(const Duration(milliseconds: 4000));
                    if (tsResp.statusCode == 200 || tsResp.statusCode == 206) {
                      int segBytes = 0;
                      await for (final chunk in tsResp.timeout(const Duration(milliseconds: 3000))) {
                        segBytes += chunk.length;
                        if (segBytes >= 128 * 1024) break;
                      }
                      final int segDuration = DateTime.now().millisecondsSinceEpoch - tSegStart;
                      if (segBytes > 0 && segDuration > 0) {
                        speedKBps = (segBytes / 1024.0) / (segDuration / 1000.0);
                      }
                    }
                  }
                }
              } catch (_) {}
            }

            route.downloadSpeedKBps = speedKBps > 0 ? speedKBps : 380.0;
          } else {
            route.latencyMs = 9999;
            route.downloadSpeedKBps = 0.0;
            route.isAvailable = false;
            route.unavailableReason = '节点异常 (HTTP ${resp.statusCode})';
          }
        } catch (_) {
          route.latencyMs = 9999;
          route.downloadSpeedKBps = 0.0;
          route.isAvailable = false;
          route.unavailableReason = route.isDirect ? '需开梯子 (国内直连超时)' : '本地连接超时';
        } finally {
          client.close(force: true);
        }
      }));

      _lastBenchmarkTime = DateTime.now();

      // 🌟 核心智能择优规则：从本地真实连通的线路中挑选吞吐量最高、延迟最低的节点
      // 若检测到科学上网已连接，官方原画直连自动参与择优池
      final availableProxies = allRoutes
          .where((r) =>
              (localNetworkMode == LocalNetworkMode.vpnConnected || !r.isDirect) &&
              r.isAvailable &&
              r.latencyMs < 9000)
          .toList();

      if (availableProxies.isNotEmpty) {
        availableProxies.sort((a, b) {
          // 专属节点优先（因为支持全链路切片重写与边缘缓存，解决 5G 播放一段时间后限速卡顿的痛点）
          final aIsCustom = a.id.startsWith('custom');
          final bIsCustom = b.id.startsWith('custom');
          if (aIsCustom != bIsCustom) {
            return aIsCustom ? -1 : 1;
          }

          if (a.downloadSpeedKBps > 0 && b.downloadSpeedKBps > 0) {
            return b.downloadSpeedKBps.compareTo(a.downloadSpeedKBps);
          }
          if (a.downloadSpeedKBps > 0) return -1;
          if (b.downloadSpeedKBps > 0) return 1;
          return a.latencyMs.compareTo(b.latencyMs);
        });
        _currentFastestRoute = availableProxies.first;
      } else {
        // 如果没有可用海外节点，默认回退至 Cloudflare 专属节点或 CDN
        _currentFastestRoute = allRoutes.firstWhere(
          (r) => r.id == 'custom_zb' || r.id == 'custom_worker' || r.id == 'f00',
          orElse: () => allRoutes.first,
        );
      }
    } catch (_) {
      _currentFastestRoute = allRoutes.firstWhere(
        (r) => r.id == 'custom_zb' || r.id == 'custom_worker' || r.id == 'f00',
        orElse: () => allRoutes.first,
      );
    } finally {
      _isBenchmarking = false;
    }

    return getActiveRoute();
  }

  /// 获取当前最快代理前缀
  static String getFastestProxyPrefix() {
    final active = getActiveRoute();
    return active.prefix;
  }
}
