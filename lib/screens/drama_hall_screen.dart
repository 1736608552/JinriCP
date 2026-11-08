import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/short_drama.dart';
import '../models/drama_history.dart';
import '../services/drama_service.dart';
import '../services/settings_service.dart';
import '../services/image_loader_service.dart';
import '../services/drama_history_service.dart';
import '../services/theme_service.dart';
import 'drama_player_screen.dart';
import 'gossip_detail_screen.dart';

class DramaHallScreen extends StatefulWidget {
  const DramaHallScreen({super.key});

  @override
  State<DramaHallScreen> createState() => _DramaHallScreenState();
}

class _DramaHallScreenState extends State<DramaHallScreen> {
  late String _selectedCategory;
  late String _selectedSubTab;
  // 黄瓜短剧官方专属四维分类筛选状态（1:1 对齐官方截图）
  String _hgdjuSelectedLine = '全部';
  String _hgdjuSelectedTag = '全部';
  String _hgdjuSelectedStatus = '全部';
  String _hgdjuSelectedSort = '最热';
  bool _hgdjuTagsExpanded = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ShortDrama> _dramas = [];
  List<DramaHistoryItem> _historyList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _initCategoryAndSubTab();
    _scrollController.addListener(_onScroll);
    SettingsService.dramaSourceTypeNotifier.addListener(_onSourceTypeChanged);
    SettingsService.dramaBaseUrlNotifier.addListener(_onSourceTypeChanged);
    _loadHistory();
    _loadDramas();
    _checkUpdates();
  }

  void _initCategoryAndSubTab() {
    final isHgdju = SettingsService.dramaSourceTypeNotifier.value == SettingsService.dramaSourceHgdju;
    if (isHgdju) {
      _selectedCategory = '全部';
      _selectedSubTab = '最热';
      _hgdjuSelectedLine = '全部';
      _hgdjuSelectedTag = '全部';
      _hgdjuSelectedStatus = '全部';
      _hgdjuSelectedSort = '最热';
    } else {
      final cats = DramaService.getCurrentCategories();
      _selectedCategory = cats.length > 1 ? cats[1] : (cats.isNotEmpty ? cats[0] : '🎬 AI成人短剧');
      final subs = DramaService.getCurrentSubTabs(_selectedCategory);
      _selectedSubTab = subs.isNotEmpty ? subs.first : '最新更新';
    }
  }

  void _onSourceTypeChanged() {
    if (!mounted) return;
    _initCategoryAndSubTab();
    _loadDramas();
  }

  @override
  void dispose() {
    SettingsService.dramaSourceTypeNotifier.removeListener(_onSourceTypeChanged);
    SettingsService.dramaBaseUrlNotifier.removeListener(_onSourceTypeChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showSourceSwitchDialog() async {
    final huangguoUrl = await SettingsService.getDramaUrlForSource(SettingsService.sourceHuangguo);
    final hgdjuUrl = await SettingsService.getDramaUrlForSource(SettingsService.sourceHgdju);
    final currentSource = SettingsService.selectedDramaSourceNotifier.value;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎬 切换短剧源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '短剧双源独立记忆。点击即切换；未配置则手动输入并记忆。',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
              ),
              const SizedBox(height: 14),
              // 选项1：黄果短剧
              _buildSourceTile(
                ctx: ctx,
                sourceKey: SettingsService.sourceHuangguo,
                title: '黄果短剧',
                icon: '🍋',
                savedUrl: huangguoUrl,
                isSelected: currentSource == SettingsService.sourceHuangguo,
              ),
              const SizedBox(height: 10),
              // 选项2：黄瓜短剧
              _buildSourceTile(
                ctx: ctx,
                sourceKey: SettingsService.sourceHgdju,
                title: '黄瓜短剧',
                icon: '🥒',
                savedUrl: hgdjuUrl,
                isSelected: currentSource == SettingsService.sourceHgdju,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required BuildContext ctx,
    required String sourceKey,
    required String title,
    required String icon,
    required String savedUrl,
    required bool isSelected,
  }) {
    final isDark = AppTheme.isDark(context);
    return InkWell(
      onTap: () async {
        Navigator.of(ctx).pop();
        if (savedUrl.isEmpty) {
          _showEditDramaUrlDialog(sourceKey: sourceKey, sourceTitle: title);
        } else {
          await SettingsService.switchDramaSource(sourceKey);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚡ 已快速切换至【$title】！'),
                backgroundColor: const Color(0xFF00C853),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF251822) : const Color(0xFFFFF0F3))
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF2B54) : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
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
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2B54).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('使用中', style: TextStyle(fontSize: 9.5, color: Color(0xFFFF2B54), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    savedUrl.isNotEmpty ? '已记忆: $savedUrl' : '⚠️ 未配置地址（点击手动输入）',
                    style: TextStyle(
                      fontSize: 11,
                      color: savedUrl.isNotEmpty ? const Color(0xFF00C853) : AppTheme.textMuted(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_note_rounded, size: 22, color: isSelected ? const Color(0xFFFF2B54) : AppTheme.textMuted(context)),
              tooltip: '修改地址',
              onPressed: () {
                Navigator.of(ctx).pop();
                _showEditDramaUrlDialog(sourceKey: sourceKey, sourceTitle: title);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDramaUrlDialog({
    required String sourceKey,
    required String sourceTitle,
  }) async {
    final currentUrl = await SettingsService.getDramaUrlForSource(sourceKey);
    final editController = TextEditingController(text: currentUrl);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('配置【$sourceTitle】源站地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请输入 $sourceTitle 完整主站地址，保存后系统将持久化记忆。下一次打开直接切换即可。',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editController,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: sourceKey == SettingsService.sourceHgdju
                    ? '例如: https://xyz.zgoqmlyp.cc/browse'
                    : '例如: https://huangguoai.ai',
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
              DramaService.clearWorkingDomainCache();
              await SettingsService.saveDramaUrlForSource(sourceKey, newUrl);
              await SettingsService.switchDramaSource(sourceKey);
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

  Future<void> _loadHistory() async {
    final list = await DramaHistoryService.getHistoryList();
    if (mounted) {
      setState(() {
        _historyList = list;
      });
    }
  }

  Future<void> _checkUpdates() async {
    try {
      final newlyUpdated = await DramaHistoryService.checkForUpdates();
      if (!mounted) return;
      await _loadHistory();
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMoreDramas();
    }
  }

  Future<void> _loadDramas() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final isHgdju = SettingsService.dramaSourceTypeNotifier.value == SettingsService.dramaSourceHgdju;
    final results = await DramaService.fetchDramas(
      category: _selectedCategory,
      subTab: _selectedSubTab,
      keyword: _searchController.text,
      page: 1,
      hgdjuLine: isHgdju ? _hgdjuSelectedLine : null,
      hgdjuTag: isHgdju ? _hgdjuSelectedTag : null,
      hgdjuStatus: isHgdju ? _hgdjuSelectedStatus : null,
      hgdjuSort: isHgdju ? _hgdjuSelectedSort : null,
    );
    if (mounted) {
      setState(() {
        _dramas = results;
        _isLoading = false;
        if (results.isEmpty) {
          _hasMore = false;
        }
      });
    }
  }

  Future<void> _loadMoreDramas() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final isHgdju = SettingsService.dramaSourceTypeNotifier.value == SettingsService.dramaSourceHgdju;
    final results = await DramaService.fetchDramas(
      category: _selectedCategory,
      subTab: _selectedSubTab,
      keyword: _searchController.text,
      page: nextPage,
      hgdjuLine: isHgdju ? _hgdjuSelectedLine : null,
      hgdjuTag: isHgdju ? _hgdjuSelectedTag : null,
      hgdjuStatus: isHgdju ? _hgdjuSelectedStatus : null,
      hgdjuSort: isHgdju ? _hgdjuSelectedSort : null,
    );

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        if (results.isEmpty) {
          _hasMore = false;
        } else {
          _currentPage = nextPage;
          final existingIds = _dramas.map((d) => d.id).toSet();
          final existingTitles = _dramas.map((d) => d.title.trim().toLowerCase()).toSet();
          final newItems = results
              .where((d) => !existingIds.contains(d.id) && !existingTitles.contains(d.title.trim().toLowerCase()))
              .toList();
          if (newItems.isEmpty) {
            // 如果拉取到了非空结果，但全部与已有内容重复：
            // 在首页若尚未达到 25 页，或吃瓜板块若尚未达到 29 页，不轻易终止翻页，允许继续向后探测
            if ((!_selectedCategory.contains('吃瓜') && !_selectedCategory.contains('首页')) || _currentPage >= 29) {
              _hasMore = false;
            }
          } else {
            _dramas.addAll(newItems);
          }
        }
      });
    }
  }

  String _formatTimeAgo(int timestampMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - timestampMs;
    final diffMin = (diffMs / 60000).round();
    if (diffMin < 1) return '刚刚';
    if (diffMin < 60) return '$diffMin 分钟前';
    final diffHour = (diffMin / 60).round();
    if (diffHour < 24) return '$diffHour 小时前';
    final diffDay = (diffHour / 24).round();
    if (diffDay < 7) return '$diffDay 天前';
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${date.month}-${date.day}';
  }

  void _showHistoryBottomSheet() {
    final isDark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.history_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '追剧记录与更新 (${_historyList.length})',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (_historyList.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: AppTheme.cardBg(context),
                                title: const Text('清空历史'),
                                content: const Text('确定要清空所有追剧进度与历史吗？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('取消')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPink),
                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                    child: const Text('清空', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await DramaHistoryService.clearAllHistory();
                              await _loadHistory();
                              setModalState(() {});
                              if (mounted) setState(() {});
                            }
                          },
                          child: const Text('清空全部', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _historyList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_empty_rounded, size: 48, color: AppTheme.textMuted(context)),
                                const SizedBox(height: 10),
                                Text('暂无短剧观看记录', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _historyList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _historyList[index];
                              final drama = item.toShortDrama();
                              final hasNew = item.hasNewEpisodes;

                              return InkWell(
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DramaPlayerScreen(
                                        drama: drama,
                                        initialEpisodeIndex: item.lastEpisodeIndex,
                                      ),
                                    ),
                                  );
                                  _loadHistory();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF161928) : const Color(0xFFF6F8FB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: hasNew ? AppTheme.primaryPink.withOpacity(0.5) : AppTheme.borderColor(context),
                                      width: hasNew ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 72,
                                          height: 96,
                                          child: DramaPosterWidget(drama: drama),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppTheme.textPrimary(context),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            if (hasNew)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                margin: const EdgeInsets.only(bottom: 6),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryPink.withOpacity(0.18),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '🔥 更新了 ${item.newlyUpdatedCount} 集 (更至第 ${item.currentMaxEpisodes} 集)',
                                                  style: const TextStyle(
                                                    color: AppTheme.primaryPink,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            Row(
                                              children: [
                                                Text(
                                                  '上次观看至第 ${item.lastEpisodeNum} 集',
                                                  style: TextStyle(
                                                    color: AppTheme.textSecondary(context),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  _formatTimeAgo(item.updatedAt),
                                                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarBg(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.neonGlow(color: AppTheme.primaryPink, opacity: 0.45, blur: 10),
              ),
              child: const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI 短剧影视',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '4K HDR',
                        style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                Text(
                  '沉浸剧场 · 极速换脸全集完结',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 模式切换
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF5A6270),
              size: 20,
            ),
            tooltip: isDark ? '浅色' : '暗黑',
            onPressed: () {
              final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
              SettingsService.setThemeMode(nextMode);
            },
          ),
          // 观看历史与更新提醒
          ValueListenableBuilder<int>(
            valueListenable: DramaHistoryService.updateCountNotifier,
            builder: (context, updateCount, _) {
              final hasUpdates = updateCount > 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: hasUpdates || _historyList.isNotEmpty,
                  label: Text(
                    hasUpdates ? '$updateCount更' : '${_historyList.length}',
                    style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  backgroundColor: hasUpdates ? AppTheme.primaryPink : Colors.amber.shade800,
                  child: Icon(
                    hasUpdates ? Icons.notifications_active_rounded : Icons.history_rounded,
                    color: hasUpdates ? AppTheme.primaryPink : AppTheme.textSecondary(context),
                    size: 22,
                  ),
                ),
                tooltip: hasUpdates ? '$updateCount 部剧有新集数' : '观看历史',
                onPressed: _showHistoryBottomSheet,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. 极光搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.inputBg(context),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: AppTheme.borderColor(context), width: 0.6),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜索短剧片名、题材标签、演员...',
                  hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryPink, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppTheme.textMuted(context), size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _loadDramas();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onSubmitted: (_) => _loadDramas(),
              ),
            ),
          ),

          // 2. 动态分类筛选栏（仅黄果源在顶部展示大板块微胶囊与联动子排序；黄瓜源已移至【最近观看】下方）
          ValueListenableBuilder<String>(
            valueListenable: SettingsService.dramaSourceTypeNotifier,
            builder: (context, sourceType, _) {
              if (sourceType == SettingsService.dramaSourceHgdju) {
                // 🥒 黄瓜短剧：四维分类矩阵已移至【最近观看】下方，与片单紧凑对齐
                return const SizedBox.shrink();
              }

              // 🍋 黄果短剧：经典一级分类流光微胶囊与二级专属联动子排序
              final currentCategories = DramaService.getCurrentCategories();
              final currentSubTabs = DramaService.getCurrentSubTabs(_selectedCategory);
              final isDark = AppTheme.isDark(context);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 38,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: currentCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = currentCategories[index];
                        final isSelected = cat == _selectedCategory;
                        return InkWell(
                          onTap: () {
                            final newSubTabs = DramaService.getCurrentSubTabs(cat);
                            setState(() {
                              _selectedCategory = cat;
                              _selectedSubTab = newSubTabs.isNotEmpty ? newSubTabs.first : '';
                            });
                            _loadDramas();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppTheme.primaryGradient : null,
                              color: isSelected ? null : AppTheme.chipUnselectedBg(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : AppTheme.borderColor(context),
                                width: 0.8,
                              ),
                              boxShadow: isSelected
                                  ? AppTheme.neonGlow(color: AppTheme.primaryPink, opacity: 0.4, blur: 8)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textSecondary(context),
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (currentSubTabs.length > 1 || !_selectedCategory.contains('专题'))
                    Container(
                      height: 32,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: currentSubTabs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final tab = currentSubTabs[index];
                          final isTabSelected = tab == _selectedSubTab;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedSubTab = tab);
                              _loadDramas();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                              decoration: BoxDecoration(
                                color: isTabSelected
                                    ? (isDark ? AppTheme.primaryPink.withOpacity(0.2) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isTabSelected
                                      ? AppTheme.primaryPink.withOpacity(0.5)
                                      : Colors.transparent,
                                  width: 0.8,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  tab,
                                  style: TextStyle(
                                    color: isTabSelected ? AppTheme.primaryPink : AppTheme.textMuted(context),
                                    fontWeight: isTabSelected ? FontWeight.w800 : FontWeight.normal,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),

          // 4. 瀑布流短剧海报网格 (支持 Hero 轮播 + 续播时光轴 + 2:3 电影海报)
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryPink,
              backgroundColor: AppTheme.cardBg(context),
              onRefresh: () async {
                DramaService.clearWorkingDomainCache();
                await _loadHistory();
                await _loadDramas();
              },
              child: (_isLoading && _dramas.isEmpty)
                  ? const Center(child: SpinKitFadingCircle(color: AppTheme.primaryPink, size: 42))
                  : _dramas.isEmpty
                      ? _buildEmptyView()
                      : Stack(
                          children: [
                            CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // 🌟 顶部爆款电影大图轮播推荐位 (Hero Carousel) - 仅黄果短剧模式呈现，黄瓜分类大厅彻底隐藏杜绝视觉遮挡
                                if (_searchController.text.isEmpty && _dramas.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: SettingsService.dramaSourceTypeNotifier,
                                      builder: (context, sourceType, _) {
                                        if (sourceType != SettingsService.dramaSourceHgdju) {
                                          return _buildHeroCarousel(_dramas.take(5).toList());
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),

                                // 🌟 正在追看 · 续播时光轴胶囊（有追剧进度时呈现）
                                if (_historyList.isNotEmpty && _searchController.text.isEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildContinueWatchingShelf(),
                                  ),

                                // 🥒 黄瓜短剧：官方全维度分类筛选矩阵（按照要求放置在【最近观看】下方，与卡片严格UI对齐）
                                if (_searchController.text.isEmpty)
                                  SliverToBoxAdapter(
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: SettingsService.dramaSourceTypeNotifier,
                                      builder: (context, sourceType, _) {
                                        if (sourceType == SettingsService.dramaSourceHgdju) {
                                          return _buildHgdjuFilterMatrix(context);
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),

                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: SettingsService.dramaSourceTypeNotifier,
                                      builder: (context, sourceType, _) {
                                        final isHgdju = sourceType == SettingsService.dramaSourceHgdju;
                                        String titleText;
                                        if (isHgdju) {
                                          final parts = <String>[];
                                          if (_hgdjuSelectedLine != '全部') parts.add(_hgdjuSelectedLine);
                                          if (_hgdjuSelectedTag != '全部') parts.add(_hgdjuSelectedTag);
                                          if (_hgdjuSelectedStatus != '全部') parts.add(_hgdjuSelectedStatus);
                                          if (_hgdjuSelectedSort != '最热') parts.add(_hgdjuSelectedSort);
                                          titleText = parts.isEmpty ? '全部 · 精选片单' : '${parts.join(' · ')} · 精选片单';
                                        } else {
                                          titleText = '${_selectedCategory.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '')} · 精选片单';
                                        }

                                        return Row(
                                          children: [
                                            Container(
                                              width: 3.5,
                                              height: 15,
                                              decoration: BoxDecoration(
                                                gradient: isHgdju
                                                    ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                                    : AppTheme.primaryGradient,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              titleText,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.textPrimary(context),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _selectedCategory.contains('吃瓜')
                                                  ? '已加载 ${_dramas.length} 篇 · 第 $_currentPage/29 页'
                                                  : _selectedCategory.contains('首页')
                                                      ? '全分类海量短剧 · 已载入 ${_dramas.length} 部'
                                                      : '共 ${_dramas.length} 部',
                                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),

                            // 智能卡片视图（专题采用16:9横版专辑卡，吃瓜采用资讯瀑布流，普通短剧与排行榜采用2:3黄金网格）
                            _selectedCategory.contains('专题')
                                ? SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _buildTopicCard(_dramas[index]),
                                        childCount: _dramas.length,
                                      ),
                                    ),
                                  )
                                : _selectedCategory.contains('吃瓜')
                                    ? SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                                        sliver: SliverList(
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) => _buildGossipCard(_dramas[index]),
                                            childCount: _dramas.length,
                                          ),
                                        ),
                                      )
                                    : SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 90), // 留出底部悬浮岛导航高度
                                        sliver: SliverGrid(
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: _getGridCrossAxisCount(MediaQuery.of(context).size.width),
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: 0.62,
                                          ),
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                              final drama = _dramas[index];
                                              return _buildDramaCard(drama);
                                            },
                                            childCount: _dramas.length,
                                          ),
                                        ),
                                      ),

                            if (_isLoadingMore)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: SpinKitThreeBounce(color: AppTheme.primaryPink, size: 22),
                                  ),
                                ),
                              ),

                            if (!_hasMore && _dramas.isNotEmpty && _dramas.length > 8)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 40),
                                  child: Center(
                                    child: Text(
                                      _selectedCategory.contains('吃瓜')
                                          ? '— 🎉 全网爆料已全部加载 (共 ${_dramas.length} 篇 / 29页) —'
                                          : _selectedCategory.contains('首页')
                                              ? '— 🎉 全分类海量短剧已全部加载完毕 (共 ${_dramas.length} 部) —'
                                              : '— 已经到底啦，共 ${_dramas.length} 部 —',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted(context).withOpacity(0.6),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_isLoading)
                          Positioned.fill(
                            child: Container(
                              color: (AppTheme.isDark(context) ? Colors.black : Colors.white).withOpacity(0.35),
                              child: const Center(
                                child: SpinKitFadingCircle(color: Color(0xFF10B981), size: 38),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🌟 顶部爆款电影大图轮播推荐位 (Hero Carousel)
  Widget _buildHeroCarousel(List<ShortDrama> list) {
    return Container(
      height: 185,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: PageView.builder(
        itemCount: list.length,
        itemBuilder: (context, idx) {
          final drama = list[idx];
          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DramaPlayerScreen(drama: drama, initialEpisodeIndex: 0),
                ),
              );
              _loadHistory();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景封面
                  DramaPosterWidget(drama: drama),

                  // 电影级暗角遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.55),
                          Colors.black.withOpacity(0.94),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  // 顶部爆款徽章
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.neonGlow(color: Colors.amber, opacity: 0.5, blur: 8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.whatshot_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('全网剧王力荐', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),

                  // 底部剧名、评分与立即开播按钮
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                drama.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '★ ${drama.rating.toStringAsFixed(1)} 分',
                                      style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    drama.updateInfo.isNotEmpty ? drama.updateInfo : '全 ${drama.totalEpisodes} 集',
                                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 立即开播按钮
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppTheme.neonGlow(color: AppTheme.primaryPink, opacity: 0.6, blur: 10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 2),
                              Text('立即看', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 🌟 正在追看 · 续播时光轴胶囊
  Widget _buildContinueWatchingShelf() {
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryPink, size: 18),
              const SizedBox(width: 8),
              Text(
                '最近在看 · 继续追剧',
                style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showHistoryBottomSheet,
                child: Row(
                  children: [
                    Text('全部 (${_historyList.length})', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11)),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context), size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _historyList.take(6).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final item = _historyList[idx];
                final drama = item.toShortDrama();
                final hasNew = item.hasNewEpisodes;

                return InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DramaPlayerScreen(
                          drama: drama,
                          initialEpisodeIndex: item.lastEpisodeIndex,
                        ),
                      ),
                    );
                    _loadHistory();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161928) : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasNew ? AppTheme.primaryPink.withOpacity(0.6) : AppTheme.borderColor(context),
                        width: hasNew ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 52,
                            height: 72,
                            child: DramaPosterWidget(drama: drama),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (hasNew)
                                Text(
                                  '🔥 新更至第 ${item.currentMaxEpisodes} 集',
                                  style: const TextStyle(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                                )
                              else
                                Text(
                                  '看到第 ${item.lastEpisodeNum} 集',
                                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 10),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimeAgo(item.updatedAt),
                                style: TextStyle(color: AppTheme.textMuted(context), fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getGridCrossAxisCount(double width) {
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    if (width >= 640) return 4;
    if (width >= 460) return 3;
    return 2;
  }

  /// 黄金比例电影海报卡片
  Widget _buildDramaCard(ShortDrama drama) {
    DramaHistoryItem? historyItem;
    try {
      historyItem = _historyList.firstWhere((h) => h.dramaId == drama.id);
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DramaPlayerScreen(
              drama: drama,
              initialEpisodeIndex: historyItem?.lastEpisodeIndex ?? 0,
            ),
          ),
        );
        _loadHistory();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: historyItem != null
                ? Colors.amber.withOpacity(0.6)
                : AppTheme.borderColor(context),
            width: 0.8,
          ),
          boxShadow: AppTheme.cardShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 海报图与角标
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DramaPosterWidget(drama: drama),

                  // 顶部评分金标
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${drama.rating.toStringAsFixed(1)}',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // 左上角角标（排行榜专属王者冠标 / 观看历史 / 独家原创标签）
                  if (drama.rankNum > 0 || _selectedCategory.contains('排行'))
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: drama.rankNum == 1
                              ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
                              : drama.rankNum == 2
                                  ? const LinearGradient(colors: [Color(0xFFE8E8E8), Color(0xFF9E9E9E)])
                                  : drama.rankNum == 3
                                      ? const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFF8B4513)])
                                      : const LinearGradient(colors: [Color(0xFF3A3A3C), Color(0xFF1C1C1E)]),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: drama.rankNum == 1
                                  ? Colors.amber.withOpacity(0.5)
                                  : Colors.black.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (drama.rankNum == 1) ...[
                              const Text('👑 ', style: TextStyle(fontSize: 9)),
                              const Text('TOP 1', style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w900)),
                            ] else if (drama.rankNum == 2) ...[
                              const Text('🥈 ', style: TextStyle(fontSize: 9)),
                              const Text('TOP 2', style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w900)),
                            ] else if (drama.rankNum == 3) ...[
                              const Text('🥉 ', style: TextStyle(fontSize: 9)),
                              const Text('TOP 3', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ] else ...[
                              Text(
                                drama.rankNum > 0 ? 'TOP ${drama.rankNum}' : 'TOP',
                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else if (historyItem != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '看到第${historyItem.lastEpisodeNum}集',
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else if (drama.rankNum > 0 || _selectedCategory.contains('排行'))
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: drama.rankNum == 1
                              ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
                              : drama.rankNum == 2
                                  ? const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFF757575)])
                                  : drama.rankNum == 3
                                      ? const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFF8B4513)])
                                      : const LinearGradient(colors: [Color(0xFF333333), Color(0xFF1E1E1E)]),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1.5)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (drama.rankNum == 1)
                              const Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Icon(Icons.workspace_premium, size: 10, color: Colors.white),
                              ),
                            Text(
                              drama.rankNum > 0 ? 'TOP ${drama.rankNum}' : 'TOP',
                              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (drama.badge.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          drama.badge,
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  // 底部更新集数遮罩
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              drama.updateInfo.isNotEmpty ? drama.updateInfo : '全${drama.totalEpisodes}集',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (drama.playCount.isNotEmpty) ...[
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF7A00), size: 11),
                            Text(
                              drama.playCount,
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 剧名与题材标签
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    drama.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    children: drama.tags.take(2).map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.chipUnselectedBg(context),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: AppTheme.textMuted(context),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 独家专题 16:9 横版宽幅专辑卡片
  Widget _buildTopicCard(ShortDrama topic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
        boxShadow: AppTheme.cardShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showTopicDramasModal(topic),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DramaPosterWidget(drama: topic),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.collections_bookmark_rounded, color: AppTheme.primaryPink, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            topic.extraMeta.isNotEmpty ? topic.extraMeta : '精选专辑',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Text(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '独家企划',
                      style: TextStyle(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topic.description.isNotEmpty ? topic.description : '汇聚全网优质剧情短剧合辑，点击查看收录剧目',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11.5),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.textMuted(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 娱乐吃瓜 资讯瀑布流卡片
  Widget _buildGossipCard(ShortDrama gossip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
        boxShadow: AppTheme.cardShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GossipDetailScreen(drama: gossip),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 8.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DramaPosterWidget(drama: gossip),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '🍉 吃瓜爆料',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gossip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.feed_outlined, size: 14, color: AppTheme.textMuted(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          gossip.extraMeta.isNotEmpty ? gossip.extraMeta : '黄果AI短剧社区 · 最新动态',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11.5),
                        ),
                      ),
                      Text(
                        '阅读全文 >',
                        style: TextStyle(color: AppTheme.primaryPink, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出独家专题包含的精选短剧片单
  void _showTopicDramasModal(ShortDrama topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TopicDramasSheet(topic: topic),
    );
  }

  /// 黄瓜短剧官方专属四维分类筛选矩阵 (1:1 像素级对齐官方截图：内容线 / 标签 / 状态 / 排序)
  Widget _buildHgdjuFilterMatrix(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    const hgdjuGreen = Color(0xFF10B981); // 官方经典黄瓜翠绿胶囊高亮

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 内容线
          _buildHgdjuRow(
            label: '内容线',
            items: DramaService.hgdjuLines,
            selectedItem: _hgdjuSelectedLine,
            activeColor: hgdjuGreen,
            onSelected: (val) {
              setState(() {
                _hgdjuSelectedLine = val;
                _selectedCategory = val;
              });
              _loadDramas();
            },
          ),
          const SizedBox(height: 8),
          // 2. 标签 (支持右侧展开/收起切换全量34个官方题材标签)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _hgdjuTagsExpanded ? DramaService.hgdjuTags.length : 13,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final item = DramaService.hgdjuTags[i];
                      final isSelected = item == _hgdjuSelectedTag;
                      return InkWell(
                        onTap: () {
                          setState(() => _hgdjuSelectedTag = item);
                          _loadDramas();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? hgdjuGreen
                                : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                            borderRadius: BorderRadius.circular(14),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                                    width: 0.6,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: hgdjuGreen.withOpacity(0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textSecondary(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 🌟 1:1 对齐官方截图右侧下箭头：展开/收起全量34个标签
              InkWell(
                onTap: () => setState(() => _hgdjuTagsExpanded = !_hgdjuTagsExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    _hgdjuTagsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppTheme.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 3. 状态
          _buildHgdjuRow(
            label: '状态',
            items: DramaService.hgdjuStatuses,
            selectedItem: _hgdjuSelectedStatus,
            activeColor: hgdjuGreen,
            onSelected: (val) {
              setState(() {
                _hgdjuSelectedStatus = val;
              });
              _loadDramas();
            },
          ),
          const SizedBox(height: 8),
          // 4. 排序
          _buildHgdjuRow(
            label: '排序',
            items: DramaService.hgdjuSorts,
            selectedItem: _hgdjuSelectedSort,
            activeColor: hgdjuGreen,
            onSelected: (val) {
              setState(() {
                _hgdjuSelectedSort = val;
                _selectedSubTab = val;
              });
              _loadDramas();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHgdjuRow({
    required String label,
    required List<String> items,
    required String selectedItem,
    required Color activeColor,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = AppTheme.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted(context),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final item = items[i];
                final isSelected = item == selectedItem;
                return InkWell(
                  onTap: () => onSelected(item),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor
                          : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                              width: 0.6,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: activeColor.withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 1.5),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 50, color: AppTheme.textMuted(context)),
          const SizedBox(height: 12),
          Text('暂无相关纯净短剧', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13)),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedCategory = DramaService.categories[1];
                _selectedSubTab = DramaService.subTabs.first;
              });
              _loadDramas();
            },
            child: const Text('重置筛选', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class DramaPosterWidget extends StatefulWidget {
  final ShortDrama drama;

  const DramaPosterWidget({super.key, required this.drama});

  @override
  State<DramaPosterWidget> createState() => _DramaPosterWidgetState();
}

class _DramaPosterWidgetState extends State<DramaPosterWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant DramaPosterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drama.coverUrl != widget.drama.coverUrl ||
        oldWidget.drama.id != widget.drama.id) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final cover = widget.drama.coverUrl.trim();
    if (cover.isEmpty || !cover.startsWith('http')) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final cached = ImageLoaderService.getCachedImage(cover);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageBytes = cached;
          _isLoading = false;
        });
      }
      return;
    }

    final domain = await SettingsService.getDramaBaseUrl();
    final bytes = await ImageLoaderService.loadImage(cover, domain: domain);

    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      return Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    if (_isLoading) {
      return Container(
        color: const Color(0xFF141724),
        child: const Center(
          child: SpinKitFadingCircle(color: AppTheme.primaryPink, size: 20),
        ),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22163B), Color(0xFF110B1E)],
        ),
      ),
      child: Center(
        child: Icon(Icons.movie_filter_rounded, color: AppTheme.primaryPink.withOpacity(0.5), size: 30),
      ),
    );
  }
}

/// 独家专题剧集片单弹窗 (BottomSheet)
class _TopicDramasSheet extends StatefulWidget {
  final ShortDrama topic;

  const _TopicDramasSheet({required this.topic});

  @override
  State<_TopicDramasSheet> createState() => _TopicDramasSheetState();
}

class _TopicDramasSheetState extends State<_TopicDramasSheet> {
  List<ShortDrama> _topicDramas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopicDramas();
  }

  Future<void> _loadTopicDramas() async {
    final list = await DramaService.fetchTopicDramas(widget.topic.id);
    if (mounted) {
      setState(() {
        _topicDramas = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部手柄
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppTheme.borderColor(context).withOpacity(0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // 专题大标题与关闭按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.topic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
                if (widget.topic.extraMeta.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.topic.extraMeta,
                      style: const TextStyle(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: AppTheme.textMuted(context),
                ),
              ],
            ),
          ),
          Divider(color: AppTheme.borderColor(context), height: 1),

          // 专题收录短剧列表
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SpinKitFadingCircle(color: AppTheme.primaryPink, size: 36),
                  )
                : _topicDramas.isEmpty
                    ? Center(
                        child: Text(
                          '暂无收录短剧',
                          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: _topicDramas.length,
                        itemBuilder: (context, index) {
                          final drama = _topicDramas[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DramaPlayerScreen(
                                    drama: drama,
                                    initialEpisodeIndex: 0,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        DramaPosterWidget(drama: drama),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.75),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              drama.rating.toStringAsFixed(1),
                                              style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Text(
                                      drama.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

