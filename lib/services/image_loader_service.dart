import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'cloudflare_opt_service.dart';
import 'crypto_service.dart';
import 'proxy_route_service.dart';

/// 🌟 高性能底层图片加载与自愈中继引擎
/// 彻底解决 Android 原生 NetworkImage 证书阻断、防盗链 403、TLS EOF、相对路径失效等全部底层痛点
class ImageLoaderService {
  // 内存高速缓存 (URL -> 图片二进制字节)
  static final Map<String, Uint8List> _memoryCache = {};

  // 请求去重映射表 (避免同时发起多个相同图片的重复请求)
  static final Map<String, Future<Uint8List?>> _inFlightRequests = {};

  // 专用优化 Dio 客户端
  static final Dio _dio = CloudflareOptService.createOptDio();

  /// 检查内存中是否有缓存
  static Uint8List? getCachedImage(String url) {
    return _memoryCache[url];
  }

  /// 底层自愈加载图片，多重策略穿透防盗链与网络阻断
  static Future<Uint8List?> loadImage(String url, {String domain = ''}) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
      return null;
    }

    // 1. 命中内存缓存
    if (_memoryCache.containsKey(cleanUrl)) {
      return _memoryCache[cleanUrl];
    }

    // 2. 去重防并发
    if (_inFlightRequests.containsKey(cleanUrl)) {
      return await _inFlightRequests[cleanUrl];
    }

    final completer = _fetchWithMultiStrategy(cleanUrl, domain: domain);
    _inFlightRequests[cleanUrl] = completer;

    try {
      final bytes = await completer;
      if (bytes != null && bytes.isNotEmpty) {
        _memoryCache[cleanUrl] = bytes;
        // 控制缓存容量（最多缓存 200 张封面，避免内存溢出）
        if (_memoryCache.length > 200) {
          _memoryCache.remove(_memoryCache.keys.first);
        }
      }
      return bytes;
    } finally {
      _inFlightRequests.remove(cleanUrl);
    }
  }

  /// 多策略深度尝试获取图片数据
  static Future<Uint8List?> _fetchWithMultiStrategy(String rawUrl, {String domain = ''}) async {
    // 🌟 核心自愈：自动将历史失效图片 CDN (tuafjz.cn / eanfog.cn) 重写映射为当前真实活跃直连 CDN pic.wirqed.cn
    var url = rawUrl.trim();
    if (url.contains('pic.tuafjz.cn')) {
      url = url.replaceAll('pic.tuafjz.cn', 'pic.wirqed.cn');
    } else if (url.contains('pic.eanfog.cn')) {
      url = url.replaceAll('pic.eanfog.cn', 'pic.wirqed.cn');
    }

    final String? referer;
    final bool isDramaCdn = url.contains('wirqed.cn') || url.contains('huangguo');
    if (isDramaCdn) {
      // 官方源站标明 <meta name="referrer" content="no-referrer">，短剧图片纯净无 Referer 直连秒开
      referer = null;
    } else if (domain.isNotEmpty) {
      referer = domain.endsWith('/') ? domain : '$domain/';
    } else if (url.contains('pandalive.co.kr')) {
      referer = 'https://www.pandalive.co.kr/';
    } else if (url.contains('flextv.co.kr') || url.contains('naverncp.com')) {
      referer = 'https://www.flextv.co.kr/';
    } else {
      referer = null;
    }

    // 策略列表：
    // 1. 直连（无 Referer，针对符合 W3C no-referrer 规范的 CDN 最优选）
    // 2. 直连（带平台专属/自定义 Referer）
    // 3. weserv.nl 图像极速加速与转码中继 (破除防盗链)
    // 4. wsrv.nl 备用加速中继
    // 5. 跨域节点代理中继
    final strategies = <_ImageFetchPlan>[
      _ImageFetchPlan(
        name: 'Direct-No-Referer',
        url: url,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        },
      ),
      if (referer != null)
        _ImageFetchPlan(
          name: 'Direct-With-Referer',
          url: url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
            'Referer': referer,
          },
        ),
      _ImageFetchPlan(
        name: 'Weserv-Cloud-Relay',
        url: 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&output=jpg&w=480&q=85',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      ),
      _ImageFetchPlan(
        name: 'Wsrv-WebP-Relay',
        url: 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}&output=webp&w=480&q=85',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      ),
      _ImageFetchPlan(
        name: 'Proxy-Node-Relay',
        url: '${ProxyRouteService.getFastestProxyPrefix().isNotEmpty ? ProxyRouteService.getFastestProxyPrefix() : "https://f00.515355.xyz/proxy/"}$url',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      ),
    ];

    for (final plan in strategies) {
      try {
        final response = await _dio.get<List<int>>(
          plan.url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: plan.headers,
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (status) => status != null && status >= 200 && status < 400,
          ),
        );

        if (response.data != null && response.data!.length > 64) {
          final rawBytes = Uint8List.fromList(response.data!);
          
          // 1. 如果本身已经是合法的标准图片（如各大直播平台、未加密封面等），直接返回，严禁二次解密
          if (_isValidImageBytes(rawBytes)) {
            return rawBytes;
          }

          // 2. 否则尝试使用 AES-CTR 解密（针对源站加密的图片）
          final decryptedBytes = CryptoService.decryptImage(rawBytes);

          // 3. 验证解密后的数据是否为合法图片格式
          if (_isValidImageBytes(decryptedBytes)) {
            return decryptedBytes;
          }
        }
      } catch (_) {
        // 当前策略失败，自动无缝尝试下一策略
      }
    }

    return null;
  }

  /// 校验二进制数据是否为合法的图片格式（JPEG, PNG, WebP, GIF, BMP, AVIF/HEIC）
  static bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 8) return false;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;

    // GIF: 47 49 46 38 ('GIF8')
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;

    // WebP: RIFF ... WEBP
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes.length > 12 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }

    // AVIF / HEIC / MP4 (ftyp)
    if (bytes.length > 12 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      return true;
    }

    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;

    return false;
  }
}

class _ImageFetchPlan {
  final String name;
  final String url;
  final Map<String, dynamic> headers;

  _ImageFetchPlan({
    required this.name,
    required this.url,
    required this.headers,
  });
}
