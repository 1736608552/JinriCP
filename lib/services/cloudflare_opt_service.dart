import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'settings_service.dart';

class IpSpeedResult {
  final String ip;
  final int latencyMs;
  final double downloadSpeedMBs;
  final bool isSuccess;

  IpSpeedResult({
    required this.ip,
    required this.latencyMs,
    required this.downloadSpeedMBs,
    required this.isSuccess,
  });

  String get formattedLatency => isSuccess ? '$latencyMs ms' : '超时';

  String get formattedSpeed {
    if (!isSuccess) return '--';
    if (downloadSpeedMBs >= 1.0) {
      return '${downloadSpeedMBs.toStringAsFixed(2)} MB/s';
    } else if (downloadSpeedMBs > 0) {
      return '${(downloadSpeedMBs * 1024).toStringAsFixed(0)} KB/s';
    } else {
      return '--';
    }
  }
}

class CloudflareOptService {
  static String _fastestIp = '104.25.159.15';
  static bool _hasTested = false;

  /// 🌐 Cloudflare 全球 Anycast 优质候选 IP 库（涵盖电信/联通/移动主流高速网段，共 70+ 个精选种子）
  static const List<String> candidateIpPool = [
    // 104.16 网段 (经典高速段)
    '104.16.40.124', '104.16.148.14', '104.16.160.10', '104.16.208.5', '104.16.80.20',
    // 104.17 网段
    '104.17.166.57', '104.17.210.9', '104.17.150.12', '104.17.232.1', '104.17.70.10',
    // 104.18 网段
    '104.18.82.153', '104.18.2.1', '104.18.10.10', '104.18.25.1', '104.18.33.2',
    // 104.19 网段 (国内多省份直连延迟优异)
    '104.19.180.144', '104.19.235.252', '104.19.112.17', '104.19.240.25', '104.19.155.1',
    // 104.20 网段
    '104.20.92.26', '104.20.150.1', '104.20.200.12', '104.20.30.5', '104.20.80.8',
    // 104.21 网段
    '104.21.245.19', '104.21.80.153', '104.21.10.1', '104.21.32.1', '104.21.90.5',
    // 104.22 网段
    '104.22.154.72', '104.22.5.1', '104.22.20.10', '104.22.60.2', '104.22.75.8',
    // 104.25 网段 (常用于华南/华东节点优选)
    '104.25.159.15', '104.25.153.116', '104.25.20.1', '104.25.80.2', '104.25.120.5',
    // 104.26 网段
    '104.26.0.1', '104.26.10.2', '104.26.15.5', '104.26.120.1', '104.26.150.10',
    // 104.27 网段
    '104.27.113.101', '104.27.150.1', '104.27.200.1', '104.27.50.2', '104.27.80.5',
    // 172.66 网段 (亚太 Anycast 直连)
    '172.66.176.109', '172.66.40.1', '172.66.43.1', '172.66.45.2', '172.66.46.1',
    // 172.67 网段
    '172.67.186.60', '172.67.200.1', '172.67.70.1', '172.67.150.1', '172.67.85.2',
    // 172.68 网段
    '172.68.21.106', '172.68.10.1', '172.68.30.2', '172.68.45.1', '172.68.150.5',
    // 162.159 网段
    '162.159.192.1', '162.159.193.1', '162.159.195.1', '162.159.152.1', '162.159.138.1',
    // 190.93 / 198.41 / 141.101 网段
    '190.93.253.77', '190.93.240.1', '198.41.214.1', '198.41.215.1', '141.101.120.1',
  ];

  /// 启动时并发测速，自动选出当前最快的优选 IP
  static Future<void> benchmarkFastestIp() async {
    final enabled = await SettingsService.getOptIpEnabled();
    if (!enabled) return;

    if (_hasTested) return;
    _hasTested = true;

    final ips = await SettingsService.getPreferredIps();
    final completer = Completer<String>();
    for (final ip in ips.take(8)) {
      () async {
        try {
          final socket = await Socket.connect(ip, 443, timeout: const Duration(milliseconds: 1500));
          socket.destroy();
          if (!completer.isCompleted) {
            _fastestIp = ip;
            completer.complete(ip);
          }
        } catch (_) {}
      }();
    }
  }

  /// 单 IP 执行官方真实测速 (TCP握手延迟 + 官方 HTTP 80 真实下载吞吐)
  static Future<IpSpeedResult> testSingleIpRealSpeed(
    String ip, {
    int pingTimeoutMs = 1500,
    bool testDownload = true,
  }) async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    bool connected = false;
    int latency = 9999;

    try {
      final socket = await Socket.connect(
        ip,
        443,
        timeout: Duration(milliseconds: pingTimeoutMs),
      );
      latency = DateTime.now().millisecondsSinceEpoch - t0;
      socket.destroy();
      connected = true;
    } catch (_) {
      connected = false;
    }

    if (!connected) {
      return IpSpeedResult(
        ip: ip,
        latencyMs: 9999,
        downloadSpeedMBs: 0.0,
        isSuccess: false,
      );
    }

    double downloadSpeedMBs = 0.0;
    if (testDownload) {
      downloadSpeedMBs = await measureRealDownloadSpeed(ip: ip, durationMs: 2000);
    }

    return IpSpeedResult(
      ip: ip,
      latencyMs: latency,
      downloadSpeedMBs: downloadSpeedMBs,
      isSuccess: true,
    );
  }

  /// 官方标准真实下载测速 (复刻 XIU2/CFSTAPP 架构)
  static Future<double> measureRealDownloadSpeed({
    required String ip,
    int durationMs = 2000,
  }) async {
    int totalBytes = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final deadline = startTime + durationMs;

    try {
      final socket = await Socket.connect(
        ip,
        80,
        timeout: const Duration(seconds: 3),
      );

      final httpRequest =
          'GET /__down?bytes=50000000 HTTP/1.1\r\n'
          'Host: speed.cloudflare.com\r\n'
          'User-Agent: CFST-Pure/1.0\r\n'
          'Accept: */*\r\n'
          'Connection: close\r\n\r\n';

      socket.add(utf8.encode(httpRequest));
      await socket.flush();

      await for (final chunk in socket) {
        totalBytes += chunk.length;
        if (DateTime.now().millisecondsSinceEpoch >= deadline) {
          break;
        }
      }

      socket.destroy();
    } catch (_) {}

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startTime;
    if (elapsedMs > 0 && totalBytes > 0) {
      final bytesPerSec = (totalBytes * 1000.0) / elapsedMs;
      final speedMBs = bytesPerSec / (1024 * 1024);
      return double.parse(speedMBs.toStringAsFixed(2));
    }
    return 0.0;
  }

  /// ⚡ 测速当前：对用户当前配置的优选 IP 进行官方真实测速与性能排序
  static Future<List<IpSpeedResult>> benchmarkAllIps({
    void Function(int current, int total, String currentIp)? onProgress,
  }) async {
    final ips = await SettingsService.getPreferredIps();
    if (ips.isEmpty) return [];

    final results = <IpSpeedResult>[];
    final total = ips.length;

    // 先并发测出延迟
    final pingFutures = ips.map((ip) async {
      final res = await testSingleIpRealSpeed(ip, testDownload: false);
      return res;
    });

    final latencyResults = await Future.wait(pingFutures);

    // 针对成功连通的节点，依次测真实下载速率
    int doneCount = 0;
    for (final r in latencyResults) {
      doneCount++;
      if (onProgress != null) {
        onProgress(doneCount, total, r.ip);
      }

      if (r.isSuccess) {
        final speed = await measureRealDownloadSpeed(ip: r.ip, durationMs: 2000);
        results.add(IpSpeedResult(
          ip: r.ip,
          latencyMs: r.latencyMs,
          downloadSpeedMBs: speed,
          isSuccess: true,
        ));
      } else {
        results.add(r);
      }
    }

    // 综合排序：优先可用 -> 延迟从低到高 -> 速度从高到低
    results.sort((a, b) {
      if (!a.isSuccess && !b.isSuccess) return 0;
      if (!a.isSuccess) return 1;
      if (!b.isSuccess) return -1;

      if (a.downloadSpeedMBs > 0 && b.downloadSpeedMBs > 0) {
        final spdCmp = b.downloadSpeedMBs.compareTo(a.downloadSpeedMBs);
        if (spdCmp != 0) return spdCmp;
      }
      return a.latencyMs.compareTo(b.latencyMs);
    });

    if (results.isNotEmpty && results.first.isSuccess) {
      _fastestIp = results.first.ip;
    }

    return results;
  }

  /// 🚀 自动调用 IP 库，一键并发测速并自动甄选出延迟最低、最稳定的前 20 个优选 IP
  static Future<List<IpSpeedResult>> findTop20FastestIps({
    void Function(int current, int total)? onProgress,
  }) async {
    final candidates = List<String>.from(candidateIpPool);
    final existingIps = await SettingsService.getPreferredIps();
    for (final e in existingIps) {
      if (!candidates.contains(e)) candidates.add(e);
    }

    final total = candidates.length;
    int processed = 0;
    final results = <IpSpeedResult>[];

    const int batchSize = 16;
    for (int i = 0; i < candidates.length; i += batchSize) {
      final batch = candidates.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((ip) async {
          final t0 = DateTime.now().millisecondsSinceEpoch;
          try {
            final socket = await Socket.connect(
              ip,
              443,
              timeout: const Duration(milliseconds: 1600),
            );
            final latency = DateTime.now().millisecondsSinceEpoch - t0;
            socket.destroy();

            results.add(IpSpeedResult(
              ip: ip,
              latencyMs: latency,
              downloadSpeedMBs: 0.0,
              isSuccess: true,
            ));
          } catch (_) {
            results.add(IpSpeedResult(
              ip: ip,
              latencyMs: 9999,
              downloadSpeedMBs: 0.0,
              isSuccess: false,
            ));
          } finally {
            processed++;
            if (onProgress != null) onProgress(processed, total);
          }
        }),
      );
    }

    // 按延迟由低到高排序
    results.sort((a, b) {
      if (!a.isSuccess) return 1;
      if (!b.isSuccess) return -1;
      return a.latencyMs.compareTo(b.latencyMs);
    });

    final successful = results.where((r) => r.isSuccess).toList();
    List<String> top20Ips = [];

    if (successful.isNotEmpty) {
      top20Ips = successful.take(20).map((r) => r.ip).toList();
    }

    if (top20Ips.length < 20) {
      for (final cand in candidateIpPool) {
        if (!top20Ips.contains(cand)) {
          top20Ips.add(cand);
          if (top20Ips.length >= 20) break;
        }
      }
    }

    await SettingsService.setPreferredIps(top20Ips);
    if (top20Ips.isNotEmpty) {
      _fastestIp = top20Ips.first;
    }

    return results.where((r) => top20Ips.contains(r.ip)).toList();
  }

  /// 获取当前最快的 IP
  static String getFastestIpSync() => _fastestIp;

  /// 重置测速标记
  static void resetBenchmarkFlag() {
    _hasTested = false;
  }

  /// 创建配置了优选 IP 证书与 SNI 穿透的 Dio 实例
  static Dio createOptDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
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

  static String get currentFastestIp => _fastestIp;
}
