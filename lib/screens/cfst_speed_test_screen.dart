import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cfst_engine_service.dart';
import '../services/settings_service.dart';
import '../services/proxy_route_service.dart';

class CfstSpeedTestScreen extends StatefulWidget {
  const CfstSpeedTestScreen({super.key});

  @override
  State<CfstSpeedTestScreen> createState() => _CfstSpeedTestScreenState();
}

class _CfstSpeedTestScreenState extends State<CfstSpeedTestScreen> {
  final CfstEngine _engine = CfstEngine();

  // 配置项
  bool _enableDownload = true;
  int _testCount = 50;
  int _pingCount = 3;
  int _port = 443;

  // 运行状态
  bool _isRunning = false;
  CfstProgress? _progress;
  List<CfstResult> _results = [];
  String _statusText = '准备就绪，点击下方按钮开始测速';

  @override
  void dispose() {
    _engine.cancel();
    super.dispose();
  }

  void _startSpeedTest() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _results = [];
      _statusText = '正在从 Cloudflare 官方网段中智能采样候选 IP...';
    });

    final currentIps = await SettingsService.getPreferredIps();

    final config = CfstConfig(
      testCount: _testCount,
      pingCount: _pingCount,
      port: _port,
      enableDownloadTest: _enableDownload,
      downloadTopCount: 20,
      downloadDurationMs: 3500,
      maxConcurrentPings: 8,
    );

    try {
      final res = await _engine.runSpeedTest(
        config: config,
        extraIps: currentIps,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _progress = p;
              _statusText = p.statusText;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _results = res;
          _isRunning = false;
          _statusText = '🎉 测速完成！共评测 ${res.length} 个节点，可用 ${res.where((e) => e.isAvailable).length} 个。';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _statusText = '测速异常中断: $e';
        });
      }
    }
  }

  void _stopSpeedTest() {
    _engine.cancel();
    setState(() {
      _isRunning = false;
      _statusText = '已手动停止测速';
    });
  }

  /// 一键应用到优选 IP 里面（支持测速结果与内置推荐节点）
  Future<void> _applyToPreferredIps() async {
    final available = _results.where((r) => r.isAvailable).map((r) => r.ip).toList();

    List<String> targetIps;
    String tipMsg;

    if (available.isNotEmpty) {
      targetIps = available.take(20).toList();
      tipMsg = '🎉 成功将测速最快的 ${targetIps.length} 个 Anycast 节点应用为优选 IP，已自动开启加速！';
    } else {
      // 未测速时，直接提取内置精选种子库前 20 个
      targetIps = CfstIpParser.highQualitySeeds.take(20).toList();
      tipMsg = '🎉 成功将系统精选的 ${targetIps.length} 个优质 Anycast 节点应用为优选 IP，已自动开启加速！';
    }

    await SettingsService.setPreferredIps(targetIps);
    await SettingsService.setOptIpEnabled(true);
    await ProxyRouteService.syncCustomDomainConfig();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tipMsg),
          backgroundColor: const Color(0xFF00C853),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 将单个 IP 应用为当前首选优选 IP
  Future<void> _applySingleIp(String ip) async {
    final current = await SettingsService.getPreferredIps();
    final updated = [ip, ...current.where((e) => e != ip)].take(20).toList();
    await SettingsService.setPreferredIps(updated);
    await SettingsService.setOptIpEnabled(true);
    await ProxyRouteService.syncCustomDomainConfig();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 已将 [$ip] 置顶为第一首选优选 IP 并生效！'),
          backgroundColor: const Color(0xFF00C853),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyAllAvailableIps() {
    final available = _results.where((r) => r.isAvailable).map((r) => r.ip).toList();
    final toCopy = available.isNotEmpty ? available : CfstIpParser.highQualitySeeds.take(20).toList();
    Clipboard.setData(ClipboardData(text: toCopy.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${toCopy.length} 个 IP 到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final availableResults = _results.where((r) => r.isAvailable).toList();

    int? bestLatency = availableResults.isNotEmpty
        ? availableResults.map((r) => r.avgLatency).reduce((a, b) => a < b ? a : b)
        : null;

    double? maxSpeed = availableResults.any((r) => r.downloadTested)
        ? availableResults.map((r) => r.downloadSpeedMBs).reduce((a, b) => a > b ? a : b)
        : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CFST 极速优选测速中心', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('XIU2 / CloudflareSpeedTest 移动端移植版', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '使用说明',
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部配置面板
          _buildConfigCard(context, primaryColor, isDark),

          // 测速进度看板
          if (_isRunning && _progress != null)
            _buildProgressCard(context, primaryColor, isDark),

          // 核心数据概览小卡片
          if (_results.isNotEmpty)
            _buildStatsOverview(context, availableResults.length, bestLatency, maxSpeed, isDark),

          // 结果数据列表
          Expanded(
            child: _results.isEmpty
                ? _buildEmptyPlaceholder(isDark)
                : _buildResultListView(context, isDark),
          ),

          // 底部操作栏
          _buildBottomBar(context, primaryColor, isDark, availableResults.length),
        ],
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context, Color primaryColor, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.08);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部标题与协议标签
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '测速模式与参数配置',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '官方 speed.cloudflare',
                  style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 模式分段选择器 (彻底解决手机端 ChoiceChip 溢出文字截断错位问题)
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _isRunning ? null : () => setState(() => _enableDownload = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _enableDownload ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _enableDownload
                            ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              size: 15,
                              color: _enableDownload ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '深度综合 (Ping+下载)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _enableDownload ? FontWeight.bold : FontWeight.normal,
                                color: _enableDownload ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: _isRunning ? null : () => setState(() => _enableDownload = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_enableDownload ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_enableDownload
                            ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.network_ping_rounded,
                              size: 15,
                              color: !_enableDownload ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '快速极速 (仅测延迟)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !_enableDownload ? FontWeight.bold : FontWeight.normal,
                                color: !_enableDownload ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 参数配置第一行：采样数量
          Row(
            children: [
              const SizedBox(
                width: 65,
                child: Text('采样数量:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Row(
                  children: [
                    _buildPillChip('20 个', _testCount == 20, () => setState(() => _testCount = 20)),
                    const SizedBox(width: 6),
                    _buildPillChip('50 个 (推荐)', _testCount == 50, () => setState(() => _testCount = 50)),
                    const SizedBox(width: 6),
                    _buildPillChip('100 个', _testCount == 100, () => setState(() => _testCount = 100)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 参数配置第二行：测试端口
          Row(
            children: [
              const SizedBox(
                width: 65,
                child: Text('测速端口:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Row(
                  children: [
                    _buildPillChip('443 (HTTPS 推荐)', _port == 443, () => setState(() => _port = 443)),
                    const SizedBox(width: 8),
                    _buildPillChip('80 (HTTP)', _port == 80, () => setState(() => _port = 80)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 主测速控制按钮
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? Colors.redAccent : const Color(0xFFFF2E63),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isRunning ? _stopSpeedTest : _startSpeedTest,
              icon: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
              label: Text(
                _isRunning ? '停止测速' : '🚀 开始执行 Cloudflare 智能优选测速',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: _isRunning ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C853).withOpacity(0.15) : Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? const Color(0xFF00C853) : null,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, Color primaryColor, bool isDark) {
    final p = _progress!;
    final phaseTitle = p.phase == 1 ? '阶段 1/2: TCP 丢包率与握手延迟初筛' : '阶段 2/2: 官方 HTTP 真实吞吐测速';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
              ),
              const SizedBox(width: 8),
              Text(phaseTitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
              const Spacer(),
              Text('${p.current} / ${p.total}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p.percent,
              minHeight: 6,
              backgroundColor: primaryColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(p.statusText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context, int availableCount, int? bestLatency, double? maxSpeed, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('可用节点', '$availableCount / ${_results.length}', Colors.blueAccent),
          _buildStatItem('最佳延迟', bestLatency != null ? '$bestLatency ms' : '--', const Color(0xFF00C853)),
          _buildStatItem('最高下行', maxSpeed != null ? '${maxSpeed.toStringAsFixed(2)} MB/s' : '--', Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildEmptyPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.network_check_rounded, size: 64, color: Colors.grey.withOpacity(0.35)),
          const SizedBox(height: 12),
          const Text('暂无测速数据', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '点击上方按钮开始测速；您也可以直接点击底部【一键应用】，系统将自动把内置 20 个精选 Anycast 节点注入优选 IP 库！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultListView(BuildContext context, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        final rank = index + 1;

        Color rankColor = Colors.grey;
        if (rank == 1) rankColor = const Color(0xFFFFD700);
        else if (rank == 2) rankColor = const Color(0xFFC0C0C0);
        else if (rank == 3) rankColor = const Color(0xFFCD7F32);

        Color latencyColor = Colors.redAccent;
        if (item.avgLatency < 180) latencyColor = const Color(0xFF00C853);
        else if (item.avgLatency < 300) latencyColor = Colors.orange;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Clipboard.setData(ClipboardData(text: item.ip));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已复制 IP [${item.ip}] 到剪贴板'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 排名徽章
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rankColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rankColor),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // IP 与发包情况
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.ip,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '收发: ${item.received}/${item.sent}  丢包: ${item.formattedLoss}',
                          style: TextStyle(
                            fontSize: 10,
                            color: item.packetLoss > 0 ? Colors.redAccent : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 延迟指标
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.formattedLatency,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: latencyColor),
                      ),
                      const SizedBox(height: 2),
                      const Text('TCP 握手', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // 下载速度指标
                  Container(
                    width: 68,
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.formattedSpeed,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.downloadSpeedMBs > 0 ? const Color(0xFF00C853) : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('实际下行', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),
                  // 单节点置顶为首选快捷微按钮
                  InkWell(
                    onTap: () => _applySingleIp(item.ip),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.check, size: 14, color: Color(0xFF00C853)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, Color primaryColor, bool isDark, int availableCount) {
    final hasResults = availableCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              ),
              onPressed: _copyAllAvailableIps,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('导出全部', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),

            // 🎯 核心大按钮：随时高亮可用的一键应用到优选 IP！
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _applyToPreferredIps,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  hasResults
                      ? '⭐ 一键应用测速最快 20 个 IP 到优选'
                      : '⭐ 一键应用精选 20 个 IP 到优选 IP',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flash_on_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('CFST 测速体系原理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本项目测速体系完全基于 Hsia97/CFSTAPP 与 XIU2/CloudflareSpeedTest 原生移植开发：',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. 官方 IP 范围抽样：涵盖 Cloudflare 官方 IPv4 CIDR 网段，并混合全国骨干网访问优异的 70+ 个 Anycast 种子。\n'
                '2. TCP 握手延时筛查：多线程探测 443/80 端口，精准测算平均握手耗时与丢包率。\n'
                '3. 官方真实下载测速：通过 speed.cloudflare.com/__down 接口实测真实下行吞吐量，以 HTTP 单连接规避 SNI 阻断，数据精准可靠。\n'
                '4. 一键应用生效：无论是否完成测速，点击底部【一键应用】按钮均可立即将前 20 个最优 IP 注入到优选列表中，并自动开启优选 IP 加速！',
                style: TextStyle(fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}
