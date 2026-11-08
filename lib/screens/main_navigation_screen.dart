import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../services/drama_history_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'live_screen.dart';
import 'drama_hall_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    DramaHistoryService.checkForUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdate();
    });
  }

  Future<void> _checkAppUpdate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final info = await UpdateService.checkUpdate();
      if (info != null && mounted) {
        UpdateDialog.show(context, info);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return ValueListenableBuilder<String>(
      valueListenable: SettingsService.dramaBaseUrlNotifier,
      builder: (context, dramaUrl, _) {
        final bool isDramaEnabled = dramaUrl.isNotEmpty;

        final List<Widget> screens = [
          LiveScreen(apiService: _apiService),
          if (isDramaEnabled) const DramaHallScreen(),
          const SettingsScreen(),
        ];

        return ValueListenableBuilder<int>(
          valueListenable: DramaHistoryService.updateCountNotifier,
          builder: (context, updateCount, _) {
            final List<_NavItemData> navItems = [
              _NavItemData(
                icon: Icons.live_tv_rounded,
                label: '超清直播',
              ),
              if (isDramaEnabled)
                _NavItemData(
                  icon: Icons.movie_filter_rounded,
                  label: 'AI 短剧',
                  badgeCount: updateCount,
                ),
              _NavItemData(
                icon: Icons.tune_rounded,
                label: '系统管理',
              ),
            ];

            final safeIndex = _currentIndex.clamp(0, screens.length - 1);

            return Scaffold(
              backgroundColor: AppTheme.scaffoldBg(context),
              extendBody: true,
              body: IndexedStack(
                index: safeIndex,
                children: screens,
              ),
              bottomNavigationBar: _buildFloatingIslandNavBar(context, navItems, safeIndex, isDark),
            );
          },
        );
      },
    );
  }

  /// 🌟 现代流媒体悬浮晶透岛屿导航栏 (Floating Frosted Island Navigation Bar)
  Widget _buildFloatingIslandNavBar(
    BuildContext context,
    List<_NavItemData> items,
    int activeIndex,
    bool isDark,
  ) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            if (isDark)
              BoxShadow(
                color: AppTheme.primaryPink.withOpacity(0.08),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF101321).withOpacity(0.88)
                    : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.black.withOpacity(0.06),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == activeIndex;
                  return _buildNavItem(item, isSelected, () {
                    setState(() {
                      _currentIndex = index;
                    });
                  });
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItemData item, bool isSelected, VoidCallback onTap) {
    final isDark = AppTheme.isDark(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPink.withOpacity(0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFF7E8698) : const Color(0xFF8C95A6)),
                ),
                if (item.badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? AppTheme.goldGradient
                            : AppTheme.liveGradient,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF101321) : Colors.white,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '${item.badgeCount}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final int badgeCount;

  _NavItemData({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });
}
