import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// 单个节点的测速结果模型 (完全对齐 CFSTAPP / XIU2 规范)
class CfstResult {
  final String ip;
  final int sent;
  final int received;
  final double packetLoss; // 丢包率百分比 (0.0 ~ 100.0)
  final int avgLatency; // 平均延迟 (毫秒)
  final int minLatency; // 最小延迟
  final int maxLatency; // 最大延迟
  double downloadSpeedMBs; // 真实下载速率 (MB/s)
  bool downloadTested; // 是否已完成下载测速

  CfstResult({
    required this.ip,
    required this.sent,
    required this.received,
    required this.packetLoss,
    required this.avgLatency,
    required this.minLatency,
    required this.maxLatency,
    this.downloadSpeedMBs = 0.0,
    this.downloadTested = false,
  });

  bool get isAvailable => received > 0 && avgLatency < 9000;

  String get formattedLatency => isAvailable ? '$avgLatency ms' : '超时';

  String get formattedLoss => '${packetLoss.toStringAsFixed(0)}%';

  String get formattedSpeed {
    if (!downloadTested) return '--';
    if (downloadSpeedMBs >= 1.0) {
      return '${downloadSpeedMBs.toStringAsFixed(2)} MB/s';
    } else if (downloadSpeedMBs > 0) {
      return '${(downloadSpeedMBs * 1024).toStringAsFixed(0)} KB/s';
    } else {
      return '0.00 MB/s';
    }
  }
}

/// 测速配置参数
class CfstConfig {
  final int testCount; // 候选 IP 数量 (默认 50)
  final int pingCount; // 每个 IP Ping 次数 (默认 3 次)
  final int pingTimeoutMs; // 单次 Ping 超时 (默认 1200ms)
  final int port; // 测速端口 (443 或 80)
  final bool enableDownloadTest; // 是否测真实下载速度 (默认 true)
  final int downloadDurationMs; // 单节点下载测速最长时间 (默认 3500ms)
  final int downloadTopCount; // 对前 N 个最优节点测下载速度 (默认 20)
  final int maxConcurrentPings; // 并发 Ping 数 (默认 8)

  const CfstConfig({
    this.testCount = 50,
    this.pingCount = 3,
    this.pingTimeoutMs = 1200,
    this.port = 443,
    this.enableDownloadTest = true,
    this.downloadDurationMs = 3500,
    this.downloadTopCount = 20,
    this.maxConcurrentPings = 8,
  });
}

/// 测速实时进度通知
class CfstProgress {
  final int phase; // 1: Ping 筛查, 2: 下载测速
  final int current; // 当前已测数量
  final int total; // 本阶段总数
  final String currentIp; // 正在测试的 IP
  final String statusText; // 状态描述

  CfstProgress({
    required this.phase,
    required this.current,
    required this.total,
    required this.currentIp,
    required this.statusText,
  });

  double get percent => total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
}

/// CIDR 解析与采样工具 (参考 CFSTAPP IpRangeParser)
class CfstIpParser {
  /// Cloudflare 官方公布的核心 IPv4 CIDR 段
  static const List<String> officialIpv4Cidrs = [
    '173.245.48.0/20',
    '103.21.244.0/22',
    '103.22.200.0/22',
    '103.31.4.0/22',
    '141.101.64.0/18',
    '108.162.192.0/18',
    '190.93.240.0/20',
    '188.114.96.0/20',
    '197.234.240.0/22',
    '198.41.128.0/17',
    '162.158.0.0/15',
    '104.16.0.0/13',
    '104.24.0.0/14',
    '172.64.0.0/13',
    '131.0.72.0/22',
  ];

  /// 国内访问优异的精选优质种子库
  static const List<String> highQualitySeeds = [
    '104.16.40.124', '104.16.148.14', '104.16.160.10', '104.16.208.5', '104.16.80.20',
    '104.17.166.57', '104.17.210.9', '104.17.150.12', '104.17.232.1', '104.17.70.10',
    '104.18.82.153', '104.18.2.1', '104.18.10.10', '104.18.25.1', '104.18.33.2',
    '104.19.180.144', '104.19.235.252', '104.19.112.17', '104.19.240.25', '104.19.155.1',
    '104.20.92.26', '104.20.150.1', '104.20.200.12', '104.20.30.5', '104.20.80.8',
    '104.21.245.19', '104.21.80.153', '104.21.10.1', '104.21.32.1', '104.21.90.5',
    '104.22.154.72', '104.22.5.1', '104.22.20.10', '104.22.60.2', '104.22.75.8',
    '104.25.159.15', '104.25.153.116', '104.25.20.1', '104.25.80.2', '104.25.120.5',
    '104.26.0.1', '104.26.10.2', '104.26.15.5', '104.26.120.1', '104.26.150.10',
    '104.27.113.101', '104.27.150.1', '104.27.200.1', '104.27.50.2', '104.27.80.5',
    '172.66.176.109', '172.66.40.1', '172.66.43.1', '172.66.45.2', '172.66.46.1',
    '172.67.186.60', '172.67.200.1', '172.67.70.1', '172.67.150.1', '172.67.85.2',
    '172.68.21.106', '172.68.10.1', '172.68.30.2', '172.68.45.1', '172.68.150.5',
    '162.159.192.1', '162.159.193.1', '162.159.195.1', '162.159.152.1', '162.159.138.1',
    '190.93.253.77', '190.93.240.1', '198.41.214.1', '198.41.215.1', '141.101.120.1',
  ];

  static int? ipToInt(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length != 4) return null;
      int res = 0;
      for (final p in parts) {
        final n = int.parse(p);
        if (n < 0 || n > 255) return null;
        res = (res << 8) | n;
      }
      return res;
    } catch (_) {
      return null;
    }
  }

  static String intToIp(int val) {
    return '${(val >> 24) & 0xFF}.${(val >> 16) & 0xFF}.${(val >> 8) & 0xFF}.${val & 0xFF}';
  }

  /// 从 CIDR 网段随机抽样生成候选 IP
  static List<String> sampleIpsFromCidrs({
    required int targetCount,
    List<String>? extraIps,
  }) {
    final results = <String>{};
    final random = Random();

    // 优先添加用户自定或精选的高速种子
    if (extraIps != null) {
      for (final ip in extraIps) {
        if (ip.trim().isNotEmpty) results.add(ip.trim());
      }
    }
    for (final s in highQualitySeeds) {
      if (results.length >= targetCount) break;
      results.add(s);
    }

    // 从各大 CIDR 网段随机散列采样
    final cidrPairs = <List<int>>[];
    for (final cidr in officialIpv4Cidrs) {
      final split = cidr.split('/');
      if (split.length != 2) continue;
      final ipInt = ipToInt(split[0]);
      final prefix = int.tryParse(split[1]);
      if (ipInt == null || prefix == null) continue;
      final mask = prefix == 0 ? 0 : (~0 << (32 - prefix)) & 0xFFFFFFFF;
      final start = ipInt & mask;
      final end = start | (~mask & 0xFFFFFFFF);
      cidrPairs.add([start, end]);
    }

    int attempts = 0;
    while (results.length < targetCount && attempts < targetCount * 5 && cidrPairs.isNotEmpty) {
      attempts++;
      final pair = cidrPairs[random.nextInt(cidrPairs.length)];
      final range = pair[1] - pair[0];
      if (range <= 0) continue;
      // 避免取全 0 网络地址与全 255 广播地址
      final offset = 1 + random.nextInt(max(1, range - 2));
      final sampledInt = pair[0] + offset;
      results.add(intToIp(sampledInt));
    }

    return results.toList();
  }
}

/// CFST 核心测速引擎 (移植自 Hsia97/CFSTAPP 与 XIU2/CloudflareSpeedTest)
class CfstEngine {
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
  }

  /// 启动完整测速流水线
  Future<List<CfstResult>> runSpeedTest({
    required CfstConfig config,
    required void Function(CfstProgress progress) onProgress,
    List<String>? extraIps,
  }) async {
    _isCancelled = false;

    // 1. 生成候选 IP 池
    onProgress(CfstProgress(
      phase: 1,
      current: 0,
      total: config.testCount,
      currentIp: '初始化 IP 池',
      statusText: '正在从 Cloudflare 官方网段中智能采样候选 IP...',
    ));

    final candidateIps = CfstIpParser.sampleIpsFromCidrs(
      targetCount: config.testCount,
      extraIps: extraIps,
    );

    // 2. 第一阶段：并发 TCP Ping 筛选延迟与丢包率
    final pingResults = <CfstResult>[];
    int processedCount = 0;

    // 并发控制器
    final pool = <Future<void>>[];
    final maxConcurrent = config.maxConcurrentPings.clamp(2, 16);

    for (final ip in candidateIps) {
      if (_isCancelled) break;

      final task = () async {
        final res = await _singleIpTcpPing(
          ip: ip,
          port: config.port,
          count: config.pingCount,
          timeoutMs: config.pingTimeoutMs,
        );

        pingResults.add(res);
        processedCount++;

        onProgress(CfstProgress(
          phase: 1,
          current: processedCount,
          total: candidateIps.length,
          currentIp: ip,
          statusText: '已探测 ${processedCount}/${candidateIps.length} 个节点 (当前: $ip, 延时: ${res.formattedLatency})',
        ));
      }();

      pool.add(task);
      if (pool.length >= maxConcurrent) {
        await Future.any(pool);
        pool.removeWhere((f) => true); // 简化并发等待
      }
    }

    await Future.wait(pool);

    if (_isCancelled) return pingResults;

    // 阶段一排序：优先按丢包率升序，再按平均延迟升序
    pingResults.sort((a, b) {
      if (!a.isAvailable && !b.isAvailable) return 0;
      if (!a.isAvailable) return 1;
      if (!b.isAvailable) return -1;

      final lossCmp = a.packetLoss.compareTo(b.packetLoss);
      if (lossCmp != 0) return lossCmp;
      return a.avgLatency.compareTo(b.avgLatency);
    });

    // 3. 第二阶段：真实下载测速 (针对延迟最低的前 N 个节点)
    if (config.enableDownloadTest && !_isCancelled) {
      final availableIps = pingResults.where((r) => r.isAvailable).toList();
      final downloadCandidates = availableIps.take(config.downloadTopCount).toList();

      for (int i = 0; i < downloadCandidates.length; i++) {
        if (_isCancelled) break;
        final target = downloadCandidates[i];

        onProgress(CfstProgress(
          phase: 2,
          current: i + 1,
          total: downloadCandidates.length,
          currentIp: target.ip,
          statusText: '正在下载测速 [${target.ip}] (${i + 1}/${downloadCandidates.length}) ...',
        ));

        final speed = await _measureDownloadSpeed(
          ip: target.ip,
          durationMs: config.downloadDurationMs,
        );

        target.downloadSpeedMBs = speed;
        target.downloadTested = true;
      }

      // 阶段二最终排序：优先下载速度高，其次丢包低、延时低
      pingResults.sort((a, b) {
        if (!a.isAvailable && !b.isAvailable) return 0;
        if (!a.isAvailable) return 1;
        if (!b.isAvailable) return -1;

        if (a.downloadTested && b.downloadTested) {
          final speedCmp = b.downloadSpeedMBs.compareTo(a.downloadSpeedMBs);
          if (speedCmp != 0) return speedCmp;
        } else if (a.downloadTested && !b.downloadTested) {
          return -1;
        } else if (!a.downloadTested && b.downloadTested) {
          return 1;
        }

        final lossCmp = a.packetLoss.compareTo(b.packetLoss);
        if (lossCmp != 0) return lossCmp;
        return a.avgLatency.compareTo(b.avgLatency);
      });
    }

    return pingResults;
  }

  /// 单 IP 多次 TCP Ping 测算丢包率与延迟 (完全复刻 CFSTAPP TcpPingTest.kt)
  Future<CfstResult> _singleIpTcpPing({
    required String ip,
    required int port,
    required int count,
    required int timeoutMs,
  }) async {
    final latencies = <int>[];

    for (int i = 0; i < count; i++) {
      if (_isCancelled) break;
      final t0 = DateTime.now().millisecondsSinceEpoch;
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: Duration(milliseconds: timeoutMs),
        );
        final elapsed = DateTime.now().millisecondsSinceEpoch - t0;
        socket.destroy();
        latencies.add(elapsed);
      } catch (_) {
        // 失败丢包
      }
    }

    final received = latencies.length;
    final packetLoss = count > 0 ? ((count - received) / count) * 100.0 : 0.0;
    final avgLatency = received > 0 ? (latencies.reduce((a, b) => a + b) ~/ received) : 9999;
    final minLatency = latencies.isNotEmpty ? latencies.reduce(min) : 9999;
    final maxLatency = latencies.isNotEmpty ? latencies.reduce(max) : 9999;

    return CfstResult(
      ip: ip,
      sent: count,
      received: received,
      packetLoss: packetLoss,
      avgLatency: avgLatency,
      minLatency: minLatency,
      maxLatency: maxLatency,
    );
  }

  /// 官方真实下载测速 (完全复刻 CFSTAPP DownloadTest.kt)
  /// 使用 HTTP 80 端口避免 HTTPS SNI 阻断，请求 speed.cloudflare.com/__down
  Future<double> _measureDownloadSpeed({
    required String ip,
    required int durationMs,
  }) async {
    int totalBytesRead = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final deadline = startTime + durationMs;

    try {
      final socket = await Socket.connect(
        ip,
        80,
        timeout: const Duration(seconds: 4),
      );

      // 构造 HTTP/1.1 请求
      final httpRequest =
          'GET /__down?bytes=50000000 HTTP/1.1\r\n'
          'Host: speed.cloudflare.com\r\n'
          'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) CFST-Pure/1.0\r\n'
          'Accept: */*\r\n'
          'Connection: close\r\n\r\n';

      socket.add(utf8.encode(httpRequest));
      await socket.flush();

      // 持续读取直到时间到达或连接关闭
      await for (final chunk in socket) {
        totalBytesRead += chunk.length;
        if (DateTime.now().millisecondsSinceEpoch >= deadline || _isCancelled) {
          break;
        }
      }

      socket.destroy();
    } catch (_) {
      // 网络抖动或超时仍计入已下载数据
    }

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startTime;
    if (elapsedMs > 0 && totalBytesRead > 0) {
      final bytesPerSec = (totalBytesRead * 1000.0) / elapsedMs;
      final speedMBs = bytesPerSec / (1024 * 1024);
      return double.parse(speedMBs.toStringAsFixed(2));
    }
    return 0.0;
  }
}
