import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/live_stream.dart';
import '../services/api_service.dart';
import '../services/image_loader_service.dart';
import '../services/theme_service.dart';
import '../services/settings_service.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import '../widgets/route_selection_modal.dart';
import '../services/proxy_route_service.dart';
import '../services/system_controls_service.dart';

class LiveScreen extends StatefulWidget {
  final ApiService apiService;

  const LiveScreen({super.key, required this.apiService});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<LiveStreamItem> _pandaStreams = [];
  List<LiveStreamItem> _flexStreams = [];
  List<LiveStreamItem> _filteredStreams = [];

  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';

  // 排序模式: viewers(观众量), score(实时热度), bookmarks(关注量), latest(最新开播)
  String _currentSort = 'viewers';

  // 房型过滤
  bool _filterAdultOnly = false;
  bool _hidePasswordRooms = true;
  bool _hideFanRooms = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _applyFilters();
      }
    });
    _loadAllLiveStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllLiveStreams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        widget.apiService.fetchPandaLiveStreams().catchError((_) => <LiveStreamItem>[]),
        widget.apiService.fetchFlexLiveStreams().catchError((_) => <LiveStreamItem>[]),
      ]);

      if (mounted) {
        setState(() {
          _pandaStreams = results[0];
          _flexStreams = results[1];
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final currentList = _tabController.index == 0 ? _pandaStreams : _flexStreams;
    List<LiveStreamItem> list = List.from(currentList);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) =>
          s.title.toLowerCase().contains(q) ||
          s.userNick.toLowerCase().contains(q) ||
          s.userId.toLowerCase().contains(q)).toList();
    }

    if (_hidePasswordRooms) {
      list = list.where((s) => !s.isPw).toList();
    }

    if (_hideFanRooms) {
      list = list.where((s) => !s.isFan).toList();
    }

    if (_filterAdultOnly) {
      list = list.where((s) => s.isAdult).toList();
    }

    if (_currentSort == 'viewers') {
      list.sort((a, b) => b.viewers.compareTo(a.viewers));
    } else if (_currentSort == 'score') {
      list.sort((a, b) => b.score.compareTo(a.score));
    } else if (_currentSort == 'bookmarks') {
      list.sort((a, b) => b.bookmarks.compareTo(a.bookmarks));
    } else if (_currentSort == 'latest') {
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
    }

    setState(() {
      _filteredStreams = list;
    });
  }

  String _formatBeijingTime(String kstTime) {
    if (kstTime.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(kstTime.replaceAll(' ', 'T'));
      if (dt != null) {
        return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return kstTime;
  }

  void _openPlayer(LiveStreamItem stream) async {
    String playUrl = stream.streamUrl;
    if (playUrl.isEmpty && stream.platform == 'pandatv') {
      final direct = ApiService.getM3uStreamUrl(stream.userId);
      if (direct != null && direct.isNotEmpty) {
        playUrl = direct;
      } else {
        playUrl = '${widget.apiService.baseUrl}/player/pandalive.html?url=${stream.userId}';
      }
    }

    final initialIdx = _filteredStreams.indexOf(stream);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          title: '🔴 [${stream.platform == 'pandatv' ? 'PandaTV' : 'FlexTV'}] ${stream.userNick} - ${stream.title}',
          videoUrl: playUrl,
          viewers: stream.viewers,
          streamList: _filteredStreams,
          initialIndex: initialIdx >= 0 ? initialIdx : 0,
        ),
      ),
    );
    // 退出播放器回到直播列表页时，做强保底还原系统默认亮度与自动感光
    SystemControlsService.resetBrightness();
  }

  @override
  Widget build(BuildContext context) {
    final pandaCount = _pandaStreams.length;
    final flexCount = _flexStreams.length;
    final isDark = AppTheme.isDark(context);
    final LiveStreamItem? heroStream = _filteredStreams.isNotEmpty && _searchQuery.isEmpty ? _filteredStreams.first : null;

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
              child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '超清现场',
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
                        gradient: AppTheme.cyanGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '1080P/60FPS',
                        style: TextStyle(fontSize: 8.5, color: Colors.black, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                Text(
                  '韩国直连 · 零广告纯净原画',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 线路调度与防卡顿测速入口
          IconButton(
            icon: Icon(
              ProxyRouteService.localNetworkMode == LocalNetworkMode.vpnConnected
                  ? Icons.vpn_lock_rounded
                  : Icons.alt_route_rounded,
              color: ProxyRouteService.localNetworkMode == LocalNetworkMode.vpnConnected
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF2E63),
              size: 21,
            ),
            tooltip: '线路调度与防卡顿设置',
            onPressed: () {
              RouteSelectionModal.show(
                context,
                onRouteChanged: () => setState(() {}),
                onShowMessage: (msg) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF1E2235),
                    ),
                  );
                },
              );
            },
          ),
          // 模式切换
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF5A6270),
              size: 20,
            ),
            tooltip: isDark ? '切换浅色' : '切换暗黑',
            onPressed: () {
              final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
              SettingsService.setThemeMode(nextMode);
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textSecondary(context)),
            tooltip: '刷新流',
            onPressed: _loadAllLiveStreams,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. 现代化平台切换分段胶囊 (PandaTV / FlexTV)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            color: AppTheme.appBarBg(context),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.inputBg(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary(context),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🐼 PandaTV'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pandaCount',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚡ FlexTV'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$flexCount',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 搜索与筛选工具栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            decoration: BoxDecoration(
              color: AppTheme.appBarBg(context),
              border: Border(bottom: BorderSide(color: AppTheme.borderColor(context), width: 0.8)),
            ),
            child: Column(
              children: [
                // 极光搜索框
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.inputBg(context),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: AppTheme.borderColor(context), width: 0.6),
                  ),
                  child: TextField(
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '搜索主播昵称、房间标题、房间 ID...',
                      hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryPink, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                    ),
                    onChanged: (val) {
                      _searchQuery = val.trim();
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 筛选胶囊滑动栏
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill(
                        label: '🔥 人气榜 ↓',
                        selected: _currentSort == 'viewers',
                        onTap: () => setState(() {
                          _currentSort = 'viewers';
                          _applyFilters();
                        }),
                      ),
                      _buildFilterPill(
                        label: '⚡ 实时热度',
                        selected: _currentSort == 'score',
                        onTap: () => setState(() {
                          _currentSort = 'score';
                          _applyFilters();
                        }),
                      ),
                      _buildFilterPill(
                        label: '⭐ 订阅关注',
                        selected: _currentSort == 'bookmarks',
                        onTap: () => setState(() {
                          _currentSort = 'bookmarks';
                          _applyFilters();
                        }),
                      ),
                      _buildFilterPill(
                        label: '⏱️ 刚刚开播',
                        selected: _currentSort == 'latest',
                        onTap: () => setState(() {
                          _currentSort = 'latest';
                          _applyFilters();
                        }),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 1,
                        height: 16,
                        color: AppTheme.borderColor(context),
                      ),
                      _buildFilterPill(
                        label: '🔞 19+ 专属',
                        selected: _filterAdultOnly,
                        activeColor: const Color(0xFFFF1744),
                        onTap: () => setState(() {
                          _filterAdultOnly = !_filterAdultOnly;
                          _applyFilters();
                        }),
                      ),
                      _buildFilterPill(
                        label: '🔒 密码房间',
                        selected: !_hidePasswordRooms,
                        activeColor: Colors.amber.shade800,
                        onTap: () => setState(() {
                          _hidePasswordRooms = !_hidePasswordRooms;
                          _applyFilters();
                        }),
                      ),
                      _buildFilterPill(
                        label: '💎 粉丝房间',
                        selected: !_hideFanRooms,
                        activeColor: AppTheme.primaryPink,
                        onTap: () => setState(() {
                          _hideFanRooms = !_hideFanRooms;
                          _applyFilters();
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. 沉浸式直播内容区
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryPink,
              backgroundColor: AppTheme.cardBg(context),
              onRefresh: _loadAllLiveStreams,
              child: _isLoading
                  ? const Center(
                      child: SpinKitFadingCircle(
                        color: AppTheme.primaryPink,
                        size: 44,
                      ),
                    )
                  : _errorMessage.isNotEmpty && _filteredStreams.isEmpty
                      ? _buildErrorView()
                      : _filteredStreams.isEmpty
                          ? _buildEmptyView()
                          : CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // 🌟 实时热度最高 TOP 1 主播焦点推荐（海报上的主播，在下方网格列表里也同样完整保留一份，不移除！）
                                if (heroStream != null)
                                  SliverToBoxAdapter(
                                    child: _buildHeroSpotlight(heroStream),
                                  ),

                                // 网格标题
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3.5,
                                          height: 15,
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '热门在线频道 (${_filteredStreams.length})',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary(context),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '实时更新中',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 直播流网格（全量完整呈现，海报卡片内部正常调用）
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), // 留出底部悬浮岛高度
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.72,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 12,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final stream = _filteredStreams[index];
                                        return _buildLiveCard(stream);
                                      },
                                      childCount: _filteredStreams.length,
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

  /// 🌟 顶部全网 TOP 1 焦点霸屏海报 (Hero Spotlight Banner)
  Widget _buildHeroSpotlight(LiveStreamItem stream) {
    return GestureDetector(
      onTap: () => _openPlayer(stream),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        height: 190,
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
            // 封面大图
            LiveThumbWidget(thumbUrl: stream.thumbUrl),

            // 电影级暗角与流光渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.92),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // 左上角“全网人气 TOP 1”金标
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.neonGlow(color: Colors.amber, opacity: 0.5, blur: 8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'TOP 1 焦点推荐',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),

            // 右上角 LIVE 脉冲胶囊
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: AppTheme.liveGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.neonGlow(color: const Color(0xFFFF1744), opacity: 0.6, blur: 8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE 正在直播',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),

            // 底部主播与房间信息
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 详情
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              stream.userNick,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (stream.isAdult)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('19+', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stream.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, color: AppTheme.electricCyan, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${stream.viewers} 人正在围观',
                              style: const TextStyle(color: AppTheme.electricCyan, fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 围观播放按钮
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
                        Text(
                          '立即进入',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
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
  }

  Widget _buildFilterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final isDark = AppTheme.isDark(context);
    final color = activeColor ?? AppTheme.primaryPink;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? color.withOpacity(0.22) : color.withOpacity(0.12))
                : AppTheme.chipUnselectedBg(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color.withOpacity(isDark ? 0.7 : 0.5) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? color : AppTheme.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  /// 升级版超清直播卡片
  Widget _buildLiveCard(LiveStreamItem stream) {
    final isDark = AppTheme.isDark(context);

    return GestureDetector(
      onTap: () => _openPlayer(stream),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 0.8,
          ),
          boxShadow: AppTheme.cardShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面与角标区域
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LiveThumbWidget(thumbUrl: stream.thumbUrl),

                  // 底部深暗过渡渐变
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 左上角 LIVE 脉冲胶囊
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        gradient: stream.isLive ? AppTheme.liveGradient : null,
                        color: stream.isLive ? null : Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: stream.isLive
                            ? AppTheme.neonGlow(color: const Color(0xFFFF1744), opacity: 0.5, blur: 6)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stream.isLive ? 'LIVE' : '录播',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 右上角 19+ / 锁 / 粉丝标
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stream.isAdult)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('19+', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                          ),
                        if (stream.isPw)
                          Container(
                            padding: const EdgeInsets.all(3),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 10),
                          ),
                        if (stream.isFan)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 10),
                          ),
                      ],
                    ),
                  ),

                  // 封面左下角在线人数
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5722), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '${stream.viewers}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 封面右下角超清标
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        '1080P',
                        style: TextStyle(color: AppTheme.electricCyan, fontSize: 8.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 卡片底部信息区
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 标题
                    Text(
                      stream.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    // 主播昵称与开播时间
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: Center(
                            child: Text(
                              stream.userNick.isNotEmpty ? stream.userNick[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            stream.userNick,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loadAllLiveStreams,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('重试连接', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tv_off_rounded, size: 56, color: AppTheme.textMuted(context)),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty ? '未找到符合条件的直播间' : '暂无正在直播的主播',
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class LiveThumbWidget extends StatefulWidget {
  final String thumbUrl;

  const LiveThumbWidget({super.key, required this.thumbUrl});

  @override
  State<LiveThumbWidget> createState() => _LiveThumbWidgetState();
}

class _LiveThumbWidgetState extends State<LiveThumbWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant LiveThumbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbUrl != widget.thumbUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.thumbUrl.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final cached = ImageLoaderService.getCachedImage(url);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageBytes = cached;
          _isLoading = false;
        });
      }
      return;
    }

    final bytes = await ImageLoaderService.loadImage(url);
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      return Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildFallback(isDark),
      );
    }

    if (_isLoading) {
      return Container(
        color: isDark ? const Color(0xFF1B1E30) : const Color(0xFFE8ECEF),
        child: const Center(
          child: SpinKitFadingCircle(color: AppTheme.primaryPink, size: 20),
        ),
      );
    }

    return _buildFallback(isDark);
  }

  Widget _buildFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1B1E30), const Color(0xFF121421)]
              : [const Color(0xFFE8ECEF), const Color(0xFFD6DBE4)],
        ),
      ),
      child: Center(
        child: Icon(Icons.live_tv_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 36),
      ),
    );
  }
}
