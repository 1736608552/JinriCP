import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/settings_service.dart';
import '../services/cloudflare_opt_service.dart';
import '../services/proxy_route_service.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'cfst_speed_test_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ipsController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _dramaUrlController = TextEditingController();
  final TextEditingController _githubTokenController = TextEditingController();

  String _selectedDramaSource = SettingsService.sourceHuangguo;
  String _huangguoDramaUrl = '';
  String _hgdjuDramaUrl = '';

  bool _isLoading = true;
  bool _isCheckingUpdate = false;
  bool _optIpEnabled = true;
  ThemeMode _selectedThemeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ips = await SettingsService.getPreferredIps();
    final domains = await SettingsService.getCustomDomains();
    final dramaUrl = await SettingsService.getDramaBaseUrl();
    final themeMode = await SettingsService.getThemeMode();
    final githubToken = await UpdateService.getGithubToken();
    final optEnabled = await SettingsService.getOptIpEnabled();
    final selectedSource = SettingsService.selectedDramaSourceNotifier.value;
    final huangguoUrl = await SettingsService.getDramaUrlForSource(SettingsService.sourceHuangguo);
    final hgdjuUrl = await SettingsService.getDramaUrlForSource(SettingsService.sourceHgdju);

    if (mounted) {
      setState(() {
        _ipsController.text = ips.join('\n');
        _domainController.text = domains.join('\n');
        _dramaUrlController.text = dramaUrl;
        _githubTokenController.text = githubToken;
        _selectedThemeMode = themeMode;
        _optIpEnabled = optEnabled;
        _selectedDramaSource = selectedSource;
        _huangguoDramaUrl = huangguoUrl;
        _hgdjuDramaUrl = hgdjuUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkUpdateManually() async {
    setState(() => _isCheckingUpdate = true);
    final installedBuild = await UpdateService.getInstalledBuildNumber();
    final info = await UpdateService.checkUpdate(force: true);
    if (mounted) {
      setState(() => _isCheckingUpdate = false);
      if (info != null) {
        if (info.hasNewVersion) {
          UpdateDialog.show(context, info);
        } else {
          // 当前已是最新版本，提供重新下载覆盖安装选项
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('🎉 当前已是最新版本'),
              content: Text('您已安装最新构建版本 (Build $installedBuild)。\n如遇到异常需要重新下载并覆盖安装，可点击下方按钮重新获取安装包。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('知道了'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2B54)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    UpdateDialog.show(context, info);
                  },
                  child: const Text('重新下载安装', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ 暂未获取到 Release 资产，请检查网络或 GitHub Token 配置'),
            backgroundColor: Color(0xFFFF9800),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final rawIps = _ipsController.text
        .split(RegExp(r'[\n,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final rawDomains = _domainController.text
        .split(RegExp(r'[\n,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    await SettingsService.setPreferredIps(rawIps.isNotEmpty ? rawIps : SettingsService.defaultIps);
    await SettingsService.setOptIpEnabled(_optIpEnabled);
    await SettingsService.setCustomDomains(rawDomains.isNotEmpty ? rawDomains : SettingsService.defaultDomains);
    await ProxyRouteService.syncCustomDomainConfig();
    await SettingsService.setDramaBaseUrl(_dramaUrlController.text.trim());
    await SettingsService.setThemeMode(_selectedThemeMode);
    await UpdateService.setGithubToken(_githubTokenController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 配置已保存成功！主题与网络参数已立即生效。'),
          backgroundColor: Color(0xFF00C853),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onSelectSource(String sourceKey, String sourceTitle) async {
    final savedUrl = sourceKey == SettingsService.sourceHgdju ? _hgdjuDramaUrl : _huangguoDramaUrl;
    if (savedUrl.isEmpty) {
      // 首次未配置：弹出手动输入地址对话框
      await _showEditDramaUrlDialog(sourceKey: sourceKey, sourceTitle: sourceTitle);
    } else {
      // 已配置：直接切换
      await SettingsService.switchDramaSource(sourceKey);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ 已快速切换至【$sourceTitle】！'),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _showEditDramaUrlDialog({
    required String sourceKey,
    required String sourceTitle,
  }) async {
    final currentUrl = sourceKey == SettingsService.sourceHgdju ? _hgdjuDramaUrl : _huangguoDramaUrl;
    final editController = TextEditingController(text: currentUrl);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('配置【$sourceTitle】源站地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请输入 $sourceTitle 完整主站地址，保存后系统将持久化记忆。下一次打开直接点击即可秒级切换。',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editController,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: sourceKey == SettingsService.sourceHgdju
                    ? '例如: https://hgdju1.com/browse'
                    : '例如: https://huangguoai.com',
                hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
                filled: true,
                fillColor: AppTheme.inputBg(context),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => editController.clear(),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          if (currentUrl.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await SettingsService.saveDramaUrlForSource(sourceKey, '');
                await _loadSettings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已清空【$sourceTitle】地址记忆'),
                      backgroundColor: Colors.grey.shade700,
                    ),
                  );
                }
              },
              child: const Text('清空记忆', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2B54)),
            onPressed: () async {
              final newUrl = editController.text.trim();
              Navigator.of(ctx).pop();
              await SettingsService.saveDramaUrlForSource(sourceKey, newUrl);
              await SettingsService.switchDramaSource(sourceKey);
              await _loadSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ 已保存并记忆【$sourceTitle】地址，并已切换生效！'),
                    backgroundColor: const Color(0xFF00C853),
                  ),
                );
              }
            },
            child: const Text('保存并记忆', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDramaSourceCard({
    required String sourceKey,
    required String title,
    required String icon,
    required String currentUrl,
    required bool isSelected,
    required BuildContext context,
  }) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isSelected ? const Color(0xFFFF2B54) : (isDark ? Colors.white12 : Colors.black12);
    final cardBg = isSelected
        ? (isDark ? const Color(0xFF251822) : const Color(0xFFFFF0F3))
        : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02));

    return InkWell(
      onTap: () => _onSelectSource(sourceKey, title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1.0),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? const Color(0xFFFF2B54) : AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF2B54).withOpacity(0.15)
                              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSelected ? '当前使用中' : '点击切换',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? const Color(0xFFFF2B54) : AppTheme.textMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUrl.isNotEmpty ? '已记忆: $currentUrl' : '⚠️ 未配置地址（点击手动输入）',
                    style: TextStyle(
                      fontSize: 11,
                      color: currentUrl.isNotEmpty ? const Color(0xFF00C853) : AppTheme.textMuted(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_note_rounded, size: 24, color: isSelected ? const Color(0xFFFF2B54) : AppTheme.textMuted(context)),
              tooltip: '修改地址',
              onPressed: () => _showEditDramaUrlDialog(sourceKey: sourceKey, sourceTitle: title),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardColor = AppTheme.cardBg(context);
    final inputFillColor = AppTheme.inputBg(context);
    final borderColor = AppTheme.borderColor(context);
    final primaryTextColor = AppTheme.textPrimary(context);
    final secondaryTextColor = AppTheme.textSecondary(context);
    final mutedTextColor = AppTheme.textMuted(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          '软件设置与管理',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '保存设置',
            icon: const Icon(Icons.check_rounded, color: Color(0xFFFF2B54)),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFFFF2E63), size: 40))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 96.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 软件版本与在线更新（自动适配 GitHub 个人仓库发布）
                  _buildSectionHeader(
                    '🚀 软件版本与在线更新',
                    '支持 GitHub 个人仓库 Release 自动静默检测、一键高速下载并安装',
                    primaryTextColor,
                    mutedTextColor,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF2B54), Color(0xFFFF5277)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '当前版本: v${UpdateService.currentVersionName}',
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Build ${UpdateService.currentBuildNumber} · 零广告原生版',
                                    style: TextStyle(
                                      color: mutedTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF2B54),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isCheckingUpdate ? null : _checkUpdateManually,
                              icon: _isCheckingUpdate
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 16),
                              label: Text(_isCheckingUpdate ? '检查中' : '检查更新'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 0. 🎨 外观主题设置（白天白色模式 / 夜晚深色模式 / 跟随系统）
                  _buildSectionHeader(
                    '🎨 外观与主题模式',
                    '支持白天清新白色模式与夜间深邃暗黑模式，默认白色',
                    primaryTextColor,
                    mutedTextColor,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildThemeOption(
                              mode: ThemeMode.light,
                              title: '白天模式',
                              subtitle: '默认纯白清爽',
                              icon: Icons.wb_sunny_rounded,
                              activeColor: const Color(0xFFFF9800),
                            ),
                            const SizedBox(width: 12),
                            _buildThemeOption(
                              mode: ThemeMode.dark,
                              title: '夜晚模式',
                              subtitle: '沉浸护眼深色',
                              icon: Icons.nightlight_round,
                              activeColor: const Color(0xFF7C4DFF),
                            ),
                            const SizedBox(width: 12),
                            _buildThemeOption(
                              mode: ThemeMode.system,
                              title: '跟随系统',
                              subtitle: '自适应切换',
                              icon: Icons.brightness_auto_rounded,
                              activeColor: const Color(0xFF00B0FF),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 1. 🎬 短剧双源独立记忆与切换配置
                  _buildSectionHeader(
                    '🎬 短剧双源独立记忆与切换',
                    '支持黄果短剧与黄瓜短剧双源独立保存记忆。点击即刻切换；首次点击需手动输入地址，下次打开直接切换，点击修改图标可更新地址。',
                    primaryTextColor,
                    mutedTextColor,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 源1：黄果短剧卡片
                        _buildDramaSourceCard(
                          sourceKey: SettingsService.sourceHuangguo,
                          title: '黄果短剧',
                          icon: '🍋',
                          currentUrl: _huangguoDramaUrl,
                          isSelected: _selectedDramaSource == SettingsService.sourceHuangguo,
                          context: context,
                        ),
                        const SizedBox(height: 10),
                        // 源2：黄瓜短剧卡片
                        _buildDramaSourceCard(
                          sourceKey: SettingsService.sourceHgdju,
                          title: '黄瓜短剧',
                          icon: '🥒',
                          currentUrl: _hgdjuDramaUrl,
                          isSelected: _selectedDramaSource == SettingsService.sourceHgdju,
                          context: context,
                        ),
                        const SizedBox(height: 14),
                        // 当前全局生效状态指示
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _dramaUrlController.text.trim().isNotEmpty
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                color: _dramaUrlController.text.trim().isNotEmpty
                                    ? const Color(0xFF00C853)
                                    : mutedTextColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dramaUrlController.text.trim().isNotEmpty
                                      ? '当前生效: ${_selectedDramaSource == SettingsService.sourceHgdju ? "黄瓜短剧" : "黄果短剧"} (${_dramaUrlController.text.trim()})'
                                      : '当前短剧源地址为空，短剧栏目已自动隐藏',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _dramaUrlController.text.trim().isNotEmpty
                                        ? primaryTextColor
                                        : mutedTextColor,
                                    fontWeight: _dramaUrlController.text.trim().isNotEmpty
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _dramaUrlController.text.trim().isNotEmpty
                                      ? const Color(0xFF00C853).withOpacity(0.15)
                                      : (isDark ? Colors.white10 : Colors.black12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _dramaUrlController.text.trim().isNotEmpty ? '已激活' : '已隐藏',
                                  style: TextStyle(
                                    color: _dramaUrlController.text.trim().isNotEmpty
                                        ? const Color(0xFF00C853)
                                        : mutedTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. 🚀 Cloudflare 优选 IP 管理模块
                  _buildSectionHeader(
                    '🚀 Cloudflare 优选 IP 加速池',
                    '直连低延迟 Anycast 优质机房，消除跨国网络抖动',
                    primaryTextColor,
                    mutedTextColor,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 优选 IP 启用开关行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '启用 Cloudflare 优选 IP 加速',
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _optIpEnabled
                                        ? '已开启 (流量自动直达最低延迟 Anycast 边缘机房)'
                                        : '已关闭 (直连系统默认 DNS 解析)',
                                    style: TextStyle(
                                      color: _optIpEnabled ? const Color(0xFF00C853) : mutedTextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _optIpEnabled,
                              activeColor: const Color(0xFFFF2E63),
                              onChanged: (val) {
                                setState(() => _optIpEnabled = val);
                                SettingsService.setOptIpEnabled(val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Text('优选 IP 列表 (支持批量粘贴):',
                                style: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                              onPressed: !_optIpEnabled
                                  ? null
                                  : () {
                                      setState(() {
                                        _ipsController.text = SettingsService.defaultIps.join('\n');
                                      });
                                    },
                              child: const Text('恢复默认15个', style: TextStyle(color: Color(0xFFFF2E63), fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ipsController,
                          enabled: _optIpEnabled,
                          maxLines: 5,
                          style: TextStyle(
                            color: _optIpEnabled ? primaryTextColor : mutedTextColor,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: '104.25.159.15\n104.21.245.19\n...',
                            hintStyle: TextStyle(color: mutedTextColor, fontSize: 12),
                            filled: true,
                            fillColor: inputFillColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 🎯 CFSTAPP 极速优选测速中心独立入口
                        InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CfstSpeedTestScreen(),
                              ),
                            );
                            final updatedIps = await SettingsService.getPreferredIps();
                            final updatedEnabled = await SettingsService.getOptIpEnabled();
                            if (mounted) {
                              setState(() {
                                _ipsController.text = updatedIps.join('\n');
                                _optIpEnabled = updatedEnabled;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.speed_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🎯 打开 CFST 极速优选测速中心',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '移植自 Hsia97/CFSTAPP · 官方 IP 采样/丢包筛查/真实下载测速',
                                        style: TextStyle(color: Colors.white70, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '💡 提示：开启后应用流量将自动通过上述 Cloudflare 优质 Anycast 节点进行中继加速。点击上方【CFST 测速中心】可一键智能测速与最优回填！',
                          style: TextStyle(color: mutedTextColor, fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. 🌐 专属 Anycast 节点域名配置 (支持多节点写入)
                  _buildSectionHeader(
                    '🌐 专属 Anycast 直播节点域名',
                    '每行输入一个域名，支持添加多个专属节点并自动测速优选',
                    primaryTextColor,
                    mutedTextColor,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('专属节点列表 (支持写入多个):',
                                style: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('每行一个域名',
                                style: TextStyle(color: mutedTextColor, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _domainController,
                          maxLines: 4,
                          minLines: 2,
                          style: TextStyle(color: primaryTextColor, fontSize: 12, height: 1.4),
                          decoration: InputDecoration(
                            hintText: "https://zb.djseven.cc.cd\nhttps://zb.djseven.us.ci\n每行一个域名，支持自由增删",
                            hintStyle: TextStyle(color: mutedTextColor, fontSize: 12),
                            filled: true,
                            fillColor: inputFillColor,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '💡 提示：在此处填写的每个域名都会自动生成专属加速线路，并在播放时并发真实测速，自动优选最快节点！',
                          style: TextStyle(color: mutedTextColor, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 底部一键保存按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2E63),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text('保存所有设置',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildThemeOption({
    required ThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedThemeMode == mode;
    final isDark = AppTheme.isDark(context);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedThemeMode = mode;
          });
          SettingsService.setThemeMode(mode);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(0.12)
                : (isDark ? const Color(0xFF10121D) : const Color(0xFFF2F4F7)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.black12),
              width: isSelected ? 1.6 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? activeColor : AppTheme.textMuted(context), size: 24),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? activeColor : AppTheme.textPrimary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? activeColor.withOpacity(0.8) : AppTheme.textMuted(context),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color titleColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 11)),
      ],
    );
  }
}
